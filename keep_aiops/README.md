# Keep AIOps Platform Documentation

This directory contains comprehensive documentation and diagrams of the Keep AIOps Platform architecture in its current state, before the integration of Agentic AI capabilities.

## Core Modules Checklist

We've created a [Core Modules Checklist](CORE_MODULES_CHECKLIST.md) to track our understanding and adaptation of Keep AIOps for high-volume IT Operations incident handling. Use this checklist to systematically work through the key components of the platform.

## Implementation Tasks

We've developed specific implementation tasks for junior developers to enhance the Keep platform:

- [Alert Module Tasks](ALERT_MODULE_TASKS.md) - Detailed tasks for modifying the alert ingestion and processing module to handle 600GB/day volumes
- [Junior Developer Guide](JUNIOR_DEVELOPER_GUIDE.md) - Step-by-step guide for junior developers on how to approach and implement their tasks

### Task Implementation Guidelines

For junior developers, we've created detailed step-by-step implementation guidelines:

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
├── JUNIOR_DEVELOPER_GUIDE.md  # Guide for junior developers
└── README.md              # This file
```

## For Junior Team Members

If you're new to the team, follow these steps:

1. Read the [Junior Developer Guide](JUNIOR_DEVELOPER_GUIDE.md) to understand how to approach your tasks
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
- **task_guidelines/** - Detailed implementation guides for junior developers
- **CORE_MODULES_CHECKLIST.md** - Detailed checklist of modules that need to be examined and potentially modified
- **ALERT_MODULE_TASKS.md** - Implementation tasks for junior developers
- **JUNIOR_DEVELOPER_GUIDE.md** - Guide for junior developers on implementing high-volume enhancements

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
   - Defined specific development tasks for junior team members
   - Structured tasks to address all aspects of high-volume processing
   - Established dependencies and implementation guidelines

4. **Developed Detailed Task Guidelines**:
   - Created step-by-step implementation guides with code examples
   - Provided testing scripts and common pitfall warnings
   - Added references to relevant documentation and best practices

5. **Prepared Junior Developer Guide**:
   - Created workflow recommendations for implementing tasks
   - Provided solutions for common challenges
   - Added final checklist for task completion

These improvements ensure our documentation accurately reflects the system's capabilities for handling 600GB/day of logs, events, and alerts.

## Next Steps

Continue working through the Core Modules Checklist, aligning the documentation with source code implementation for each module. 