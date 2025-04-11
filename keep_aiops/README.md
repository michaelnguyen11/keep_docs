# Keep AIOps Platform Documentation

This directory contains comprehensive documentation and diagrams of the Keep AIOps Platform architecture in its current state, before the integration of Agentic AI capabilities.

## Core Modules Checklist

We've created a [Core Modules Checklist](CORE_MODULES_CHECKLIST.md) to track our understanding and adaptation of Keep AIOps for high-volume IT Operations incident handling. Use this checklist to systematically work through the key components of the platform.

## Implementation Tasks

We've developed specific implementation tasks for developers to enhance the Keep platform:

- [Alert Module Tasks](ALERT_MODULE_TASKS.md) - Detailed tasks for modifying the alert ingestion and processing module to handle 600GB/day volumes
- [Developer Guide](DEVELOPER_GUIDE.md) - Step-by-step guide for developers on how to approach and implement their tasks

### Task Implementation Guidelines

For developers, we've created detailed step-by-step implementation guidelines:

1. [Redis Queue Implementation Guide](task_guidelines/01_redis_queue_implementation.md) - Detailed guide for implementing Redis-based queues for high-volume alert processing
2. [Worker Pool Optimization Guide](task_guidelines/02_worker_pool_optimization.md) - Guide for optimizing thread pools and worker management for alert processing
3. [Elasticsearch Integration Guide](task_guidelines/03_elasticsearch_integration.md) - Guide for implementing Elasticsearch for historical alert storage

*Additional guides for other tasks will be added soon.*

## C4 Architecture Diagrams

These diagrams represent different levels of architectural detail following the C4 model approach:

1. [Context Diagram](diagrams/c4/c4_keep_context_improved.puml) - High-level system context showing how Keep AIOps interacts with external systems
2. [Container Diagram](diagrams/c4/c4_keep_container_improved.puml) - Key containers (applications, data stores) that make up the Keep AIOps platform
3. [Component Diagram](diagrams/c4/c4_keep_component_improved.puml) - Major components inside the main Keep API container

You can view the rendered diagrams in the [images directory](images/index.html#c4-architecture-diagrams).

## Class Diagrams

These diagrams show the detailed structure of key subsystems:

1. [Alert/Incident Class Diagram](diagrams/class/alert_incident_class_diagram.puml) - Classes for alert processing and incident management
2. [Workflow Class Diagram](diagrams/class/workflow_class_diagram.puml) - Classes for workflow definition and execution
3. [Provider Class Diagram](diagrams/class/provider_class_diagram.puml) - Classes for integrating with external systems

You can view the rendered diagrams in the [images directory](images/index.html#class-diagrams).

## Sequence Diagrams

These diagrams illustrate key workflows and processes:

1. [Alert Processing Sequence](diagrams/sequence/alert_processing_sequence.puml) - How alerts are processed, correlated, and transformed into incidents
2. [Workflow Execution Sequence](diagrams/sequence/workflow_execution_sequence.puml) - Step-by-step workflow execution process
3. [AI Enrichment Sequence](diagrams/sequence/ai_enrichment_sequence.puml) - Current AI capabilities for enriching alerts and incidents

You can view the rendered diagrams in the [images directory](images/index.html#sequence-diagrams).

## Directory Structure

```
keep_aiops/
├── diagrams/              # Source PlantUML diagram files
│   ├── c4/                # C4 architecture diagrams
│   ├── class/             # Class diagrams
│   └── sequence/          # Sequence diagrams
├── images/                # Generated PNG images and HTML index
├── task_guidelines/       # Detailed implementation guides for tasks
├── CORE_MODULES_CHECKLIST.md  # Checklist of modules to understand and adapt
├── ALERT_MODULE_TASKS.md  # Implementation tasks for alert module
├── DEVELOPER_GUIDE.md  # Guide for developers
└── README.md              # This file
```

## For Team Members

If you're new to the team, follow these steps:

1. Read the [Developer Guide](DEVELOPER_GUIDE.md) to understand how to approach your tasks
2. Review the diagrams to understand the system architecture:
   - Start with the **Class Diagrams** to understand how our main data entities relate to each other
   - Review the **Sequence Diagrams** to see how these components interact to implement key workflows
   - Finally, look at the **C4 Architecture Diagrams** to understand how everything fits into the big picture

For implementing the high-volume enhancements:

1. Find your assigned task in [ALERT_MODULE_TASKS.md](ALERT_MODULE_TASKS.md)
2. Follow the detailed implementation guide for your specific task in the `task_guidelines` directory
3. Use the testing scripts provided in each guide to verify your implementation
4. Ask for help if you encounter issues not covered in the guides

## Generating Diagrams

To regenerate all diagrams, run:

```bash
./scripts/puml_to_image_organized.sh keep_aiops/diagrams
```

Or to generate a specific diagram:

```bash
./scripts/puml_to_image_organized.sh keep_aiops/diagrams/c4/c4_keep_context_improved.puml
```

## Keep AIOps Project

This repository contains documentation and resources related to adapting the Keep platform for high-volume IT Operations incident management.

## Project Overview

Keep will be adapted to process and manage approximately 600GB/day of logs, events, and alerts from various monitoring systems. The adapted solution will provide effective incident management capabilities for large-scale IT operations.

## Goals

- Analyze and understand Keep's core functionality
- Evaluate performance and scalability considerations for high-volume data
- Design architectural modifications necessary for the 600GB/day requirement
- Document implementation approaches for adapting the platform

## Contents

- **diagrams/** - C4 model and UML diagrams showcasing the architecture
  - **c4/** - C4 context, container, and component level diagrams
  - **class/** - Class diagrams for major components
  - **sequence/** - Sequence diagrams for key processes
- **task_guidelines/** - Detailed implementation guides for developers
- **CORE_MODULES_CHECKLIST.md** - Detailed checklist of modules that need to be examined and potentially modified
- **ALERT_MODULE_TASKS.md** - Implementation tasks for developers
- **DEVELOPER_GUIDE.md** - Guide for developers on implementing high-volume enhancements

## Module Alignment Status

### Alert Ingestion & Processing
We have aligned the Alert Ingestion & Processing module documentation with the actual source code implementation. The following updates were made:

1. **Updated Core Modules Checklist**:
   - Added detailed sub-items with specific configuration parameters for high-volume environments
   - Included references to critical environment variables and database structures

2. **Enhanced Diagrams**:
   - C4 Component Diagram now shows Redis queue and Elasticsearch components
   - Class Diagram includes high-volume processing classes like AlertRaw, ProcessEventTask
   - Sequence Diagram illustrates async processing flow with Redis queues

3. **Created Implementation Tasks**:
   - Defined specific development tasks for team members
   - Structured tasks to address all aspects of high-volume processing
   - Established dependencies and implementation guidelines

4. **Developed Detailed Task Guidelines**:
   - Created step-by-step implementation guides with code examples
   - Provided testing scripts and common pitfall warnings
   - Added references to relevant documentation and best practices

5. **Prepared Developer Guide**:
   - Created workflow recommendations for implementing tasks
   - Provided solutions for common challenges
   - Added final checklist for task completion

These improvements ensure our documentation accurately reflects the system's capabilities for handling 600GB/day of logs, events, and alerts.

### Alert Correlation Engine
We have documented the Alert Correlation Engine module to align with the source code implementation. The following updates were made:

1. **Created Comprehensive Documentation**:
   - Detailed the [Alert Correlation Engine](ALERT_CORRELATION_ENGINE.md) architecture and components
   - Documented the CEL-based rule evaluation system
   - Explained the fingerprinting mechanism for alert grouping
   - Outlined the incident creation logic and workflow

2. **Aligned Diagrams with Implementation**:
   - Verified that class diagrams match the actual code structure in `RulesEngine`
   - Ensured sequence diagrams accurately reflect the correlation process
   - Confirmed C4 component diagrams correctly represent system relationships

3. **Added Implementation Details**:
   - Documented key classes like `Rule`, `RulesEngine`, and CEL integration
   - Detailed the multi-level grouping functionality
   - Described the dynamic incident naming system
   - Explained performance optimizations for high-volume environments

4. **Covered Advanced Features**:
   - Documented rule types (condition-based, time-based, topology-based)
   - Explained resolution logic options (FIRST, LAST, ALL, NEVER)
   - Detailed incident creation conditions (ANY, ALL)
   - Described template-based naming with variable substitution

These improvements provide a clear understanding of how the Alert Correlation Engine groups related alerts into meaningful incidents, which is essential for effective high-volume incident management.

### Incident Management
We have documented the Incident Management module to align with the source code implementation. The following updates were made:

1. **Created Comprehensive Documentation**:
   - Detailed the [Incident Management](INCIDENT_MANAGEMENT.md) architecture and components
   - Documented the incident lifecycle from creation to resolution
   - Explained the incident data model and relationships
   - Described the incident reporting and analytics capabilities

2. **Aligned Diagrams with Implementation**:
   - Verified that class diagrams match the actual code structure in `IncidentBl` and `Incident`
   - Ensured sequence diagrams accurately reflect the incident lifecycle
   - Confirmed C4 component diagrams correctly represent system integration points

3. **Added Implementation Details**:
   - Documented key classes like `Incident`, `IncidentStatus`, and `IncidentBl`
   - Detailed the merge incident functionality
   - Described the resolution logic options
   - Explained WebSocket-based notification system
   - Outlined the workflow integration for automation

4. **Covered Performance Optimizations**:
   - Documented database schema optimizations for high-volume environments
   - Explained the async processing for incident operations
   - Detailed caching strategies for incident data
   - Described the LastAlertToIncident table for performance

These improvements provide a clear understanding of the complete incident lifecycle, from creation through correlation to resolution, enabling effective management of incidents in high-volume environments.

### ML-Based Anomaly Detection
We have documented the ML-Based Anomaly Detection module to align with the source code implementation. The following updates were made:

1. **Created Comprehensive Documentation**:
   - Detailed the [ML-Based Anomaly Detection](ML_BASED_ANOMALY_DETECTION.md) architecture and components
   - Documented class structures and relationships
   - Described workflows for model training, inference, and feedback collection
   - Outlined performance optimizations for high-volume environments

2. **Aligned Diagrams with Implementation**:
   - Verified that class diagrams match the actual code structure
   - Ensured sequence diagrams accurately reflect the processing flow
   - Confirmed C4 component diagrams show correct relationships

3. **Added Implementation Details**:
   - Documented key classes like `ExternalAI`, `AISuggestion`, and `TransformersCorrelation`
   - Described the OpenAI integration for intelligent suggestions
   - Detailed the feedback collection system for continuous model improvement
   - Explained caching and deduplication strategies for performance

4. **Highlighted API Endpoints**:
   - Documented the `/ai/suggest` and `/ai/{suggestion_id}/commit` endpoints
   - Explained the request/response flow for AI-powered incident suggestions
   - Detailed the feedback submission process

These improvements provide a clear understanding of the ML-Based Anomaly Detection module's architecture, implementation, and integration with other Keep AIOps components.

## Next Steps

Continue working through the Core Modules Checklist, aligning the documentation with source code implementation for each module. 