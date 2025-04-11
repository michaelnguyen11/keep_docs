# Task 2: Worker Pool Optimization Guidelines

This document provides detailed guidance for optimizing the worker pool for high-volume alert processing in Keep.

## Overview

The current Keep system uses a ThreadPoolExecutor for processing alerts. For handling 600GB/day, we need to enhance the worker pool implementation to handle higher volumes, optimize resource usage, and provide better monitoring.

## 1. Scaling ThreadPoolExecutor

### Current Implementation

In `keep/api/tasks/process_event_task.py`, a fixed number of workers is used:

```python
# Current implementation
KEEP_EVENT_WORKERS = int(os.getenv("KEEP_EVENT_WORKERS", "5"))
executor = ThreadPoolExecutor(max_workers=KEEP_EVENT_WORKERS)
```

### Required Changes

#### Step 1: Update worker configuration in `keep/api/config.py`:

```python
# Update to scale with CPU cores
import os
import multiprocessing

# Base worker count on CPU cores with a reasonable minimum
CPU_CORES = multiprocessing.cpu_count()
DEFAULT_WORKERS = max(10, CPU_CORES * 2)  # At least 10, or 2x CPU cores

# Worker configuration
KEEP_EVENT_WORKERS = int(os.getenv("KEEP_EVENT_WORKERS", DEFAULT_WORKERS))
KEEP_WORKER_MAX_QUEUE_SIZE = int(os.getenv("KEEP_WORKER_MAX_QUEUE_SIZE", 10000))
KEEP_WORKER_DYNAMIC_SCALING = getenv_as_bool("KEEP_WORKER_DYNAMIC_SCALING", True)
KEEP_WORKER_MIN_WORKERS = int(os.getenv("KEEP_WORKER_MIN_WORKERS", DEFAULT_WORKERS))
KEEP_WORKER_MAX_WORKERS = int(os.getenv("KEEP_WORKER_MAX_WORKERS", DEFAULT_WORKERS * 4))
KEEP_WORKER_SCALING_THRESHOLD = float(os.getenv("KEEP_WORKER_SCALING_THRESHOLD", 0.7))
```

#### Step 2: Create an advanced worker pool in `keep/api/core/worker_pool.py`:

```python
import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any, Callable, List
import psutil
from keep.api.config import (
    KEEP_EVENT_WORKERS, KEEP_WORKER_DYNAMIC_SCALING,
    KEEP_WORKER_MIN_WORKERS, KEEP_WORKER_MAX_WORKERS,
    KEEP_WORKER_SCALING_THRESHOLD, KEEP_WORKER_MAX_QUEUE_SIZE
)

logger = logging.getLogger(__name__)

class WorkerStats:
    """Track statistics for workers"""
    def __init__(self):
        self.tasks_processed = 0
        self.tasks_errored = 0
        self.processing_times: List[float] = []
        self.last_error = None
        self.max_memory_mb = 0
        self.lock = threading.Lock()
        
    def record_success(self, processing_time: float):
        with self.lock:
            self.tasks_processed += 1
            self.processing_times.append(processing_time)
            # Keep only the last 1000 times
            if len(self.processing_times) > 1000:
                self.processing_times = self.processing_times[-1000:]
            
    def record_error(self, error):
        with self.lock:
            self.tasks_errored += 1
            self.last_error = str(error)
            
    def record_memory(self, memory_mb: float):
        with self.lock:
            self.max_memory_mb = max(self.max_memory_mb, memory_mb)
            
    def get_avg_processing_time(self) -> float:
        with self.lock:
            if not self.processing_times:
                return 0
            return sum(self.processing_times) / len(self.processing_times)
            
    def get_stats(self) -> Dict[str, Any]:
        with self.lock:
            return {
                "tasks_processed": self.tasks_processed,
                "tasks_errored": self.tasks_errored,
                "avg_processing_time": self.get_avg_processing_time(),
                "last_error": self.last_error,
                "max_memory_mb": self.max_memory_mb
            }

class DynamicWorkerPool:
    """Advanced worker pool with dynamic scaling and monitoring"""
    def __init__(self):
        self.min_workers = KEEP_WORKER_MIN_WORKERS
        self.max_workers = KEEP_WORKER_MAX_WORKERS
        self.current_workers = KEEP_EVENT_WORKERS
        self.dynamic_scaling = KEEP_WORKER_DYNAMIC_SCALING
        self.scaling_threshold = KEEP_WORKER_SCALING_THRESHOLD
        self.max_queue_size = KEEP_WORKER_MAX_QUEUE_SIZE
        
        self.executor = ThreadPoolExecutor(max_workers=self.current_workers)
        self.stats = WorkerStats()
        self.active_tasks = 0
        self.active_tasks_lock = threading.Lock()
        self.circuit_breaker_open = False
        self.circuit_breaker_lock = threading.Lock()
        
        # Start monitoring thread
        self.shutdown_event = threading.Event()
        self.monitor_thread = threading.Thread(target=self._monitor_workers)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        
        logger.info(f"Worker pool initialized with {self.current_workers} workers")
        
    def submit(self, fn: Callable, *args, **kwargs) -> None:
        """Submit task to the pool with stats tracking"""
        if self.circuit_breaker_open:
            logger.warning("Circuit breaker open, rejecting new task")
            raise RuntimeError("Circuit breaker open")
            
        with self.active_tasks_lock:
            if self.active_tasks >= self.max_queue_size:
                logger.warning(f"Queue full ({self.active_tasks} active tasks), rejecting new task")
                raise RuntimeError("Queue full")
            self.active_tasks += 1
            
        def wrapped_fn(*args, **kwargs):
            start_time = time.time()
            process = psutil.Process()
            initial_memory = process.memory_info().rss / (1024 * 1024)  # MB
            
            try:
                result = fn(*args, **kwargs)
                processing_time = time.time() - start_time
                self.stats.record_success(processing_time)
                return result
            except Exception as e:
                self.stats.record_error(e)
                logger.exception(f"Error in worker task: {str(e)}")
                raise
            finally:
                current_memory = process.memory_info().rss / (1024 * 1024)  # MB
                memory_used = current_memory - initial_memory
                self.stats.record_memory(memory_used)
                
                with self.active_tasks_lock:
                    self.active_tasks -= 1
        
        return self.executor.submit(wrapped_fn, *args, **kwargs)
        
    def _monitor_workers(self):
        """Monitor and dynamically adjust worker count"""
        while not self.shutdown_event.is_set():
            try:
                self._check_health()
                
                if self.dynamic_scaling:
                    self._adjust_worker_count()
                    
                # Sleep for 5 seconds
                self.shutdown_event.wait(5)
            except Exception as e:
                logger.exception(f"Error in worker monitor: {str(e)}")
                self.shutdown_event.wait(10)  # Wait longer if we hit an error
                
    def _check_health(self):
        """Check for deadlocks and high error rates"""
        stats = self.stats.get_stats()
        
        # Check for high error rate (more than 20% failures)
        error_rate = 0
        if stats["tasks_processed"] + stats["tasks_errored"] > 0:
            error_rate = stats["tasks_errored"] / (stats["tasks_processed"] + stats["tasks_errored"])
            
        # Open circuit breaker if error rate is too high
        with self.circuit_breaker_lock:
            if error_rate > 0.2 and not self.circuit_breaker_open:
                self.circuit_breaker_open = True
                logger.critical(f"Opening circuit breaker due to high error rate: {error_rate:.2f}")
            elif error_rate <= 0.1 and self.circuit_breaker_open:
                self.circuit_breaker_open = False
                logger.info("Closing circuit breaker, error rate back to normal")
                
    def _adjust_worker_count(self):
        """Dynamically adjust worker count based on load"""
        with self.active_tasks_lock:
            queue_usage = self.active_tasks / self.max_queue_size
            current_usage = self.active_tasks / self.current_workers
            
            # Scale up if we're above threshold and not at max
            if current_usage > self.scaling_threshold and self.current_workers < self.max_workers:
                new_workers = min(self.current_workers + 5, self.max_workers)
                logger.info(f"Scaling up workers from {self.current_workers} to {new_workers}")
                
                # Create new executor with more workers
                old_executor = self.executor
                self.executor = ThreadPoolExecutor(max_workers=new_workers)
                self.current_workers = new_workers
                
                # Shutdown old executor gracefully
                old_executor.shutdown(wait=False)
                
            # Scale down if we're below threshold and above min
            elif current_usage < self.scaling_threshold/2 and queue_usage < 0.3 and self.current_workers > self.min_workers:
                new_workers = max(self.current_workers - 3, self.min_workers)
                logger.info(f"Scaling down workers from {self.current_workers} to {new_workers}")
                
                # Create new executor with fewer workers
                old_executor = self.executor  
                self.executor = ThreadPoolExecutor(max_workers=new_workers)
                self.current_workers = new_workers
                
                # Shutdown old executor gracefully
                old_executor.shutdown(wait=False)
                
    def get_stats(self) -> Dict[str, Any]:
        """Get worker pool statistics"""
        stats = self.stats.get_stats()
        
        # Add pool stats
        with self.active_tasks_lock:
            stats["active_tasks"] = self.active_tasks
            stats["current_workers"] = self.current_workers
            stats["queue_usage"] = self.active_tasks / self.max_queue_size
            stats["worker_usage"] = self.active_tasks / self.current_workers if self.current_workers > 0 else 0
            
        with self.circuit_breaker_lock:
            stats["circuit_breaker_open"] = self.circuit_breaker_open
            
        return stats
        
    def shutdown(self, wait=True):
        """Gracefully shutdown the worker pool"""
        self.shutdown_event.set()
        if self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=5)
        self.executor.shutdown(wait=wait)
        logger.info("Worker pool shut down")

# Singleton instance
_worker_pool = None

def get_worker_pool() -> DynamicWorkerPool:
    """Get the global worker pool instance"""
    global _worker_pool
    if _worker_pool is None:
        _worker_pool = DynamicWorkerPool()
    return _worker_pool
```

## 2. Using the Enhanced Worker Pool

### Step 1: Update the process_event task in `keep/api/tasks/process_event_task.py`:

```python
from keep.api.core.worker_pool import get_worker_pool
from keep.api.core.queue_manager import QueueManager
import logging
import time
import traceback

logger = logging.getLogger(__name__)

def process_event(alert_data):
    """Process an alert event"""
    start_time = time.time()
    
    try:
        # Your existing alert processing logic here
        # ...
        
        processing_time = time.time() - start_time
        logger.info(f"Processed alert in {processing_time:.2f}s")
        
        # If using Redis queue, mark as complete
        if "alert_id" in alert_data and hasattr(alert_data, "_queue_id"):
            queue_manager = QueueManager()
            queue_manager.complete_processing(alert_data._queue_id)
            
        return True
        
    except Exception as e:
        logger.exception(f"Error processing alert: {str(e)}")
        
        # If using Redis queue, mark as failed
        if "alert_id" in alert_data and hasattr(alert_data, "_queue_id"):
            queue_manager = QueueManager()
            queue_manager.fail_processing(alert_data._queue_id, str(e))
            
        return False

def start_worker_pool():
    """Initialize and start the worker pool"""
    worker_pool = get_worker_pool()
    logger.info(f"Worker pool started with {worker_pool.current_workers} workers")

def submit_event(alert_data):
    """Submit an event to the worker pool"""
    worker_pool = get_worker_pool()
    try:
        return worker_pool.submit(process_event, alert_data)
    except RuntimeError as e:
        logger.error(f"Failed to submit task: {str(e)}")
        return None
```

## 3. Adding Worker Pool Monitoring

### Step 1: Add endpoints to monitor worker health in `keep/api/routes/admin.py`:

```python
from keep.api.core.worker_pool import get_worker_pool

@router.get("/workers/stats")
async def get_worker_stats():
    """Get worker pool statistics"""
    worker_pool = get_worker_pool()
    return worker_pool.get_stats()

@router.post("/workers/reset-circuit-breaker")
async def reset_circuit_breaker():
    """Manually reset the circuit breaker"""
    worker_pool = get_worker_pool()
    with worker_pool.circuit_breaker_lock:
        was_open = worker_pool.circuit_breaker_open
        worker_pool.circuit_breaker_open = False
    
    return {"status": "reset", "was_open": was_open}
```

### Step 2: Create a worker monitoring component in the UI (`keep-ui/src/pages/admin/WorkerMonitor.tsx`):

```tsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Card, CardHeader, CardContent, Typography, 
  CircularProgress, Button, Alert, Box,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper
} from '@mui/material';

const WorkerMonitor = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState<any>({});

  const fetchStats = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/admin/workers/stats');
      setStats(response.data);
      setError(null);
    } catch (err) {
      setError('Failed to fetch worker stats');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
    // Refresh every 5 seconds
    const interval = setInterval(fetchStats, 5000);
    return () => clearInterval(interval);
  }, []);

  const resetCircuitBreaker = async () => {
    try {
      await axios.post('/api/admin/workers/reset-circuit-breaker');
      fetchStats();
    } catch (err) {
      setError('Failed to reset circuit breaker');
      console.error(err);
    }
  };

  if (loading && Object.keys(stats).length === 0) {
    return <CircularProgress />;
  }

  const workerUsagePercent = (stats.worker_usage || 0) * 100;
  const queueUsagePercent = (stats.queue_usage || 0) * 100;

  return (
    <div>
      <Typography variant="h4" gutterBottom>Worker Pool Monitor</Typography>
      
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      
      {stats.circuit_breaker_open && (
        <Alert 
          severity="error" 
          sx={{ mb: 2 }}
          action={
            <Button 
              color="inherit" 
              size="small"
              onClick={resetCircuitBreaker}
            >
              Reset
            </Button>
          }
        >
          Circuit breaker is open! The system is experiencing high error rates.
        </Alert>
      )}
      
      <TableContainer component={Paper} sx={{ mb: 4 }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Metric</TableCell>
              <TableCell>Value</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            <TableRow>
              <TableCell>Active Tasks</TableCell>
              <TableCell>{stats.active_tasks || 0}</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Current Workers</TableCell>
              <TableCell>{stats.current_workers || 0}</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Tasks Processed</TableCell>
              <TableCell>{stats.tasks_processed || 0}</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Tasks Errored</TableCell>
              <TableCell>{stats.tasks_errored || 0}</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Avg Processing Time</TableCell>
              <TableCell>{stats.avg_processing_time ? `${stats.avg_processing_time.toFixed(2)}s` : 'N/A'}</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Max Memory Used</TableCell>
              <TableCell>{stats.max_memory_mb ? `${stats.max_memory_mb.toFixed(2)} MB` : 'N/A'}</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </TableContainer>
      
      <Card sx={{ mb: 4 }}>
        <CardHeader title="Resource Usage" />
        <CardContent>
          <Typography variant="subtitle1">Worker Utilization</Typography>
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
            <Box sx={{ width: '100%', mr: 1 }}>
              <div 
                style={{ 
                  height: 20, 
                  width: `${workerUsagePercent}%`, 
                  backgroundColor: workerUsagePercent > 80 ? 'red' : workerUsagePercent > 50 ? 'orange' : 'green',
                  borderRadius: 4
                }} 
              />
            </Box>
            <Box sx={{ minWidth: 35 }}>
              <Typography variant="body2" color="text.secondary">{`${workerUsagePercent.toFixed(1)}%`}</Typography>
            </Box>
          </Box>
          
          <Typography variant="subtitle1">Queue Utilization</Typography>
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            <Box sx={{ width: '100%', mr: 1 }}>
              <div 
                style={{ 
                  height: 20, 
                  width: `${queueUsagePercent}%`, 
                  backgroundColor: queueUsagePercent > 80 ? 'red' : queueUsagePercent > 50 ? 'orange' : 'green',
                  borderRadius: 4
                }} 
              />
            </Box>
            <Box sx={{ minWidth: 35 }}>
              <Typography variant="body2" color="text.secondary">{`${queueUsagePercent.toFixed(1)}%`}</Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>
      
      {stats.last_error && (
        <Card>
          <CardHeader title="Last Error" />
          <CardContent>
            <Typography component="pre" sx={{ whiteSpace: 'pre-wrap', fontFamily: 'monospace' }}>
              {stats.last_error}
            </Typography>
          </CardContent>
        </Card>
      )}
    </div>
  );
};

export default WorkerMonitor;
```

## 4. Implementation Steps

1. Update the config file with worker pool settings
2. Create the DynamicWorkerPool class
3. Modify the process_event task to use the new worker pool
4. Add worker monitoring endpoints
5. Create the UI monitoring component

## 5. Testing Your Implementation

```python
# test_worker_pool.py
import requests
import json
import time
import random
import threading
from concurrent.futures import ThreadPoolExecutor

# Configuration
BASE_URL = "http://localhost:8000"
NUM_ALERTS = 5000  # Test with a large number of alerts
CONCURRENCY = 20   # Number of concurrent threads

def send_alert(i):
    """Send a test alert"""
    # Create random alert data
    severity = random.choice(["critical", "high", "medium", "low"])
    alert_data = {
        "title": f"Test Alert {i}",
        "severity": severity,
        "source": "test_script",
        "timestamp": time.time(),
        "description": f"This is test alert {i} with {severity} severity"
    }
    
    # Add random sleep to simulate network variance
    time.sleep(random.uniform(0.01, 0.1))
    
    # Send to the alert endpoint
    try:
        response = requests.post(f"{BASE_URL}/api/alerts/event", json=alert_data, timeout=5)
        return response.status_code
    except requests.exceptions.RequestException as e:
        return f"Error: {str(e)}"

# Use ThreadPoolExecutor to send alerts concurrently
with ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
    futures = [executor.submit(send_alert, i) for i in range(NUM_ALERTS)]
    
    # Wait for all alerts to be sent
    for i, future in enumerate(futures):
        result = future.result()
        if i % 100 == 0:
            print(f"Sent {i} alerts, last status: {result}")

# Check worker stats
print("\nWorker Stats:")
try:
    response = requests.get(f"{BASE_URL}/api/admin/workers/stats")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error getting worker stats: {str(e)}")
```

## 6. Common Pitfalls to Avoid

1. **Thread Safety**: Always use locks for shared resources to avoid race conditions
2. **Resource Leaks**: Ensure executor shutdown is handled properly
3. **Deadlocks**: Be careful with nested locks that could cause deadlocks
4. **Memory Usage**: Monitor memory usage to avoid worker processes using too much memory
5. **Error Propagation**: Always catch and log exceptions from worker threads

## 7. Advanced Optimization Tips

1. **Batched Processing**: For even higher throughput, process alerts in batches rather than one at a time
2. **Worker Affinity**: Pin workers to specific CPU cores for better cache efficiency
3. **Adaptive Timeouts**: Implement adaptive timeouts based on system load
4. **Worker Isolation**: Consider process-based workers instead of threads for better isolation

## Helpful Resources

- [Python ThreadPoolExecutor Documentation](https://docs.python.org/3/library/concurrent.futures.html#threadpoolexecutor)
- [Python Threading Documentation](https://docs.python.org/3/library/threading.html)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [psutil Documentation](https://psutil.readthedocs.io/en/latest/) 