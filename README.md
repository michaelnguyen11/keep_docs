# Keep AIOps Platform Documentation

This repository contains comprehensive documentation for the Keep AIOps platform, including architecture diagrams, deployment guides, and subsystem descriptions.

## Repository Structure

```
keep_re_docs/
├── README.md                     # This file
├── diagrams/                     # All PlantUML diagram source files
│   ├── c4/                       # C4 model architecture diagrams
│   │   ├── c4_context_diagram.puml
│   │   ├── c4_container_diagram.puml
│   │   ├── c4_component_diagram.puml
│   │   └── c4_aws_deployment.puml
│   ├── class/                    # Class diagrams
│   │   ├── class_diagram.puml
│   │   ├── class_diagram_core.puml
│   │   └── class_diagram_providers.puml
│   └── sequence/                 # Sequence diagrams
│       ├── sequence_diagram_alert_processing.puml
│       ├── sequence_diagram_workflow_execution.puml
│       ├── sequence_diagram_ai_enrichment.puml
│       └── workflow_execution_sequence.puml
├── docs/                         # Documentation
│   ├── architecture/             # Architecture documentation
│   │   ├── overview.md           # General platform overview
│   │   └── agentic_ai_integration.md
│   ├── deployment/               # Deployment guides
│   │   └── aws_guide.md          # AWS deployment guide
│   └── subsystems/               # Subsystem documentation
│       ├── workflow_system.md    # Workflow system details
│       └── provider_system.md    # Provider system details
├── images/                       # Generated diagram images
│   └── index.html                # HTML index of all diagrams
└── scripts/                      # Utility scripts
    ├── puml_to_image.sh          # Script to generate diagram images
    └── plantuml-1.2025.2.jar     # PlantUML JAR file
```

## Documentation Overview

### Architecture Documentation

- **[Platform Overview](docs/architecture/overview.md)**: General overview of the Keep AIOps platform, including its features, components, and architecture.
- **[Agentic AI Integration](docs/architecture/agentic_ai_integration.md)**: Information on how Agentic AI capabilities can be integrated with the Keep platform.

### Deployment Guides

- **[AWS Deployment Guide](docs/deployment/aws_guide.md)**: Detailed guide on deploying Keep AIOps on AWS, including architecture, implementation steps, and best practices.

### Subsystem Documentation

- **[Workflow System](docs/subsystems/workflow_system.md)**: Detailed documentation on the workflow system, including triggers, steps, actions, and context.
- **[Provider System](docs/subsystems/provider_system.md)**: Documentation on the provider system, which enables integration with external services.

## Diagrams

The repository includes several types of diagrams:

1. **C4 Model Diagrams**: Context, Container, and Component diagrams showing the architecture at different levels of detail, plus a deployment diagram for AWS.
2. **Class Diagrams**: Showing the data model and key classes.
3. **Sequence Diagrams**: Illustrating key processes like alert processing and workflow execution.

## Working with Diagrams

### Viewing Diagrams

Pre-generated images of all diagrams are available in the `images` directory. You can view all diagrams in a web browser by opening `images/index.html`.

### Generating Diagram Images

To generate or update diagram images:

1. Ensure you have Java installed
2. Run the diagram generation script:

```bash
# From the root of keep_re_docs directory
./scripts/puml_to_image.sh
```

This will convert all PlantUML files in the `diagrams` directory to PNG images and place them in the `images` directory.

You can also convert specific diagrams or directories:

```bash
# Convert a specific diagram
./scripts/puml_to_image.sh diagrams/c4/c4_context_diagram.puml

# Convert all diagrams in a specific directory
./scripts/puml_to_image.sh diagrams/class
```

## Contributing

When contributing to this documentation:

1. Place new diagram source files in the appropriate subdirectory under `diagrams/`
2. Place new documentation in the appropriate subdirectory under `docs/`
3. Run the `puml_to_image.sh` script to generate images for any new or updated diagrams
4. Update this README if you add new categories of documentation 