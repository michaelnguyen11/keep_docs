# Keep AIOps Platform Documentation

This directory has been reorganized to separate the documentation of the current Keep AIOps Platform from the planned Agentic AI integration.

## Open documents on Web Browser
```bash
open index.html
```

## New Organization Structure

The documentation is now organized into two main sections:

### [Keep AIOps Platform](keep_aiops/README.md)

Documentation about the current Keep AIOps Platform architecture, including:
- C4 model architecture diagrams (Context, Container, and Component levels)
- Class diagrams for key subsystems (Alert/Incident, Workflow, Provider)
- Sequence diagrams showing dynamic behavior (Alert Processing, Workflow Execution, AI Enrichment)
- Written documentation about the platform architecture

### [Agentic AI Integration](keep_agentic/README.md)

Documentation about the planned integration of Agentic AI capabilities with Keep, including:
- C4 model integration architecture diagrams
- Architecture options analysis
- Implementation timelines
- Executive summaries

## For Team Members

If you're new to the team or need a more concrete understanding of the codebase:

1. Start with the [Class Diagrams](keep_aiops/diagrams/class) which show how the system's main classes are structured
2. Review the [Sequence Diagrams](keep_aiops/diagrams/sequence) to understand how the components interact
3. Then explore the higher-level [C4 Diagrams](keep_aiops/diagrams/c4) for the big picture

## Generating Diagram Images

Use the following script to generate PNG images from any PlantUML diagram:

```bash
./scripts/puml_to_image.sh keep_aiops/diagrams/class/alert_incident_class_diagram.puml
```

This will create corresponding PNG files in the `images` directory and update the HTML index. 