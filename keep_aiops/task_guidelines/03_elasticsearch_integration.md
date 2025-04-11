# Task 3: Elasticsearch Integration for Historical Alerts

This document provides detailed guidance for implementing Elasticsearch integration for historical alert storage in Keep.

## Overview

For a high-volume environment processing 600GB/day of alerts, we need an efficient way to store and query historical alert data. Elasticsearch provides the scalability and search capabilities needed for this volume of data.

## 1. Creating the Elasticsearch Client

### Step 1: Add Elasticsearch configuration to `keep/api/config.py`:

```python
# Elasticsearch configuration
ES_ENABLED = getenv_as_bool("KEEP_ES_ENABLED", True)
ES_HOSTS = os.getenv("KEEP_ES_HOSTS", "http://localhost:9200").split(",")
ES_USERNAME = os.getenv("KEEP_ES_USERNAME", "")
ES_PASSWORD = os.getenv("KEEP_ES_PASSWORD", "")
ES_INDEX_PREFIX = os.getenv("KEEP_ES_INDEX_PREFIX", "keep-alerts-")
ES_ARCHIVE_DAYS = int(os.getenv("KEEP_ES_ARCHIVE_DAYS", 30))
ES_DELETE_DAYS = int(os.getenv("KEEP_ES_DELETE_DAYS", 90))
ES_BULK_SIZE = int(os.getenv("KEEP_ES_BULK_SIZE", 1000))
ES_SHARDS = int(os.getenv("KEEP_ES_SHARDS", 5))
ES_REPLICAS = int(os.getenv("KEEP_ES_REPLICAS", 1))
```

### Step 2: Implement an Elasticsearch client in `keep/api/core/elastic.py`:

```python
from elasticsearch import Elasticsearch, helpers
from elasticsearch.exceptions import NotFoundError
import logging
import time
from datetime import datetime, timedelta
import json
from typing import Dict, List, Any, Optional, Iterator
from keep.api.config import (
    ES_ENABLED, ES_HOSTS, ES_USERNAME, ES_PASSWORD, ES_INDEX_PREFIX,
    ES_ARCHIVE_DAYS, ES_DELETE_DAYS, ES_BULK_SIZE, ES_SHARDS, ES_REPLICAS
)

logger = logging.getLogger(__name__)

class ElasticClient:
    """Client for Elasticsearch operations"""
    _instance = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        self.enabled = ES_ENABLED
        self.index_prefix = ES_INDEX_PREFIX
        self.archive_days = ES_ARCHIVE_DAYS
        self.delete_days = ES_DELETE_DAYS
        self.bulk_size = ES_BULK_SIZE
        
        # Connect to Elasticsearch
        if not self.enabled:
            logger.info("Elasticsearch integration is disabled")
            self.client = None
            return
            
        auth = None
        if ES_USERNAME and ES_PASSWORD:
            auth = (ES_USERNAME, ES_PASSWORD)
            
        self.client = Elasticsearch(
            hosts=ES_HOSTS,
            basic_auth=auth,
            retry_on_timeout=True,
            max_retries=5
        )
        
        # Create index templates
        self._create_index_template()
        logger.info(f"Elasticsearch client initialized with hosts: {ES_HOSTS}")
        
    def _create_index_template(self):
        """Create index template for alerts"""
        if not self.enabled or not self.client:
            return
            
        template_name = f"{self.index_prefix}template"
        
        # Check if template exists
        try:
            existing = self.client.indices.get_index_template(name=template_name)
            if existing:
                logger.debug(f"Index template {template_name} already exists")
                return
        except NotFoundError:
            pass
        
        # Alert mapping
        mapping = {
            "mappings": {
                "properties": {
                    "alert_id": {"type": "keyword"},
                    "fingerprint": {"type": "keyword"},
                    "title": {
                        "type": "text",
                        "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}
                    },
                    "description": {"type": "text"},
                    "status": {"type": "keyword"},
                    "severity": {"type": "keyword"},
                    "source": {"type": "keyword"},
                    "source_link": {"type": "keyword"},
                    "source_incident_id": {"type": "keyword"},
                    "created_at": {"type": "date"},
                    "last_seen_at": {"type": "date"},
                    "first_seen_at": {"type": "date"},
                    "environment": {"type": "keyword"},
                    "team": {"type": "keyword"},
                    "owner": {"type": "keyword"},
                    "tags": {"type": "keyword"},
                    "metadata": {"type": "object", "enabled": False},
                    "service": {"type": "keyword"},
                    "count": {"type": "integer"},
                    # Add any additional fields needed
                }
            },
            "settings": {
                "number_of_shards": ES_SHARDS,
                "number_of_replicas": ES_REPLICAS,
                "index.mapping.total_fields.limit": 2000,
                "index.mapping.nested_fields.limit": 50
            },
            "index_patterns": [f"{self.index_prefix}*"],
        }
        
        # Create the template
        try:
            self.client.indices.put_index_template(name=template_name, body=mapping)
            logger.info(f"Created index template {template_name}")
        except Exception as e:
            logger.error(f"Failed to create index template: {str(e)}")
            
    def _get_index_name(self, date=None):
        """Get the index name for a specific date"""
        if date is None:
            date = datetime.now()
        return f"{self.index_prefix}{date.strftime('%Y.%m.%d')}"
        
    def index_alert(self, alert_data: Dict):
        """Index a single alert in Elasticsearch"""
        if not self.enabled or not self.client:
            return False
            
        try:
            # Generate ID from alert fingerprint or ID
            doc_id = alert_data.get("fingerprint") or alert_data.get("alert_id")
            if not doc_id:
                doc_id = f"alert-{int(time.time()*1000)}"
                
            # Add timestamp if missing
            if "created_at" not in alert_data:
                alert_data["created_at"] = datetime.now().isoformat()
                
            # Index the document
            index_name = self._get_index_name()
            self.client.index(
                index=index_name,
                id=doc_id,
                document=alert_data
            )
            return True
        except Exception as e:
            logger.error(f"Failed to index alert: {str(e)}")
            return False
            
    def bulk_index_alerts(self, alerts: List[Dict]):
        """Index multiple alerts in bulk"""
        if not self.enabled or not self.client or not alerts:
            return 0
            
        indexed = 0
        try:
            # Process in chunks to avoid overwhelming ES
            chunks = [alerts[i:i + self.bulk_size] for i in range(0, len(alerts), self.bulk_size)]
            
            for chunk in chunks:
                actions = []
                for alert in chunk:
                    # Generate ID from alert fingerprint or ID
                    doc_id = alert.get("fingerprint") or alert.get("alert_id")
                    if not doc_id:
                        doc_id = f"alert-{int(time.time()*1000)}"
                        
                    # Add timestamp if missing
                    if "created_at" not in alert:
                        alert["created_at"] = datetime.now().isoformat()
                        
                    # Create bulk action
                    actions.append({
                        "_index": self._get_index_name(),
                        "_id": doc_id,
                        "_source": alert
                    })
                
                # Execute bulk operation
                if actions:
                    success, failed = helpers.bulk(
                        self.client,
                        actions,
                        stats_only=True,
                        raise_on_error=False
                    )
                    indexed += success
                    if failed:
                        logger.warning(f"Failed to index {failed} alerts in bulk operation")
            
            return indexed
        except Exception as e:
            logger.error(f"Failed to bulk index alerts: {str(e)}")
            return indexed
            
    def search_alerts(self, query_params: Dict, size: int = 100, from_: int = 0) -> Dict:
        """Search for alerts in Elasticsearch"""
        if not self.enabled or not self.client:
            return {"total": 0, "results": []}
            
        try:
            # Build Elasticsearch query
            query = self._build_query(query_params)
            
            # Define which indices to search
            days_to_search = query_params.get("time_range_days", 7)
            indices = self._get_indices_for_timespan(days=days_to_search)
            
            if not indices:
                return {"total": 0, "results": []}
                
            # Execute search
            response = self.client.search(
                index=indices,
                body=query,
                size=size,
                from_=from_
            )
            
            # Process results
            hits = response.get("hits", {})
            total = hits.get("total", {}).get("value", 0)
            results = []
            
            for hit in hits.get("hits", []):
                source = hit.get("_source", {})
                results.append(source)
                
            return {
                "total": total,
                "results": results
            }
            
        except Exception as e:
            logger.error(f"Failed to search alerts: {str(e)}")
            return {"total": 0, "results": []}
            
    def _build_query(self, params: Dict) -> Dict:
        """Build an Elasticsearch query from parameters"""
        must_clauses = []
        
        # Handle search text
        if "search" in params and params["search"]:
            must_clauses.append({
                "multi_match": {
                    "query": params["search"],
                    "fields": ["title^3", "description^2", "source", "tags"]
                }
            })
            
        # Handle status filter
        if "status" in params and params["status"]:
            must_clauses.append({"term": {"status": params["status"]}})
            
        # Handle severity filter
        if "severity" in params and params["severity"]:
            must_clauses.append({"term": {"severity": params["severity"]}})
            
        # Handle date range
        date_range = {}
        if "from_date" in params and params["from_date"]:
            date_range["gte"] = params["from_date"]
        if "to_date" in params and params["to_date"]:
            date_range["lte"] = params["to_date"]
            
        if date_range:
            must_clauses.append({
                "range": {
                    "created_at": date_range
                }
            })
            
        # Add any other specific filters you need
        
        # Create the final query
        if must_clauses:
            query = {
                "query": {
                    "bool": {
                        "must": must_clauses
                    }
                },
                "sort": [
                    {"created_at": {"order": "desc"}}
                ]
            }
        else:
            # Default query to match all
            query = {
                "query": {"match_all": {}},
                "sort": [
                    {"created_at": {"order": "desc"}}
                ]
            }
            
        return query
        
    def _get_indices_for_timespan(self, days: int = 7) -> str:
        """Get a comma-separated list of indices for a given timespan"""
        if days <= 0:
            days = 7
            
        indices = []
        today = datetime.now()
        
        for i in range(days):
            date = today - timedelta(days=i)
            index_name = self._get_index_name(date)
            indices.append(index_name)
            
        return ",".join(indices)
        
    def archive_alerts(self, alert_models: List, batch_size: int = 1000) -> int:
        """Archive alerts to Elasticsearch from the database"""
        if not self.enabled or not self.client or not alert_models:
            return 0
            
        try:
            total_archived = 0
            
            # Process in batches
            for i in range(0, len(alert_models), batch_size):
                batch = alert_models[i:i + batch_size]
                alerts_to_index = []
                
                for alert_model in batch:
                    # Convert alert model to dictionary
                    alert_dict = self._model_to_dict(alert_model)
                    alerts_to_index.append(alert_dict)
                    
                # Bulk index the batch
                indexed = self.bulk_index_alerts(alerts_to_index)
                total_archived += indexed
                
            return total_archived
        except Exception as e:
            logger.error(f"Failed to archive alerts: {str(e)}")
            return 0
            
    def _model_to_dict(self, model) -> Dict:
        """Convert a database model to a dictionary for Elasticsearch"""
        # This should be customized based on your model structure
        # Example implementation - adjust based on your actual model
        if hasattr(model, "to_dict"):
            return model.to_dict()
        elif hasattr(model, "__dict__"):
            return {k: v for k, v in model.__dict__.items() if not k.startswith("_")}
        else:
            return {}
            
    def cleanup_old_indices(self) -> int:
        """Delete indices older than the configured retention period"""
        if not self.enabled or not self.client:
            return 0
            
        deleted = 0
        try:
            # Calculate cutoff date
            cutoff_date = datetime.now() - timedelta(days=self.delete_days)
            
            # Get all indices
            indices = self.client.indices.get(index=f"{self.index_prefix}*")
            
            for index_name in indices:
                # Extract date from index name
                date_part = index_name.replace(self.index_prefix, "")
                try:
                    index_date = datetime.strptime(date_part, "%Y.%m.%d")
                    
                    # Delete if older than cutoff
                    if index_date < cutoff_date:
                        self.client.indices.delete(index=index_name)
                        deleted += 1
                        logger.info(f"Deleted old index: {index_name}")
                except ValueError:
                    # Skip indices that don't match our date pattern
                    pass
                    
            return deleted
        except Exception as e:
            logger.error(f"Failed to clean up old indices: {str(e)}")
            return deleted
            
    def get_alert_count(self) -> int:
        """Get the total count of alerts in Elasticsearch"""
        if not self.enabled or not self.client:
            return 0
            
        try:
            response = self.client.count(index=f"{self.index_prefix}*")
            return response.get("count", 0)
        except Exception as e:
            logger.error(f"Failed to get alert count: {str(e)}")
            return 0
```

## 2. Implementing the Archiving Process

### Step 1: Create a background task for alert archiving in `keep/api/tasks/archive_alerts_task.py`:

```python
from keep.api.core.elastic import ElasticClient
from keep.api.models.db.alert import Alert
from sqlalchemy import func
from datetime import datetime, timedelta
import logging
from keep.api.database import get_session
from keep.api.config import ES_ARCHIVE_DAYS

logger = logging.getLogger(__name__)

def archive_old_alerts():
    """Archive alerts older than the configured retention period"""
    elastic_client = ElasticClient.get_instance()
    if not elastic_client.enabled:
        logger.info("Elasticsearch archiving disabled")
        return
        
    try:
        # Calculate cutoff date for archiving
        cutoff_date = datetime.now() - timedelta(days=ES_ARCHIVE_DAYS)
        
        with get_session() as session:
            # Get count of alerts to archive
            count_query = session.query(func.count(Alert.id)).filter(
                Alert.created_at < cutoff_date,
                Alert.archived.is_(False)  # Only archive alerts not already archived
            )
            alert_count = count_query.scalar()
            
            if alert_count == 0:
                logger.info("No alerts to archive")
                return
                
            logger.info(f"Found {alert_count} alerts to archive")
            
            # Get alerts in batches to avoid memory issues
            batch_size = 1000
            total_archived = 0
            
            for offset in range(0, alert_count, batch_size):
                alerts = session.query(Alert).filter(
                    Alert.created_at < cutoff_date,
                    Alert.archived.is_(False)
                ).limit(batch_size).offset(offset).all()
                
                # Archive to Elasticsearch
                archived = elastic_client.archive_alerts(alerts)
                
                if archived > 0:
                    # Mark alerts as archived in the database
                    alert_ids = [alert.id for alert in alerts[:archived]]
                    session.query(Alert).filter(Alert.id.in_(alert_ids)).update(
                        {"archived": True},
                        synchronize_session=False
                    )
                    session.commit()
                    total_archived += archived
                    
            logger.info(f"Archived {total_archived} alerts to Elasticsearch")
            
        # Clean up old indices
        deleted = elastic_client.cleanup_old_indices()
        if deleted > 0:
            logger.info(f"Deleted {deleted} old Elasticsearch indices")
            
    except Exception as e:
        logger.exception(f"Error during alert archiving: {str(e)}")
```

### Step 2: Schedule the archiving task in `keep/api/core/scheduler.py`:

```python
from keep.api.tasks.archive_alerts_task import archive_old_alerts
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import logging

logger = logging.getLogger(__name__)

def setup_scheduler():
    """Set up scheduled tasks"""
    scheduler = BackgroundScheduler()
    
    # Archive alerts daily at 3 AM
    scheduler.add_job(
        archive_old_alerts,
        trigger=CronTrigger(hour=3, minute=0),
        id="archive_alerts",
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("Alert archiving scheduler started")
    
    return scheduler
```

## 3. Implementing Query Federation

For high-volume environments, we want to be able to query both the database and Elasticsearch seamlessly.

### Step 1: Create a federated search service in `keep/api/services/alert_search_service.py`:

```python
from keep.api.core.elastic import ElasticClient
from keep.api.models.db.alert import Alert
from sqlalchemy import or_, and_, func
from typing import Dict, List, Any, Optional, Tuple
import logging
from keep.api.database import get_session
from keep.api.config import ES_ENABLED, ES_ARCHIVE_DAYS

logger = logging.getLogger(__name__)

class AlertSearchService:
    """Service for searching alerts across database and Elasticsearch"""
    
    @staticmethod
    def search_alerts(query_params: Dict, page: int = 1, size: int = 50) -> Dict:
        """
        Search for alerts using both database and Elasticsearch
        
        For recent alerts, we query the database
        For historical alerts, we query Elasticsearch
        """
        # Calculate offset
        offset = (page - 1) * size
        
        # Determine if we should use Elasticsearch
        use_elasticsearch = ES_ENABLED
        es_query_needed = False
        
        # Check if we need Elasticsearch for historical data
        if "from_date" in query_params and query_params["from_date"]:
            # If from_date is older than our archive threshold, use ES
            import dateutil.parser
            from datetime import datetime, timedelta
            
            try:
                from_date = dateutil.parser.parse(query_params["from_date"])
                archive_threshold = datetime.now() - timedelta(days=ES_ARCHIVE_DAYS)
                
                if from_date < archive_threshold:
                    es_query_needed = True
            except:
                pass
        
        results = []
        total = 0
        
        # Query database for recent alerts
        db_results, db_total = AlertSearchService._search_database(
            query_params, offset, size, es_query_needed
        )
        results.extend(db_results)
        total += db_total
        
        # Query Elasticsearch for historical alerts if needed
        if use_elasticsearch and es_query_needed:
            es_results, es_total = AlertSearchService._search_elasticsearch(
                query_params, offset, size
            )
            
            # If we have a mix of DB and ES results, we need to merge and sort
            if db_results and es_results:
                # Add all results and sort by created_at
                all_results = db_results + es_results
                sorted_results = sorted(
                    all_results, 
                    key=lambda x: x.get("created_at", ""), 
                    reverse=True
                )
                
                # Take only the requested page
                results = sorted_results[offset:offset+size]
                total = db_total + es_total
            else:
                results.extend(es_results)
                total += es_total
        
        return {
            "results": results,
            "total": total,
            "page": page,
            "size": size,
            "pages": (total + size - 1) // size if size > 0 else 0
        }
    
    @staticmethod
    def _search_database(
        query_params: Dict, offset: int, size: int, es_query_needed: bool
    ) -> Tuple[List[Dict], int]:
        """Search for alerts in the database"""
        try:
            with get_session() as session:
                # Build query
                query = session.query(Alert)
                
                # Apply filters
                if "search" in query_params and query_params["search"]:
                    search_term = f"%{query_params['search']}%"
                    query = query.filter(
                        or_(
                            Alert.title.ilike(search_term),
                            Alert.description.ilike(search_term)
                        )
                    )
                
                if "status" in query_params and query_params["status"]:
                    query = query.filter(Alert.status == query_params["status"])
                
                if "severity" in query_params and query_params["severity"]:
                    query = query.filter(Alert.severity == query_params["severity"])
                
                if "from_date" in query_params and query_params["from_date"]:
                    query = query.filter(Alert.created_at >= query_params["from_date"])
                
                if "to_date" in query_params and query_params["to_date"]:
                    query = query.filter(Alert.created_at <= query_params["to_date"])
                    
                # If ES query is needed, only get non-archived alerts from DB
                if es_query_needed:
                    query = query.filter(Alert.archived.is_(False))
                
                # Get total count
                total = query.count()
                
                # Get paginated results
                alerts = query.order_by(Alert.created_at.desc()).offset(offset).limit(size).all()
                
                # Convert to dict
                results = [alert.to_dict() for alert in alerts]
                
                return results, total
        except Exception as e:
            logger.error(f"Database search error: {str(e)}")
            return [], 0
    
    @staticmethod
    def _search_elasticsearch(query_params: Dict, offset: int, size: int) -> Tuple[List[Dict], int]:
        """Search for alerts in Elasticsearch"""
        elastic_client = ElasticClient.get_instance()
        if not elastic_client.enabled:
            return [], 0
            
        try:
            # Get results from Elasticsearch
            es_response = elastic_client.search_alerts(
                query_params, size=size, from_=offset
            )
            
            return es_response.get("results", []), es_response.get("total", 0)
        except Exception as e:
            logger.error(f"Elasticsearch search error: {str(e)}")
            return [], 0
```

### Step 2: Update the alert routes in `keep/api/routes/alerts.py` to use the federated search:

```python
from keep.api.services.alert_search_service import AlertSearchService

@router.get("")
async def get_alerts(
    request: Request,
    search: Optional[str] = None,
    status: Optional[str] = None,
    severity: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    page: int = 1,
    size: int = 50
):
    """Get alerts with federated search"""
    # Build query params
    query_params = {
        "search": search,
        "status": status,
        "severity": severity,
        "from_date": from_date,
        "to_date": to_date
    }
    
    # Filter out None values
    query_params = {k: v for k, v in query_params.items() if v is not None}
    
    # Get results from federated search
    results = AlertSearchService.search_alerts(query_params, page, size)
    
    return results
```

## 4. Implementation Steps

Follow these steps to implement the Elasticsearch integration:

1. Add Elasticsearch dependencies to your project
   ```
   pip install elasticsearch
   ```

2. Create the Elasticsearch client class
3. Implement the alert archiving background task
4. Create the scheduler to run archiving regularly
5. Implement the federated search service
6. Update the alert routes to use the federated search

## 5. Testing Your Implementation

Here's a test script to verify your Elasticsearch integration:

```python
# test_elasticsearch.py
import requests
import json
import time
import random
from datetime import datetime, timedelta

# Configuration
BASE_URL = "http://localhost:8000"

def test_elasticsearch_search():
    """Test the federated search capability"""
    # Search for recent alerts (should use database)
    print("Testing recent alerts search (database)...")
    response = requests.get(f"{BASE_URL}/api/alerts", params={
        "page": 1,
        "size": 10
    })
    
    if response.status_code == 200:
        data = response.json()
        print(f"Recent alerts: Found {data.get('total')} results")
    else:
        print(f"Error: {response.status_code}")
    
    # Search for historical alerts (should use Elasticsearch)
    # Calculate a date older than the archive threshold
    from_date = (datetime.now() - timedelta(days=45)).isoformat()
    
    print(f"\nTesting historical alerts search (Elasticsearch)...")
    response = requests.get(f"{BASE_URL}/api/alerts", params={
        "from_date": from_date,
        "page": 1,
        "size": 10
    })
    
    if response.status_code == 200:
        data = response.json()
        print(f"Historical alerts: Found {data.get('total')} results")
    else:
        print(f"Error: {response.status_code}")

def test_alert_count():
    """Test the Elasticsearch alert count endpoint"""
    print("\nTesting Elasticsearch alert count...")
    response = requests.get(f"{BASE_URL}/api/admin/elastic/count")
    
    if response.status_code == 200:
        data = response.json()
        print(f"Elasticsearch contains {data.get('count')} alerts")
    else:
        print(f"Error: {response.status_code}")

if __name__ == "__main__":
    test_elasticsearch_search()
    test_alert_count()
```

## 6. Common Pitfalls

1. **Index Management**: Without proper index management, Elasticsearch can grow too large over time
2. **Connection Handling**: Always handle Elasticsearch connection errors gracefully
3. **Bulk Operations**: Always use bulk operations for better performance
4. **Mapping Conflicts**: Be careful with dynamic mapping to avoid mapping explosions
5. **Data Consistency**: Ensure the data model in Elasticsearch matches your database model

## 7. Additional Considerations

1. **Index Lifecycle Management (ILM)**: For very high volumes, consider using Elasticsearch's ILM policies
2. **Cross-Cluster Search**: For extremely large volumes, set up multiple Elasticsearch clusters
3. **Document Compression**: Use compression techniques to reduce storage requirements
4. **Query Optimization**: Analyze slow queries and optimize them
5. **Alerting**: Set up Elasticsearch monitoring to alert on cluster health issues

## Helpful Resources

- [Elasticsearch Python Client Documentation](https://elasticsearch-py.readthedocs.io/)
- [Elasticsearch Index Templates](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-templates.html)
- [Elasticsearch Best Practices](https://www.elastic.co/guide/en/elasticsearch/reference/current/general-recommendations.html)
- [Elasticsearch Index Lifecycle Management](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html) 