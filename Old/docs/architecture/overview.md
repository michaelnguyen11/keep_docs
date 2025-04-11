# Keep AIOps Platform Overview

## Introduction

Keep is an open-source AIOps and alert management platform designed to streamline incident management by providing a single pane of glass for alerts from various monitoring tools. The platform offers capabilities such as alert deduplication, enrichment, correlation, bi-directional integrations, automated workflows, and AI-powered features.

## Core Features

1. **Unified Alert Management**
   - Centralized view of alerts from multiple monitoring systems
   - Alert deduplication based on configurable fingerprinting
   - Alert enrichment with additional context from multiple sources
   - Customizable views with saved presets and faceted search
   
2. **Incident Management**
   - Automated incident creation from correlated alerts
   - Rule-based and AI-powered correlation
   - Incident prioritization, assignment, and lifecycle management
   - Dynamic incident naming using alert attributes
   
3. **Integration Ecosystem**
   - 100+ integrations across multiple categories
   - Standardized provider interface for all integrations
   - Categories include Observability, AI, Communication, and Ticketing
   - Bi-directional sync with external systems
   
4. **Workflow Automation**
   - GitHub Actions-like workflows for automated responses
   - Event-based, scheduled, and manual triggers
   - Conditional execution with CEL expressions
   - Context passing between workflow steps
   
5. **AI-Powered Features**
   - AI correlation for intelligent alert grouping
   - AI Incident Assistant for interactive incident investigation
   - AI Workflow Assistant for workflow guidance
   - Integrations with multiple LLM providers (OpenAI, Anthropic, Gemini, etc.)

## Architecture Overview

Keep follows a modular architecture with clear boundaries between components:

### High-Level Components

1. **Keep API (Backend)**
   - Python-based FastAPI server
   - Business logic and API endpoints
   - Alert processing and incident management
   - Workflow engine

2. **Keep UI (Frontend)**
   - Next.js React application
   - Feature-Slice Design architecture
   - Tailwind CSS for styling
   - SWR for data fetching

3. **WebSocket Server**
   - Soketi server for real-time updates
   - Enables push notifications without page refreshes

4. **Database**
   - Supports PostgreSQL, MySQL, SQLite, and SQL Server
   - SQLModel ORM for data access

### Backend Components

1. **API Layer (FastAPI)**
   - REST API endpoints for all operations
   - Authentication and authorization
   - Request validation and error handling
   - OpenTelemetry instrumentation

2. **Business Logic Layer**
   - Alert processing and deduplication
   - Incident management and correlation
   - Rule evaluation and execution
   - Workflow management

3. **Provider System**
   - Unified interface for integrations
   - Provider-specific implementations
   - Authentication and connection management
   - Method execution for external operations

4. **Rules Engine**
   - Common Expression Language (CEL) for rule definitions
   - Alert evaluation and matching
   - Incident creation based on rule conditions
   - Fingerprint generation for correlation

5. **Workflow Engine**
   - Workflow definition and storage
   - Scheduling and execution
   - Step and action processing
   - Context management for state sharing

### Frontend Components

1. **React Application (Next.js)**
   - Feature-Slice Design architecture
   - Server-Side Rendering for performance
   - Responsive and accessible UI
   - Route-based code splitting

2. **State Management**
   - SWR for data fetching and caching
   - Context API for shared state
   - Zustand for complex state management
   - Real-time updates via WebSockets

3. **Component Library**
   - Tailwind CSS for styling
   - Reusable UI component system
   - Visualization components for metrics and graphs
   - Headless UI components for accessibility

## Data Model

The core entities in the Keep platform include:

1. **Alert**
   - Represents a notification from a monitoring system
   - Contains metadata, timestamp, severity, and payload
   - Linked to provider and fingerprinted for deduplication
   - Can be enriched with additional context

2. **Incident**
   - Represents a group of related alerts
   - Has lifecycle (firing, acknowledged, resolved)
   - Contains metadata like severity, assignee, summary
   - Can be manually created or generated automatically

3. **Rule**
   - Defines conditions for alert correlation and incident creation
   - Consists of CEL expressions and grouping criteria
   - Configurable creation and resolution settings
   - Supports dynamic incident naming

4. **Workflow**
   - Defines automated processes for incident response
   - Contains steps, actions, triggers, and schedule
   - Integrates with providers for external actions
   - Supports conditional logic and context passing

5. **Provider**
   - Represents integration with external systems
   - Contains connection details and authentication
   - Implements specific capabilities based on provider type
   - Categorized by functionality (Observability, AI, etc.)

6. **Tenant**
   - Supports multi-tenancy with isolated data
   - Contains configuration settings and preferences
   - Enables enterprise deployments with organization segregation

## Key Subsystems

### Provider System

The provider system enables integration with external services through a uniform interface:

```
BaseProvider
├── Authentication Layer
├── Configuration Management
├── Method Execution
└── Scopes Validation
```

Providers are organized into categories:
- **Observability**: Datadog, Prometheus, CloudWatch, etc.
- **AI Providers**: OpenAI, Anthropic, DeepSeek, Gemini, etc.
- **Communication**: Slack, Discord, Email, etc.
- **Ticketing**: Jira, ServiceNow, Linear, etc.

### Workflow Engine

The workflow engine manages the execution of automated processes:

```
WorkflowManager
├── Scheduler (time-based triggers)
├── Executor (runs workflow steps)
├── Context Manager (maintains state)
└── Provider Integration (executes actions)
```

Workflows consist of:
- **Triggers**: Events that start the workflow (alert, incident, schedule, manual)
- **Steps**: Information gathering operations
- **Actions**: Operations that change state or communicate
- **Conditions**: Logic for conditional execution
- **Context**: State shared between steps and actions

### Rules Engine

The rules engine correlates alerts into incidents using defined criteria:

```
RulesEngine
├── CEL Expression Evaluation
├── Fingerprint Generation
├── Incident Creation/Update
└── Resolution Logic
```

Rules can:
- Group alerts based on common attributes
- Create incidents based on alert patterns
- Dynamically name incidents using templates
- Specify resolution conditions

### AI Capabilities

The AI integration enables intelligent operations:

```
AI Integration
├── AI Correlation Engine (alert grouping)
├── AI Incident Assistant (chat interface)
├── AI Workflow Assistant (workflow guidance)
├── AI in Workflows (workflow steps)
└── Semi-Automatic Correlation (human approval)
```

## Technology Stack

### Backend
- **Python**: Core programming language
- **FastAPI**: Web framework for APIs
- **SQLModel/SQLAlchemy**: ORM for database operations
- **CEL**: Common Expression Language for rules
- **ARQ**: Asynchronous task queue

### Frontend
- **TypeScript**: Programming language
- **React**: UI library
- **Next.js**: React framework
- **SWR**: Data fetching library
- **Tailwind CSS**: Utility-first CSS framework

### Infrastructure
- **Docker**: Containerization
- **Kubernetes**: Orchestration (for production deployments)
- **Keycloak**: Identity and access management (optional)
- **Soketi**: WebSocket server for real-time updates
- **OpenTelemetry**: Observability instrumentation

## Deployment Options

The Keep platform supports multiple deployment options:

1. **Docker Compose**
   - Single-node deployment for development and testing
   - Includes all required components
   - Quick setup for evaluation

2. **Kubernetes**
   - Production-grade deployment with high availability
   - Horizontal scaling for components
   - Secret management using Kubernetes
   - Configurable via Helm charts

3. **SaaS Platform**
   - Managed service available at platform.keephq.dev
   - Free tier for evaluation
   - Enterprise plans with additional features

## Customization and Extension

The Keep platform is designed to be highly customizable and extensible:

1. **Provider System**
   - Create custom providers for new integrations
   - Extend existing providers with new capabilities
   - Implement domain-specific provider methods

2. **Workflow System**
   - Create custom workflow steps and actions
   - Define reusable workflow templates
   - Implement organization-specific automation

3. **UI Customization**
   - Create custom dashboards and views
   - Implement organization-specific widgets
   - Define saved presets for common queries

4. **Data Model Extension**
   - Enrich alerts with custom attributes
   - Define custom correlation rules
   - Implement organization-specific classification

## Security Architecture

1. **Authentication**
   - Multiple authentication options (DB, OAuth2, Keycloak, Auth0)
   - Role-based access control
   - API key authentication

2. **Secrets Management**
   - Multiple backend options (File, GCP, K8S, Vault)
   - Encryption for sensitive data
   - Secure provider credential storage

3. **Multi-tenancy**
   - Strict isolation between tenants
   - Tenant-specific configuration
   - Role-based permissions within tenants

## Future Directions and Agentic AI Integration

The Keep platform is well-positioned for enhancement with Agentic AI capabilities:

1. **Enhanced Provider System**
   - Extend the BaseProvider class to create an AgentProvider type
   - Implement specialized agent providers for different roles
   - Enable tool-based interaction for agents

2. **Agent Memory and Context**
   - Extend the ContextManager to include persistent agent memory
   - Implement knowledge storage for long-term learning
   - Enable context sharing between agents

3. **Multi-Agent Orchestration**
   - Implement an orchestration layer for coordinating multiple agents
   - Define communication protocols between agents
   - Enable specialized roles for different incident aspects

4. **Autonomous Incident Response**
   - Automated investigation of incidents
   - Intelligent remediation suggestion
   - Guided resolution with human oversight

## Conclusion

The Keep AIOps platform represents a modern approach to incident management, combining alert aggregation, intelligent correlation, and automated response in a single, extensible platform. Its modular architecture and comprehensive integration capabilities make it adaptable to a wide range of environments and use cases, from small teams to enterprise-scale operations. The platform's existing AI capabilities provide a solid foundation for further enhancement with Agentic AI features, enabling increasingly autonomous operation while maintaining human oversight. 