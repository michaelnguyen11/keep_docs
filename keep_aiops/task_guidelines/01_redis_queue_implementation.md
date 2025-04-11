# Task 1: Redis Queue Implementation Guidelines

This document provides detailed guidance for implementing a Redis-based queue system for high-volume alert processing in Keep.

## Overview

The current Keep system can use either in-memory processing or Redis-based queue processing controlled by the `REDIS` environment variable. For handling 600GB/day of alerts, we need to enhance the Redis implementation for better reliability, performance monitoring, and scalability.

## 1. Enabling Redis as Default

### Current Implementation

In `keep/api/config.py`, Redis is optional and disabled by default:

```python
# Current implementation
REDIS = getenv_as_bool("REDIS", False)
```

### Required Changes

#### Step 1: Update the default setting in `keep/api/config.py`:

```python
# Updated setting - make Redis the default
REDIS = getenv_as_bool("REDIS", True)

# Add additional Redis configuration settings
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)
REDIS_USE_SSL = getenv_as_bool("REDIS_USE_SSL", False)
REDIS_POOL_MAX_CONNECTIONS = int(os.getenv("REDIS_POOL_MAX_CONNECTIONS", 100))
REDIS_SOCKET_TIMEOUT = int(os.getenv("REDIS_SOCKET_TIMEOUT", 5))
REDIS_SOCKET_CONNECT_TIMEOUT = int(os.getenv("REDIS_SOCKET_CONNECT_TIMEOUT", 5))
```

#### Step 2: Implement Redis connection pooling in `keep/api/core/redis_client.py`:

```python
import redis
from redis.connection import BlockingConnectionPool
from keep.api.config import (
    REDIS_HOST, REDIS_PORT, REDIS_DB, REDIS_PASSWORD, REDIS_USE_SSL,
    REDIS_POOL_MAX_CONNECTIONS, REDIS_SOCKET_TIMEOUT, REDIS_SOCKET_CONNECT_TIMEOUT
)
import time
import logging

logger = logging.getLogger(__name__)

class RedisClient:
    _instance = None
    _redis_pool = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        self._create_pool()
    
    def _create_pool(self):
        """Create a blocking connection pool to Redis"""
        self._redis_pool = BlockingConnectionPool(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            password=REDIS_PASSWORD,
            ssl=REDIS_USE_SSL,
            max_connections=REDIS_POOL_MAX_CONNECTIONS,
            socket_timeout=REDIS_SOCKET_TIMEOUT,
            socket_connect_timeout=REDIS_SOCKET_CONNECT_TIMEOUT,
            health_check_interval=30,
            retry_on_timeout=True
        )
        
    def get_client(self):
        """Get a Redis client from the connection pool with retry logic"""
        max_retries = 5
        retry_count = 0
        backoff_factor = 0.5
        
        while retry_count < max_retries:
            try:
                return redis.Redis(connection_pool=self._redis_pool)
            except (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError) as e:
                retry_count += 1
                wait_time = backoff_factor * (2 ** (retry_count - 1))
                logger.warning(f"Redis connection failed, retrying in {wait_time} seconds. Error: {str(e)}")
                time.sleep(wait_time)
                
                # Recreate the pool if we have multiple failures
                if retry_count >= 3:
                    self._create_pool()
                    
        logger.error("Failed to connect to Redis after maximum retries")
        raise redis.exceptions.ConnectionError("Failed to connect to Redis after maximum retries")
    
    def ping(self):
        """Check if Redis is available"""
        try:
            client = self.get_client()
            return client.ping()
        except:
            return False
```

## 2. Implementing Priority Queues

The current implementation treats all alerts equally. For high-volume environments, we need to prioritize critical alerts.

### Step 1: Create a priority queue manager in `keep/api/core/queue_manager.py`:

```python
from keep.api.core.redis_client import RedisClient
import json
import time
import logging
from enum import Enum

logger = logging.getLogger(__name__)

class AlertPriority(Enum):
    CRITICAL = 0  # Lowest queue number = highest priority
    HIGH = 1
    MEDIUM = 2
    LOW = 3

class QueueManager:
    """Manages priority queues for alert processing"""
    
    def __init__(self):
        self.redis_client = RedisClient.get_instance().get_client()
        self.queue_prefix = "keep:alerts:queue:"
        self.priority_queues = {
            AlertPriority.CRITICAL: f"{self.queue_prefix}critical",
            AlertPriority.HIGH: f"{self.queue_prefix}high",
            AlertPriority.MEDIUM: f"{self.queue_prefix}medium",
            AlertPriority.LOW: f"{self.queue_prefix}low",
        }
        self.processing_queue = "keep:alerts:processing"
        self.dead_letter_queue = "keep:alerts:deadletter"
        
    def determine_priority(self, alert_data):
        """Determine queue priority based on alert data"""
        # Extract severity if it exists
        severity = None
        if isinstance(alert_data, dict):
            severity = alert_data.get("severity", None)
            
        # Map severity to priority
        if severity == "critical":
            return AlertPriority.CRITICAL
        elif severity == "high" or severity == "error":
            return AlertPriority.HIGH
        elif severity == "warning" or severity == "medium":
            return AlertPriority.MEDIUM
        else:
            return AlertPriority.LOW
    
    def enqueue_alert(self, alert_data, ttl=86400):  # Default TTL: 24 hours
        """Add alert to the appropriate priority queue"""
        alert_id = alert_data.get("id", f"alert:{int(time.time()*1000)}")
        priority = self.determine_priority(alert_data)
        queue_key = self.priority_queues[priority]
        
        serialized_data = json.dumps(alert_data)
        
        # Use a pipeline for atomic operations
        pipe = self.redis_client.pipeline()
        
        # Store the alert data with TTL
        data_key = f"keep:alerts:data:{alert_id}"
        pipe.set(data_key, serialized_data)
        pipe.expire(data_key, ttl)
        
        # Add to the priority queue
        pipe.lpush(queue_key, alert_id)
        
        # Add queue metrics
        pipe.hincrby("keep:alerts:metrics", f"enqueued:{priority.name.lower()}", 1)
        pipe.hincrby("keep:alerts:metrics", "total_enqueued", 1)
        
        pipe.execute()
        
        logger.debug(f"Alert {alert_id} enqueued with {priority.name} priority")
        return alert_id
    
    def dequeue_alert(self, timeout=5):
        """Get the next alert from the highest priority non-empty queue"""
        # Check each priority queue in order
        for priority in AlertPriority:
            queue_key = self.priority_queues[priority]
            
            # Try to get an alert ID from this queue
            alert_id = self.redis_client.brpoplpush(
                queue_key,
                self.processing_queue,
                timeout
            )
            
            if alert_id:
                # Convert bytes to string if needed
                if isinstance(alert_id, bytes):
                    alert_id = alert_id.decode('utf-8')
                    
                # Get the actual alert data
                data_key = f"keep:alerts:data:{alert_id}"
                alert_data = self.redis_client.get(data_key)
                
                if alert_data:
                    if isinstance(alert_data, bytes):
                        alert_data = alert_data.decode('utf-8')
                    
                    # Update metrics
                    self.redis_client.hincrby("keep:alerts:metrics", f"dequeued:{priority.name.lower()}", 1)
                    self.redis_client.hincrby("keep:alerts:metrics", "total_dequeued", 1)
                    
                    logger.debug(f"Alert {alert_id} dequeued from {priority.name} queue")
                    return json.loads(alert_data), alert_id
                else:
                    # Data missing, remove from processing queue
                    self.redis_client.lrem(self.processing_queue, 0, alert_id)
                    logger.warning(f"Alert data missing for {alert_id}, removed from processing queue")
            
        # No alerts found in any queue
        return None, None
    
    def complete_processing(self, alert_id):
        """Mark an alert as successfully processed"""
        # Remove from processing queue
        self.redis_client.lrem(self.processing_queue, 0, alert_id)
        # Remove the data (it's already saved to the database)
        self.redis_client.delete(f"keep:alerts:data:{alert_id}")
        # Update metrics
        self.redis_client.hincrby("keep:alerts:metrics", "successfully_processed", 1)
        
    def fail_processing(self, alert_id, error_data):
        """Move an alert to the dead-letter queue after processing failure"""
        # Remove from processing queue
        self.redis_client.lrem(self.processing_queue, 0, alert_id)
        
        # Add to dead letter queue with error information
        error_info = {
            "alert_id": alert_id,
            "error": str(error_data),
            "timestamp": time.time()
        }
        self.redis_client.lpush(self.dead_letter_queue, json.dumps(error_info))
        
        # Update metrics
        self.redis_client.hincrby("keep:alerts:metrics", "processing_failures", 1)
        
    def get_queue_metrics(self):
        """Get queue statistics for monitoring"""
        metrics = {}
        
        # Get metrics from Redis
        raw_metrics = self.redis_client.hgetall("keep:alerts:metrics")
        if raw_metrics:
            for k, v in raw_metrics.items():
                if isinstance(k, bytes):
                    k = k.decode('utf-8')
                if isinstance(v, bytes):
                    v = v.decode('utf-8')
                metrics[k] = int(v)
        
        # Get current queue lengths
        for priority in AlertPriority:
            queue_key = self.priority_queues[priority]
            metrics[f"queue_length:{priority.name.lower()}"] = self.redis_client.llen(queue_key)
        
        # Additional important metrics
        metrics["processing_queue_length"] = self.redis_client.llen(self.processing_queue)
        metrics["dead_letter_queue_length"] = self.redis_client.llen(self.dead_letter_queue)
        
        return metrics
    
    def clear_stalled_processing(self, max_processing_time=3600):
        """Return alerts that have been in processing too long back to their original queues"""
        processing_items = self.redis_client.lrange(self.processing_queue, 0, -1)
        recovered = 0
        
        for alert_id in processing_items:
            if isinstance(alert_id, bytes):
                alert_id = alert_id.decode('utf-8')
                
            data_key = f"keep:alerts:data:{alert_id}"
            alert_data = self.redis_client.get(data_key)
            
            if alert_data:
                if isinstance(alert_data, bytes):
                    alert_data = alert_data.decode('utf-8')
                
                # Parse the data to determine priority
                alert_json = json.loads(alert_data)
                priority = self.determine_priority(alert_json)
                queue_key = self.priority_queues[priority]
                
                # Use pipeline for atomic operations
                pipe = self.redis_client.pipeline()
                # Remove from processing queue
                pipe.lrem(self.processing_queue, 0, alert_id)
                # Add back to the appropriate priority queue
                pipe.lpush(queue_key, alert_id)
                pipe.execute()
                
                recovered += 1
                logger.info(f"Recovered stalled alert {alert_id} back to {priority.name} queue")
        
        return recovered
```

### Step 2: Update the alert processing code in `keep/api/routes/alerts.py` to use the queue manager:

```python
from keep.api.core.queue_manager import QueueManager
from keep.api.config import REDIS

# In your /alerts/event endpoint
@router.post("/event", status_code=202)
async def create_event(request: Request, background_tasks: BackgroundTasks):
    alert_data = await request.json()
    
    if REDIS:
        # Use Redis queue for high-volume processing
        queue_manager = QueueManager()
        alert_id = queue_manager.enqueue_alert(alert_data)
        return {"status": "queued", "alert_id": alert_id}
    else:
        # Use in-memory processing for low volumes
        background_tasks.add_task(process_event, alert_data)
        return {"status": "processing"}
```

## 3. Monitoring Dashboard

For high-volume environments, we need a monitoring dashboard to track queue health.

### Step 1: Add a monitoring endpoint in `keep/api/routes/admin.py`:

```python
from fastapi import APIRouter, Depends
from keep.api.core.queue_manager import QueueManager
from keep.api.core.redis_client import RedisClient

router = APIRouter(prefix="/admin", tags=["Admin"])

@router.get("/queue/health")
async def queue_health():
    """Health check endpoint for the Redis queue system"""
    redis_client = RedisClient.get_instance()
    is_redis_available = redis_client.ping()
    
    result = {
        "redis_available": is_redis_available,
        "queue_status": "healthy" if is_redis_available else "unavailable"
    }
    
    if is_redis_available:
        # Get queue metrics
        queue_manager = QueueManager()
        metrics = queue_manager.get_queue_metrics()
        result["metrics"] = metrics
        
        # Determine health based on metrics
        processing_queue_length = metrics.get("processing_queue_length", 0)
        dead_letter_length = metrics.get("dead_letter_queue_length", 0)
        
        # Check for unhealthy conditions
        if processing_queue_length > 1000:
            result["queue_status"] = "backlogged"
        
        if dead_letter_length > 100:
            result["queue_status"] = "errors"
            
    return result

@router.post("/queue/recover-stalled")
async def recover_stalled_alerts():
    """Recover alerts that have been stuck in processing"""
    queue_manager = QueueManager()
    recovered = queue_manager.clear_stalled_processing()
    return {"recovered_alerts": recovered}
```

### Step 2: Create a simple front-end view for the queue metrics in `keep-ui/src/pages/admin/QueueMonitor.tsx`:

```tsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Card, CardHeader, CardContent, Grid, Typography, CircularProgress, Button, Alert } from '@mui/material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const QueueMonitor = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [metrics, setMetrics] = useState<any>({});
  const [queueStatus, setQueueStatus] = useState<string>('unknown');
  const [historicalData, setHistoricalData] = useState<any[]>([]);

  const fetchMetrics = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/admin/queue/health');
      setMetrics(response.data.metrics || {});
      setQueueStatus(response.data.queue_status);
      
      // Add current metrics to historical data
      setHistoricalData(prev => {
        const newPoint = {
          time: new Date().toLocaleTimeString(),
          ...response.data.metrics
        };
        // Keep last 20 data points
        const updatedData = [...prev, newPoint].slice(-20);
        return updatedData;
      });
      
      setError(null);
    } catch (err) {
      setError('Failed to fetch queue metrics');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
    // Refresh every 10 seconds
    const interval = setInterval(fetchMetrics, 10000);
    return () => clearInterval(interval);
  }, []);

  const recoverStalledAlerts = async () => {
    try {
      const response = await axios.post('/api/admin/queue/recover-stalled');
      alert(`Recovered ${response.data.recovered_alerts} stalled alerts`);
      fetchMetrics();
    } catch (err) {
      setError('Failed to recover stalled alerts');
      console.error(err);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy': return 'success.main';
      case 'backlogged': return 'warning.main';
      case 'errors': return 'error.main';
      default: return 'info.main';
    }
  };

  if (loading && !Object.keys(metrics).length) {
    return <CircularProgress />;
  }

  return (
    <div>
      <Typography variant="h4" gutterBottom>Redis Queue Monitor</Typography>
      
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      
      <Card sx={{ mb: 4 }}>
        <CardHeader 
          title="Queue Status" 
          subheader={
            <Typography 
              color={getStatusColor(queueStatus)}
              variant="h6"
            >
              {queueStatus.toUpperCase()}
            </Typography>
          }
        />
        <CardContent>
          <Button 
            variant="contained" 
            color="primary" 
            onClick={recoverStalledAlerts}
            sx={{ mb: 2 }}
          >
            Recover Stalled Alerts
          </Button>
          
          <Grid container spacing={3}>
            {/* Queue Lengths */}
            <Grid item xs={12} md={6}>
              <Card>
                <CardHeader title="Queue Lengths" />
                <CardContent>
                  <Typography>Critical: {metrics['queue_length:critical'] || 0}</Typography>
                  <Typography>High: {metrics['queue_length:high'] || 0}</Typography>
                  <Typography>Medium: {metrics['queue_length:medium'] || 0}</Typography>
                  <Typography>Low: {metrics['queue_length:low'] || 0}</Typography>
                  <Typography>Processing: {metrics['processing_queue_length'] || 0}</Typography>
                  <Typography color="error">
                    Dead Letter: {metrics['dead_letter_queue_length'] || 0}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            
            {/* Processing Metrics */}
            <Grid item xs={12} md={6}>
              <Card>
                <CardHeader title="Processing Metrics" />
                <CardContent>
                  <Typography>
                    Total Enqueued: {metrics['total_enqueued'] || 0}
                  </Typography>
                  <Typography>
                    Total Dequeued: {metrics['total_dequeued'] || 0}
                  </Typography>
                  <Typography>
                    Successfully Processed: {metrics['successfully_processed'] || 0}
                  </Typography>
                  <Typography color="error">
                    Processing Failures: {metrics['processing_failures'] || 0}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
      
      {/* Historical Chart */}
      <Card>
        <CardHeader title="Queue Activity (Last 20 Updates)" />
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={historicalData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="queue_length:critical" stroke="#ff0000" name="Critical" />
              <Line type="monotone" dataKey="queue_length:high" stroke="#ff9900" name="High" />
              <Line type="monotone" dataKey="queue_length:medium" stroke="#0066ff" name="Medium" />
              <Line type="monotone" dataKey="queue_length:low" stroke="#009900" name="Low" />
              <Line type="monotone" dataKey="processing_queue_length" stroke="#9900cc" name="Processing" />
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </div>
  );
};

export default QueueMonitor;
```

## 4. Implementation Steps (Execution Order)

Follow these steps in order to implement this task:

1. Create the Redis client class with connection pooling
2. Implement the queue manager with priority queues
3. Update the alert endpoint to use the queue manager
4. Add admin endpoints for queue monitoring
5. Create the front-end dashboard

## 5. Testing Your Implementation

Here's how to test that your implementation works correctly:

```python
# Test script - save as test_redis_queue.py
import requests
import json
import time
import random

# Configuration
BASE_URL = "http://localhost:8000"
NUM_ALERTS = 1000
ALERT_TYPES = ["critical", "high", "medium", "low"]

# Generate and send test alerts
for i in range(NUM_ALERTS):
    # Create random alert data
    severity = random.choice(ALERT_TYPES)
    alert_data = {
        "title": f"Test Alert {i}",
        "severity": severity,
        "source": "test_script",
        "timestamp": time.time(),
        "description": f"This is test alert {i} with {severity} severity"
    }
    
    # Send to the alert endpoint
    response = requests.post(f"{BASE_URL}/api/alerts/event", json=alert_data)
    
    # Print status every 100 alerts
    if i % 100 == 0:
        print(f"Sent {i} alerts, last response: {response.status_code}")
    
    # Small delay to avoid overwhelming the server
    time.sleep(0.01)

# Check the queue status
response = requests.get(f"{BASE_URL}/api/admin/queue/health")
print("Queue Status:")
print(json.dumps(response.json(), indent=2))
```

## 6. Common Pitfalls to Avoid

1. **Connection Management**: Don't create a new Redis connection for each request. Use connection pooling.
2. **Error Handling**: Always handle Redis connection errors gracefully.
3. **Memory Leaks**: Ensure that processed alerts are removed from both processing queues and data storage.
4. **Monitoring**: Don't forget to implement queue monitoring to detect backlogs.
5. **Serialization**: Always handle serialization/deserialization properly, especially for bytes vs. strings in Redis.

## 7. Advanced Considerations (Optional)

For even better performance in extremely high-volume environments:

1. **Queue Sharding**: Implement multiple queues based on alert source or tenant.
2. **Cluster Mode**: Configure Redis for cluster mode for horizontal scalability.
3. **Lua Scripts**: Use Redis Lua scripts for complex atomic operations.
4. **Compression**: Compress alert data for large payloads to reduce Redis memory usage.

## Helpful Resources

- [Redis Documentation](https://redis.io/documentation)
- [Redis Python Client](https://github.com/redis/redis-py)
- [Redis Queue Patterns](https://redis.com/redis-best-practices/communication-patterns/queue/) 