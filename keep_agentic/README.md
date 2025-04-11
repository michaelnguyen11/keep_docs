# Agentic AI Integration Documentation

This directory contains documentation and diagrams for integrating Agentic AI capabilities with the Keep AIOps Platform.

## C4 Architecture Diagrams

These diagrams illustrate the proposed architecture for integrating Agentic AI with Keep:

### Integration Architecture

1. [Detailed Integration Diagram](diagrams/c4/c4_agentic_integration_detailed.puml) - Detailed view of the integration between Keep and Agentic AI
2. [Detailed Integration (Color-coded)](diagrams/c4/c4_agentic_integration_detailed_color.puml) - Color-coded version distinguishing existing vs. new components
3. [Simplified Integration Diagram](diagrams/c4/c4_agentic_integration_simplified.puml) - Simplified view of the integration architecture
4. [Simplified Integration (Color-coded)](diagrams/c4/c4_agentic_integration_simplified_color.puml) - Color-coded simplified version

You can view the rendered diagrams in the [images directory](images/index.html#c4-architecture-diagrams).

### Container and Component Level

1. [Container Diagram](diagrams/c4/c4_agentic_container.puml) - Key containers in the Agentic AI system
2. [Component Diagram](diagrams/c4/c4_agentic_component.puml) - Major components inside the Agentic AI containers

## Implementation Timeline

These diagrams outline the implementation plans for integrating Agentic AI:

1. [Implementation Timeline](diagrams/c4/c4_implementation_timeline.puml) - High-level implementation roadmap
2. [PoC Timeline](diagrams/c4/c4_poc_timeline.puml) - Detailed timeline for the proof-of-concept phase

You can view the rendered diagrams in the [images directory](images/index.html#c4-architecture-diagrams).

## Directory Structure

```
keep_agentic/
├── diagrams/              # Source PlantUML diagram files
│   └── c4/                # C4 architecture and timeline diagrams
├── images/                # Generated PNG images and HTML index
└── README.md              # This file
```

## Architectural Approach

The Agentic AI integration is designed to:

1. **Enhance existing Keep capabilities** with advanced AI/ML features
2. **Minimize changes to the core platform** by using a modular approach
3. **Follow a phased implementation** starting with a proof-of-concept

## Key Benefits

1. **Autonomous incident resolution** through AI-powered agents
2. **Improved alert correlation** using advanced machine learning
3. **Reduced mean time to resolution (MTTR)** for common incidents
4. **Knowledge-powered responses** leveraging historical incident data

## Generating Diagrams

To regenerate all Agentic AI integration diagrams, run:

```bash
./scripts/puml_to_image_organized.sh keep_agentic/diagrams
```

Or to generate a specific diagram:

```bash
./scripts/puml_to_image_organized.sh keep_agentic/diagrams/c4/c4_agentic_integration_detailed.puml
``` 