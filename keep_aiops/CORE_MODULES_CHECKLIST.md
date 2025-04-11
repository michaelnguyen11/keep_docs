# Keep AIOps Core Modules Checklist

This checklist outlines the core Keep modules that need to be thoroughly understood and potentially modified to adapt the platform for high-volume IT Operations incident handling (processing ~600GB/day of logs, events, and alerts).

## 1. Alert Ingestion & Processing
- [x] Alert collector interfaces and API endpoints
  - [x] Webhook endpoints (`/alerts/event` and `/alerts/event/{provider_type}`)
  - [x] Provider-specific pull mechanisms (`_get_alerts()`)
  - [x] Background task configuration for async processing
- [x] Alert normalization and standardization mechanisms
  - [x] Provider-specific formatters (`_format_alert()`)
  - [x] Fingerprinting configuration (`FINGERPRINT_FIELDS`)
  - [x] Alert hash generation for deduplication
- [x] Alert filtering and pre-processing logic
  - [x] Alert deduplication strategies
  - [x] Maintenance window handling (`KEEP_MAINTENANCE_WINDOWS_ENABLED`)
  - [x] Enrichment rule application
- [x] Input validation and error handling
  - [x] AlertDto validation mechanisms
  - [x] Error alerting and tracking (`AlertErrorDto`)
  - [x] Retry policies (`TIMES_TO_RETRY_JOB`)
- [x] Scalability aspects for high-volume ingestion (~600GB/day)
  - [x] Redis + ARQ queue implementation (`REDIS=true`)
  - [x] Worker thread optimization (`KEEP_EVENT_WORKERS`)
  - [x] ThreadPoolExecutor configuration
- [x] Alert persistence and storage architecture
  - [x] Database tables (`Alert`, `AlertRaw`, `LastAlert`)
  - [x] Elasticsearch integration for historical data
  - [x] Storage optimization strategies

## 2. Alert Correlation Engine
- [x] Correlation rule definition framework
  - [x] Rule data model and schema (`Rule`)
  - [x] CEL (Common Expression Language) integration for conditions
  - [x] User interface for rule creation and management
- [x] Temporal correlation mechanisms (time-based grouping)
  - [x] Timeframe and timeunit configuration
  - [x] Time-based matching logic
- [x] Topology-based correlation (infrastructure relationships)
  - [x] Grouping criteria configuration
  - [x] Multi-level grouping for nested relationships
- [x] Similarity-based correlation algorithms
  - [x] Alert fingerprinting for rule matching
  - [x] Alert attribute mapping and comparison
- [x] Rule evaluation pipeline
  - [x] Rule extraction and preparation
  - [x] Expression evaluation with CEL
  - [x] Rule fingerprint calculation
  - [x] Incident candidate creation
- [x] Performance optimization for large alert volumes
  - [x] Efficient query mechanisms
  - [x] Expression preprocessing
  - [x] Optimization for CEL evaluation

See detailed documentation in [ALERT_CORRELATION_ENGINE.md](ALERT_CORRELATION_ENGINE.md) and diagrams in the `diagrams` directory.

## 3. Incident Management
- [x] Incident creation logic from correlated alerts
  - [x] Incident model initialization from alerts
  - [x] Candidate incident generation
  - [x] Multi-alert incident formation
- [x] Incident data model and schema
  - [x] Core incident attributes (`Incident` class)
  - [x] Incident status management
  - [x] Relationship with alerts
- [x] Incident state management and lifecycle
  - [x] Status transitions (firing → acknowledged → resolved)
  - [x] Audit logging for state changes
  - [x] Incident visibility control
- [x] Incident assignment and ownership tracking
  - [x] Assignee tracking
  - [x] Assignment notifications
  - [x] Self-assignment functionality
- [x] Incident prioritization mechanisms
  - [x] Severity calculation
  - [x] Service impact assessment
  - [x] Manual override capabilities
- [x] SLA monitoring and escalation workflows
  - [x] Integration with workflow engine
  - [x] Time-based escalation triggers
  - [x] Notification tier management

See detailed documentation in [INCIDENT_MANAGEMENT.md](INCIDENT_MANAGEMENT.md) and diagrams in the `diagrams` directory.

## 4. ML-Based Anomaly Detection
- [x] Machine learning model architecture
  - [x] External AI model integration (`ExternalAI`)
  - [x] Transformer-based correlation models
  - [x] OpenAI integration for intelligent suggestions
- [x] Training data requirements and preparation
  - [x] Historical alert-to-incident mapping
  - [x] Feature extraction from alert data
  - [x] Data validation and preprocessing
- [x] Feature extraction from alerts and incidents
  - [x] Alert content analysis
  - [x] Topology data utilization
  - [x] Temporal feature extraction
- [x] Model evaluation and performance metrics
  - [x] Accuracy threshold configuration
  - [x] Validation dataset (30% split)
  - [x] Confidence scoring
- [x] Integration with correlation engine
  - [x] AI-based incident suggestion
  - [x] User feedback collection
  - [x] Suggestion-to-incident conversion
- [x] Model retraining and updating mechanisms
  - [x] Feedback-based model improvement
  - [x] Tenant-specific model customization
  - [x] Continuous model evaluation

See detailed documentation in [ML_BASED_ANOMALY_DETECTION.md](ML_BASED_ANOMALY_DETECTION.md) and diagrams in the `diagrams` directory.

## 5. Workflow Automation
- [x] Workflow definition interface and schema
  - [x] YAML-based workflow definition format
  - [x] Support for steps, actions, triggers, and conditions
  - [x] Permission-based access control
- [x] Workflow execution engine
  - [x] ThreadPoolExecutor-based execution
  - [x] Support for scheduled, manual, and event-based triggers
  - [x] Context management for workflow execution
- [x] Integration with external systems
  - [x] Provider-based architecture for extensibility
  - [x] Support for various provider types (console, Slack, etc.)
  - [x] Secret management for provider credentials
- [x] Error handling and retry mechanisms
  - [x] Configurable workflow strategies (NONPARALLEL, NONPARALLEL_WITH_RETRY, PARALLEL)
  - [x] On-failure step execution
  - [x] Retry configuration for steps
- [x] Workflow templating capabilities
  - [x] Pre-built workflow templates
  - [x] Support for reusable workflow components
  - [x] Import/export functionality
- [x] Conditional execution paths
  - [x] Condition evaluation with multiple condition types
  - [x] Foreach loops for processing collections
  - [x] Continue flags for controlling execution flow

## 6. Integration Framework
- [x] Available API endpoints and authentication
  - [x] Webhook endpoints (`/alerts/event` and `/alerts/event/{provider_type}`)
  - [x] API key and basic authentication support
  - [x] OAuth integration for supported providers
- [x] Webhook integration capabilities
  - [x] Generic webhook support for any alert format
  - [x] Provider-specific webhook adapters
  - [x] Automatic webhook setup for compatible systems
- [x] Custom integration development approach
  - [x] Provider-based architecture
  - [x] Standardized interfaces (BaseProvider classes)
  - [x] Plugin system for extensibility
- [x] Data transformation mechanisms
  - [x] Provider-specific alert formatters
  - [x] Alert normalization and standardization
  - [x] Fingerprinting for deduplication
- [x] Rate limiting and throttling mechanisms
  - [x] Step-level throttling in workflows
  - [x] Provider-level rate limiting
  - [x] Configurable retry policies
- [x] Integration health monitoring
  - [x] Provider status checks
  - [x] Alert error logging
  - [x] Provider health reporting

## 7. Data Storage & Retention
- [x] Database schema and relationships
  - [x] Relational database models for active data (Alert, Incident, etc.)
  - [x] Association tables for many-to-many relationships
  - [x] LastAlert pattern for performance optimization
  - [x] Soft delete mechanisms for historical relationships
- [x] Indexing strategy for fast queries
  - [x] Composite indexes for common query patterns
  - [x] Filtered indexes for specific query scenarios
  - [x] Timestamp-based indexes for time range queries
  - [x] Tenant-based partitioning
- [x] Data retention policies and implementation
  - [x] Tiered storage approach (hot, warm, cold)
  - [x] Configurable retention periods
  - [x] Automatic cleanup processes
  - [x] Data archiving before deletion
- [x] Archiving mechanisms for historical data
  - [x] Elasticsearch integration for historical alerts
  - [x] Index lifecycle management
  - [x] Optional archiving to cold storage (S3)
  - [x] Tenant-specific archiving policies
- [x] Query optimization for reporting
  - [x] Specialized views for common report types
  - [x] Elasticsearch for complex historical queries
  - [x] Efficient pagination for large result sets
  - [x] Caching for frequently accessed data
- [x] Backup and recovery procedures
  - [x] Database point-in-time recovery
  - [x] Elasticsearch snapshot mechanism
  - [x] Incremental backup strategies
  - [x] Geographic replication options

## 8. User Interface
- [x] Alert and incident visualization
  - [x] Alerts table with server-side pagination and sorting
  - [x] Dynamic column generation based on alert data
  - [x] Virtualized rendering for large datasets
  - [x] Advanced CEL-based filtering capabilities
- [x] Dashboard and reporting capabilities
  - [x] Overview dashboard with key metrics
  - [x] Customizable widgets and layouts
  - [x] Performance optimized visualizations
  - [x] Time-range selection for historical data
- [x] User workflow and navigation patterns
  - [x] Feature-Slice Design architecture
  - [x] Contextual actions based on data state
  - [x] Optimistic UI updates for responsiveness
  - [x] Keyboard shortcuts for power users
- [x] Customization options
  - [x] User-configurable table columns
  - [x] Saved views and filters as presets
  - [x] Customizable time and list formats
  - [x] Theme customization with dark mode support
- [x] Performance with large datasets
  - [x] Server-side rendering for initial page load
  - [x] Incremental loading for paged data
  - [x] SWR caching for efficient data reuse
  - [x] Live updates with selective re-rendering

## 9. System Administration
- [x] Configuration management
  - [x] Environment variable and file-based configuration
  - [x] Tenant-specific configuration with reload mechanism
  - [x] Settings API for programmatic configuration
  - [x] Secure storage for sensitive configuration
- [x] User and role management
  - [x] Role-based access control with scope system
  - [x] Predefined roles (Admin, NOC, Webhook, WorkflowRunner)
  - [x] Identity provider integration (Auth0, Keycloak)
  - [x] API key management for service authentication
- [x] System health monitoring
  - [x] Health check endpoints for component status
  - [x] Performance metrics for key operations
  - [x] Worker process monitoring
  - [x] System status dashboard
- [x] Performance tuning parameters
  - [x] Database connection pooling and optimization
  - [x] Worker process configuration
  - [x] Queue management settings
  - [x] Caching parameters
- [x] Logging and auditing
  - [x] Centralized logging with JSON formatting
  - [x] Specialized loggers for workflows and providers
  - [x] Log level configuration
  - [x] Comprehensive audit trail
- [x] Scaling options for high-volume environments
  - [x] Kubernetes deployment with HPA
  - [x] Microservice architecture for independent scaling
  - [x] Tiered storage for efficient data management
  - [x] Vertical scaling recommendations

## 10. Knowledge Management
- [x] Knowledge base structure and organization
  - [x] Alert-incident correlation history
  - [x] Resolution workflow repository
  - [x] Semantic vector embeddings for similarity search
  - [x] Contextual enrichment data
- [x] Integration with incident resolution
  - [x] Similar incident suggestion with confidence scoring
  - [x] Historical resolution recommendations
  - [x] Knowledge-enriched automation workflows
  - [x] One-click application of known solutions
- [x] Search and retrieval mechanisms
  - [x] Semantic similarity search with vector embeddings
  - [x] Contextual understanding of alert descriptions
  - [x] Multi-dimensional clustering of incident types
  - [x] Time-based pattern recognition
- [x] Knowledge capture from resolved incidents
  - [x] Automated extraction from resolution workflows
  - [x] LLM-based summarization of incident handling
  - [x] Key action and decision point identification
  - [x] Active learning from user feedback
- [x] LLM-powered suggestion engine
  - [x] External AI framework for LLM integration
  - [x] Transformer-based correlation models
  - [x] On-premises and cloud LLM provider support
  - [x] Air-gap compatibility for secure environments

## 11. Performance Considerations
- [ ] Bottlenecks in the data pipeline
- [ ] Caching strategies
- [ ] Horizontal and vertical scaling options
- [ ] Resource requirements for your scale
- [ ] Performance monitoring and alerting

## Recommended Approach

1. Start with modules 1-3 (Alert Ingestion, Correlation, and Incident Management) as they form the core foundation
2. Then focus on the Integration Framework (module 6) to connect with your existing monitoring tools
3. Next, examine Data Storage & Retention (module 7) to ensure it can handle your 600GB/day volume
4. Finally, explore the more advanced features like ML-Based Anomaly Detection and Knowledge Management

As you work through this checklist, update the diagrams in the `keep_aiops/diagrams` directory to reflect your understanding and any modifications you plan to make. 