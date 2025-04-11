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

## 5. Workflow Automation
- [ ] Workflow definition interface and schema
- [ ] Workflow execution engine
- [ ] Integration with external systems
- [ ] Error handling and retry mechanisms
- [ ] Workflow templating capabilities
- [ ] Conditional execution paths

## 6. Integration Framework
- [ ] Available API endpoints and authentication
- [ ] Webhook integration capabilities
- [ ] Custom integration development approach
- [ ] Data transformation mechanisms
- [ ] Rate limiting and throttling mechanisms
- [ ] Integration health monitoring

## 7. Data Storage & Retention
- [ ] Database schema and relationships
- [ ] Indexing strategy for fast queries
- [ ] Data retention policies and implementation
- [ ] Archiving mechanisms for historical data
- [ ] Query optimization for reporting
- [ ] Backup and recovery procedures

## 8. User Interface
- [ ] Alert and incident visualization
- [ ] Dashboard and reporting capabilities
- [ ] User workflow and navigation patterns
- [ ] Customization options
- [ ] Performance with large datasets

## 9. System Administration
- [ ] Configuration management
- [ ] User and role management
- [ ] System health monitoring
- [ ] Performance tuning parameters
- [ ] Logging and auditing
- [ ] Scaling options for high-volume environments

## 10. Knowledge Management
- [ ] Knowledge base structure and organization
- [ ] Integration with incident resolution
- [ ] Search and retrieval mechanisms
- [ ] Knowledge capture from resolved incidents
- [ ] Suggestion engine for similar incidents

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