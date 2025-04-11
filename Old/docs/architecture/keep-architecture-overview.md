# Keep AIOps Platform Architecture Overview

This document provides an overview of the Keep AIOps Platform architecture based on our code analysis and understanding of the platform's current capabilities.

## System Overview

Keep AIOps is an open-source platform for AIOps and alert management that provides:

- **Single pane of glass** for alerts and incidents
- **Alert processing** including deduplication, correlation, filtering, and enrichment
- **Bi-directional integrations** with monitoring tools and collaboration systems
- **Workflow automation** to streamline incident response
- **AI-powered operations** for correlation and summarization

The platform leverages AI technologies to enhance alert processing, incident management, and operational insights.

## Architecture Layers

The Keep AIOps Platform architecture consists of several key layers:

### 1. Frontend Layer (Keep UI)

- Built with TypeScript, Next.js, React, and Tailwind CSS
- Follows Feature-Slice Design pattern with entities, features, widgets, and shared components
- Provides interfaces for alert monitoring, incident management, workflow configuration, and system settings
- Connects to backend via REST API and WebSockets for real-time updates

### 2. Backend API Layer

- Implemented in Python using FastAPI
- Provides RESTful endpoints for all platform operations
- Handles business logic, data operations, and integration management
- Manages authentication and authorization

### 3. Core Processing Layer

- **Alert Deduplicator** - Reduces alert noise through intelligent deduplication
- **Rules Engine** - Evaluates conditions using CEL (Common Expression Language)
- **Workflow Manager** - Handles workflow execution with steps and actions
- **AI Manager** - Orchestrates AI operations across the platform
- **Provider Integrations** - Manages connections to external systems

### 4. Data Storage and Processing Layer

- **Database** - Stores alerts, incidents, workflows, and configuration data
- **Search Engine** - Enables advanced search capabilities (using Elasticsearch)
- **Background Tasks** - Handles asynchronous processing using ARQ/Redis
- **WebSocket Server** - Provides real-time updates to clients
- **Secrets Manager** - Securely manages provider credentials

## Key Components

### Alert Management

The alert management system handles:

- Alert ingestion from multiple monitoring systems
- Deduplication using configurable rules and fingerprinting
- Enrichment with additional context and metadata
- Correlation to identify related alerts
- Status tracking (firing, resolved, acknowledged, suppressed)
- Severity classification (critical, high, warning, info, low)

### Incident Management

The incident management system provides:

- Grouping of related alerts into incidents
- Incident lifecycle management
- Status tracking and severity assessment
- AI-assisted summarization and context gathering
- Integration with ticketing systems

### Workflow Automation

The workflow system enables:

- Definition of multi-step workflows
- Scheduled and event-triggered execution
- Integration with external systems via providers
- Context preservation across workflow steps
- Error handling and retries
- Parallel and sequential execution strategies

### Provider Integration System

The provider integration system:

- Manages connections to external tools and services
- Provides a common interface for different provider types
- Handles authentication and credential management
- Supports bidirectional data flow

### AI Capabilities

Current AI integration includes:

- Alert correlation using similarity detection
- Incident summarization
- Root cause analysis assistance
- Context enrichment from various sources

## Data Flow

1. **Alert Ingestion:**
   - Alerts are received from monitoring tools via webhooks or pulled via API
   - Alerts are normalized, deduplicated, and enriched
   - Related alerts are correlated using rules and AI

2. **Incident Creation:**
   - Correlated alerts are grouped into incidents
   - Incidents are enriched with additional context
   - Notifications are sent to configured channels

3. **Workflow Execution:**
   - Workflows can be triggered by alerts, incidents, or schedules
   - Workflow steps are executed with appropriate context
   - Actions are performed via provider integrations

4. **User Interaction:**
   - Users view and manage alerts and incidents via the UI
   - Users configure workflows, rules, and integrations
   - Users receive real-time updates via WebSockets

## Integration Points

Keep integrates with various external systems:

### Observability Systems
- Metrics systems (Prometheus, Datadog, CloudWatch, etc.)
- Log systems (Elastic, Grafana Loki, Graylog, etc.)
- Tracing systems (Jaeger, Zipkin, OpenTelemetry, etc.)
- Synthetic monitoring (Checkly, etc.)
- Infrastructure monitoring (LibreNMS, NetData, AppDynamics, etc.)

### Collaboration Systems
- Ticketing systems (Jira, ServiceNow, Linear, GitHub Issues, etc.)
- Chat systems (Slack, Teams, Discord, etc.)
- Notification channels (Email, SMS, PagerDuty, OpsGenie, etc.)
- Documentation systems (Notion, Confluence, etc.)

### AI Services
- LLM providers (OpenAI, Anthropic, DeepSeek, Gemini, etc.)
- Embedding providers (OpenAI Embeddings, etc.)
- Self-hosted LLMs (Ollama, LlamaCPP, etc.)

## Deployment Architecture

Keep AIOps can be deployed in various configurations:

- Containerized deployment with Docker/Docker Compose
- Kubernetes deployment
- Cloud-based deployment (AWS, GCP, Azure)
- On-premises deployment

The platform uses a microservices architecture with the following main services:

- Keep UI service
- Keep API service
- Database service (PostgreSQL/MySQL/SQLite)
- Redis service for caching and background tasks
- Elasticsearch service for search capabilities
- WebSocket service for real-time updates

## Future Integration Points for Agentic AI

Based on the current architecture, several potential integration points for Agentic AI capabilities have been identified:

1. **Enhanced Workflow System** - Augmenting the existing workflow system with agentic capabilities
2. **Advanced Incident Analysis** - Using agents for deep incident analysis beyond basic correlation
3. **Autonomous Remediation** - Enabling agents to propose and execute remediation steps
4. **Contextual Knowledge Integration** - Using agents to gather and integrate contextual knowledge
5. **Predictive Alert Management** - Leveraging agents for proactive alert prediction and prevention 