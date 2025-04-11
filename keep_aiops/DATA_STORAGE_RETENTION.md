# Keep AIOps Data Storage & Retention

## Overview

The Data Storage & Retention module in Keep AIOps is designed to handle high volumes of alert and incident data (up to 600GB/day) while maintaining system performance and managing data lifecycle efficiently. This module uses a hybrid storage approach that combines:

1. Relational database (SQL) for active data and operational workflows
2. Elasticsearch for historical data, advanced search, and analytics
3. Caching mechanisms for performance optimization

## Database Architecture

### Core Database Structure

Keep uses SQLModel (built on SQLAlchemy) with support for multiple database backends:

- PostgreSQL (recommended for production)
- MySQL/MariaDB
- SQLite (development/testing only)

The connection is configured through environment variables:
```
DATABASE_CONNECTION_STRING=postgresql://user:password@localhost:5432/keep
```

### Database Schema Design

#### Alert Storage Models

1. **Alert**: Main alert storage table
   - `id`: UUID primary key
   - `tenant_id`: Multi-tenancy support
   - `timestamp`: When the alert was received
   - `provider_type`, `provider_id`: Source system identifier
   - `event`: JSON field containing the full alert data
   - `fingerprint`: Alert identifier for deduplication
   - `alert_hash`: Hash for content-based deduplication

2. **LastAlert**: Most recent alert for each fingerprint
   - `tenant_id`, `fingerprint`: Composite primary key
   - `alert_id`: Reference to the full Alert
   - `timestamp`: Last occurrence time
   - `first_timestamp`: First occurrence time
   - `alert_hash`: For deduplication

3. **AlertRaw**: Raw incoming alerts before processing
   - Used for error tracking and audit
   - Stores failures that couldn't be processed

4. **AlertEnrichment**: Additional context for alerts
   - `alert_fingerprint`: Links to alerts
   - `enrichments`: JSON field with enrichments
   - One-to-many relationship with Alerts

#### Incident Storage Models

1. **Incident**: Correlated group of alerts
   - `id`: UUID primary key
   - `tenant_id`: Multi-tenancy support
   - `running_number`: Auto-incrementing ID per tenant
   - Various metadata fields (name, summary, severity, etc.)
   - `status`: FIRING, RESOLVED, ACKNOWLEDGED, etc.
   - `rule_id`: Correlation rule that created the incident
   - `start_time`, `end_time`: Incident timeframe

2. **AlertToIncident**: Many-to-many relationship
   - Links alerts to incidents
   - Supports soft deletion for relationship history

3. **LastAlertToIncident**: Optimized relationship tracking
   - Links most recent alert instances to incidents
   - Improves query performance for active incidents

### Indexing Strategy

The database schema includes carefully designed indexes to optimize the most common query patterns:

1. **Composite indexes** for multi-column queries:
   ```python
   # Example from Alert model
   __table_args__ = (
       Index(
           "ix_alert_tenant_fingerprint_timestamp",
           "tenant_id", 
           "fingerprint",
           "timestamp",
       ),
       # More indexes...
   )
   ```

2. **Filtered indexes** for specific queries:
   ```python
   # Example from Incident model
   __table_args__ = (
       Index(
           "ix_incident_tenant_running_number",
           "tenant_id",
           "running_number",
           unique=True,
           postgresql_where=text("running_number IS NOT NULL"),
           sqlite_where=text("running_number IS NOT NULL"),
       ),
   )
   ```

3. **Optimized timestamp indexes** for time-range queries:
   - Critical for efficient historical data access
   - Support for time-based filtering and pagination

## Elasticsearch Integration

For high-volume environments, Keep integrates with Elasticsearch to handle historical alerts and provide advanced search capabilities.

### Elasticsearch Configuration

The Elasticsearch integration is configured through environment variables:
```
ELASTIC_ENABLED=true
ELASTIC_HOSTS=http://elasticsearch:9200
ELASTIC_USER=elastic
ELASTIC_PASSWORD=changeme
ELASTIC_VERIFY_CERTS=true
ELASTIC_INDEX_SUFFIX=tenant1  # For single-tenant mode
```

### Index Structure

- Keep uses tenant-specific indices (`keep-alerts-{tenant_id}`)
- Each alert is indexed with its complete data and metadata
- The mapping includes text fields with keyword sub-fields for both full-text and exact match searching

### Querying Mechanism

The `ElasticClient` class provides several query mechanisms:

1. **SQL queries** for simple searches:
   ```python
   def run_query(self, query: str, limit: int = 1000):
       # Uses Elasticsearch SQL capabilities
   ```

2. **DSL queries** for complex searches:
   ```python
   def search_alerts(self, query: str, limit: int) -> list[AlertDto]:
       # Translates SQL to DSL for better performance with array fields
   ```

3. **Bulk indexing** for efficient data ingestion:
   ```python
   def index_alerts(self, alerts: list[AlertDto]):
       # Indexes batches of alerts
   ```

## Data Retention Policies

Keep implements a multi-tiered data retention strategy:

### 1. Hot Data (Relational Database)

- Stores recent and active alerts (typically 7-30 days)
- Fully normalized for transactional workloads
- Optimized for low-latency access

### 2. Warm Data (Elasticsearch)

- Stores historical alerts (typically 30-90 days)
- Indexed for search and analytics
- Optimized for query performance

### 3. Cold Data (Archive)

- Archived data beyond the retention period
- Optional S3/cloud storage integration
- Available for compliance and audit purposes

### Retention Configuration

Retention periods can be configured through environment variables:
```
# Database retention (days)
KEEP_DB_RETENTION_DAYS=30

# Elasticsearch retention
ELASTIC_RETENTION_DAYS=90

# Archive retention (optional)
KEEP_ARCHIVE_RETENTION_DAYS=365
```

## Data Partitioning

For high-volume environments, Keep implements several partitioning strategies:

### Time-Based Partitioning

- Elasticsearch indices use time-based naming (`keep-alerts-{tenant_id}-{YYYY.MM.DD}`)
- Enables efficient rollover and deletion of old data
- Optimizes query performance for time-range searches

### Tenant-Based Partitioning

- All data is partitioned by tenant_id
- Ensures isolation between tenants
- Allows for tenant-specific retention policies

## Optimization Techniques

### Database Optimizations

1. **Connection Pooling**:
   ```python
   # Session management with proper disposal
   def dispose_session():
       if engine.dialect.name != "sqlite":
           engine.dispose(close=False)
   ```

2. **Retry Mechanisms** for transient failures:
   ```python
   @retry(exceptions=(OperationalError,), tries=3, delay=0.1, backoff=2)
   def wrapper(*args, **kwargs):
       # Handles deadlocks and retries
   ```

3. **Efficient Queries**:
   - Use of SQLAlchemy's optimized query building
   - Selective loading with joinedload/subqueryload
   - Pagination to limit result sets

### Elasticsearch Optimizations

1. **Mapping Optimization**:
   - Field type selection based on query patterns
   - Keyword fields for filtering, text fields for search
   - Strategic use of nested fields

2. **Bulk Operations**:
   - Batched indexing for better throughput
   - Optimized bulk APIs for mass operations

3. **Index Lifecycle Management**:
   - Automated index rotation
   - Shard and replica configuration
   - Warm/cold node transitions

## High-Volume Considerations (600GB/day)

For environments processing 600GB/day:

1. **Hardware Requirements**:
   - Database: High-memory instances with fast SSD storage
   - Elasticsearch: Distributed cluster with dedicated master nodes

2. **Scaling Strategies**:
   - Horizontal scaling for Elasticsearch (add nodes)
   - Vertical scaling for the database (larger instances)
   - Read replicas for reporting workloads

3. **Performance Monitoring**:
   - Database query performance tracking
   - Elasticsearch index and query metrics
   - Regular optimization of slow queries

4. **Backup and Recovery**:
   - Database: Point-in-time recovery
   - Elasticsearch: Snapshot and restore
   - Geographic replication for disaster recovery

## Implementation Recommendations

For implementing the Data Storage & Retention module at 600GB/day scale:

1. **Start with Database Optimization**:
   - Review and optimize existing indexes
   - Implement partitioning for large tables
   - Configure connection pooling appropriately

2. **Add Elasticsearch for Historical Data**:
   - Set up a multi-node Elasticsearch cluster
   - Implement the indexing pipeline
   - Configure index templates and lifecycle policies

3. **Develop Retention Policies**:
   - Implement cleanup jobs for database retention
   - Configure Elasticsearch ILM policies
   - Set up archiving for long-term storage

4. **Monitor and Tune**:
   - Establish performance baselines
   - Monitor query performance
   - Continuously optimize based on actual workloads 