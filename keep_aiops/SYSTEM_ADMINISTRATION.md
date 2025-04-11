# Keep AIOps System Administration

## Overview

The System Administration module in Keep AIOps provides the tools and interfaces necessary to manage, configure, monitor, and scale the platform to handle high-volume environments (up to 600GB/day of events, logs, and alerts). This module is essential for IT operations teams to maintain the health, security, and performance of the system.

## Configuration Management

### Core Configuration

Keep AIOps uses a layered configuration approach:

1. **Environment Variables**: Primary method for configuring system behavior
   - `KEEP_API_URL`: Base URL for the API service
   - `KEEP_STORE_WORKFLOW_LOGS`: Controls workflow log persistence (default: "true")
   - `TENANT_CONFIGURATION_RELOAD_TIME`: Interval for reloading tenant config (default: 5 minutes)
   - `PROVISION_RESOURCES`: Controls automatic resource provisioning on startup (default: "true")

2. **Configuration Files**: Loaded at startup for persistent settings
   - `.env` file in the root directory (for development)
   - Configuration stored in environment for production deployments

3. **Tenant-Specific Configuration**: Per-tenant settings stored in the database
   - Accessed via `TenantConfiguration` singleton class
   - Automatically reloaded at configurable intervals

### Settings API

The `/settings` API endpoints provide programmatic access to common configuration tasks:

1. **Email Configuration (SMTP)**
   - `GET /settings/smtp`: Retrieve SMTP settings
   - `POST /settings/smtp`: Configure SMTP server
   - `DELETE /settings/smtp`: Remove SMTP settings
   - `POST /settings/smtp/test`: Test email delivery

2. **API Key Management**
   - `POST /settings/apikey`: Create new API key
   - `GET /settings/apikeys`: List all API keys
   - `PUT /settings/apikey`: Update API key
   - `DELETE /settings/apikey/{keyId}`: Remove an API key

3. **SSO and Authentication Settings**
   - `GET /settings/sso`: Retrieve SSO configuration
   - `GET /settings/tenant/configuration`: Get tenant configuration

4. **Webhook Configuration**
   - `GET /settings/webhook`: Get webhook endpoints and API key

## User and Role Management

### Role-Based Access Control (RBAC)

Keep implements a scope-based RBAC system with predefined roles:

1. **Admin Role**
   - Full system access with all permissions
   - Scopes: `read:*`, `write:*`, `delete:*`, `update:*`, `execute:*`

2. **NOC Role**
   - Read-only access to most resources with workflow execution rights
   - Scopes: `read:*`, `execute:workflows`

3. **Webhook Role**
   - Limited to alert and incident creation
   - Scopes: `write:alert`, `write:incident`

4. **Workflow Runner Role**
   - Focused on workflow management and execution
   - Scopes: `write:workflows`, `execute:workflows`

### User Management

User management is handled through:

1. **Identity Provider Integration**
   - Support for external identity providers (Auth0, Keycloak)
   - OIDC/OAuth2 implementation for SSO

2. **Local User Management**
   - Direct user creation for standalone deployments
   - User-role assignment API

3. **API Authentication**
   - API key generation and management
   - Token-based authentication for services
   - Role-specific API keys for integrations

## System Health Monitoring

### Health Checks

1. **API Health Endpoints**
   - `/healthcheck`: Basic API availability check
   - Access via: `GET /healthcheck`

2. **Component Status Monitoring**
   - Database connectivity checks
   - External dependency status
   - Worker process health

3. **Key Performance Metrics**
   - Alert ingestion rate
   - Correlation engine performance
   - Workflow execution throughput
   - API response times

### System Information

System-wide information is stored in the `System` table with a simple schema:
```
id: str (primary_key)
name: str
value: str
```

This table stores global configuration values and system metrics for quick access.

## Performance Tuning

### Database Optimization

1. **Connection Pooling**
   - Configured through database configuration
   - Pool size adjusted based on workload

2. **Query Optimization**
   - Indexing strategy based on common access patterns
   - Tenant-based partitioning for multi-tenant deployments

3. **Transaction Management**
   - Proper transaction isolation for concurrent operations
   - Optimistic locking for high-concurrency scenarios

### Worker Process Configuration

1. **Alert Worker Scaling**
   - `KEEP_EVENT_WORKERS`: Number of worker processes for alert processing
   - Adjustable based on CPU cores and expected load

2. **Workflow Execution Engine**
   - `ThreadPoolExecutor` configuration for parallel workflow steps
   - Adjustable thread pool size based on workflow complexity

3. **Queue Management**
   - Redis + ARQ queue implementation for distributed processing
   - Configurable job retry policies (`TIMES_TO_RETRY_JOB`)

## Logging and Auditing

### Logging Architecture

1. **Centralized Logging**
   - JSON-formatted logs for machine processing
   - Configurable log levels through environment variables or command line

2. **Special-Purpose Loggers**
   - `WorkflowDBHandler`: Stores workflow execution logs in the database
   - `ProviderDBHandler`: Captures provider integration logs
   - `WorkflowContextFilter`: Contextualizes logs with workflow information

3. **Log Collection**
   - Automatic log forwarding to database
   - Configurable buffer size and flush intervals
   - Support for external log aggregation systems

### Audit Trail

All significant system actions are logged with context information:

1. **User Action Tracking**
   - Authentication events
   - Configuration changes
   - Role assignments

2. **Alert and Incident Lifecycle**
   - State transitions
   - Ownership changes
   - Comment history

3. **Workflow Execution**
   - Step-by-step execution logs
   - Input/output recording
   - Failure analysis data

## Scaling Options for High-Volume Environments

### Horizontal Scaling

1. **Kubernetes Deployment**
   - Helm chart for automated deployment
   - Horizontal Pod Autoscalers (HPA) for dynamic scaling
   - Component-specific scaling configurations:
     - Frontend
     - Backend API
     - WebSocket server

2. **Microservice Architecture**
   - Frontend/backend separation
   - Independent scaling of components
   - Stateless design for easy replication

### Vertical Scaling

1. **Resource Allocation**
   - Memory tuning based on dataset size
   - CPU allocation based on correlation complexity
   - Disk I/O optimization for high-volume storage

2. **Database Scaling**
   - Support for external database services
   - Read replica configuration
   - Connection pooling optimization

### Data Volume Management

1. **Tiered Storage**
   - Hot storage for active data (SQL)
   - Warm storage for recent history (Elasticsearch)
   - Cold storage for archival (optional S3 integration)

2. **Retention Policies**
   - Configurable retention periods
   - Automatic data archiving or pruning
   - Tenant-specific retention settings

## Deployment Models

### On-Premises Deployment

1. **Hardware Requirements**
   - Minimum specifications for different scales:
     - Small (< 50GB/day): 4 CPU cores, 16GB RAM
     - Medium (50-200GB/day): 8 CPU cores, 32GB RAM
     - Large (200-600GB/day): 16+ CPU cores, 64GB+ RAM
   - Storage requirements based on retention policy

2. **Network Configuration**
   - Ingress controller setup
   - Load balancer configuration
   - Firewall recommendations

### Cloud Deployment

1. **Kubernetes on Cloud**
   - Support for major cloud providers (AWS, GCP, Azure)
   - Infrastructure as Code templates
   - Autoscaling group configuration

2. **Cloud-Native Services Integration**
   - Managed database services
   - Object storage for archival
   - Identity provider integration

## Implementation Recommendations

For deploying Keep AIOps in high-volume environments (600GB/day):

1. **Start with Capacity Planning**
   - Estimate alert volume and growth rate
   - Calculate correlation complexity
   - Determine retention requirements

2. **Begin with Conservative Scaling**
   - Start with sufficient capacity plus 30% headroom
   - Monitor actual usage patterns
   - Gradually optimize based on observed workloads

3. **Implement Tiered Storage Early**
   - Configure hot/warm/cold storage separation
   - Set up appropriate data lifecycle policies
   - Monitor storage growth rate

4. **Set Up Comprehensive Monitoring**
   - Alert on system performance issues
   - Track key metrics (ingestion rate, correlation time, etc.)
   - Establish baseline performance metrics

5. **Regular Performance Tuning**
   - Schedule quarterly review of system performance
   - Adjust scaling parameters based on growth
   - Optimize database queries and indexes 