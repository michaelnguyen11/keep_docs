# Keep Provider System

## Overview

The Provider System is a core component of the Keep platform that facilitates integration with external services. It provides a standardized interface for connecting to, authenticating with, and executing operations against a wide range of external systems, from observability tools to ticketing systems to AI services.

## Architecture

The Provider System follows a modular architecture with several key components:

### Base Provider

The `BaseProvider` class serves as the foundation for all providers, implementing common functionality:

1. **Authentication Management**: Handling credentials and authentication flows
2. **Method Registration**: Registering methods that can be called on the provider
3. **Scope Validation**: Ensuring operations have the necessary permissions
4. **Configuration Management**: Storing and validating provider-specific configuration
5. **Connection Management**: Establishing and maintaining connections to external services

### Provider Types

Providers are categorized into different types based on their functionality:

1. **Observability Providers**: Integration with monitoring and observability tools
2. **Communication Providers**: Integration with notification and communication platforms
3. **Ticketing Providers**: Integration with issue tracking and incident management systems
4. **AI Providers**: Integration with AI and LLM services
5. **Documentation Providers**: Integration with documentation and knowledge management systems
6. **CMDB Providers**: Integration with configuration management databases
7. **Source Control Providers**: Integration with source code repositories
8. **Authentication Providers**: Integration with identity providers

### Provider Registry

The Provider Registry maintains a catalog of available providers:

1. **Discovery**: Automatically discovers provider implementations
2. **Registration**: Registers providers and their capabilities
3. **Instantiation**: Creates provider instances when needed
4. **Configuration**: Stores provider configuration templates

## Provider Implementation

### Provider Definition

Each provider is implemented as a class that inherits from `BaseProvider`:

```python
class SlackProvider(BaseProvider):
    provider_type = "slack"
    name = "Slack"
    description = "Slack integration for Keep"
    logo = "slack.svg"
    
    auth_spec = {
        "type": "oauth2",
        "oauth2_spec": {
            "client_id": {"type": "string", "required": True},
            "client_secret": {"type": "secret", "required": True},
            "scopes": ["chat:write", "channels:read", "channels:manage"]
        }
    }
    
    config_spec = {
        "default_channel": {"type": "string", "required": False}
    }
    
    @provider_method
    def post_message(self, channel: str, message: str, blocks: list = None) -> dict:
        """
        Post a message to a Slack channel.
        
        Args:
            channel: The channel to post to
            message: The message text
            blocks: Optional message blocks
            
        Returns:
            dict: The response from Slack
        """
        # Method implementation
```

### Authentication Schemes

The Provider System supports multiple authentication schemes:

1. **OAuth2**: For providers that use OAuth 2.0 (Slack, GitHub, etc.)
2. **API Key**: For providers that use API keys (Datadog, PagerDuty, etc.)
3. **Username/Password**: For providers that use basic authentication
4. **JWT**: For providers that use JWT tokens
5. **Custom**: For providers with unique authentication requirements

### Method Registration

Provider methods are registered using the `@provider_method` decorator:

```python
@provider_method
def create_issue(self, project: str, summary: str, description: str, 
                 issue_type: str = "Task", priority: str = "Medium") -> dict:
    """
    Create an issue in the ticketing system.
    
    Args:
        project: Project key
        summary: Issue summary
        description: Issue description
        issue_type: Issue type (Task, Bug, etc.)
        priority: Issue priority
        
    Returns:
        dict: The created issue
    """
    # Method implementation
```

The decorator handles:
1. Parameter validation
2. Authentication
3. Rate limiting
4. Error handling
5. Result processing

### Scopes and Permissions

Provider methods can require specific scopes:

```python
@provider_method(scopes=["issue:write"])
def create_issue(self, project: str, summary: str, description: str) -> dict:
    # Method implementation
```

Workflows using these methods must have the appropriate permissions.

## Provider Categories

### Observability Providers

Connect to monitoring and observability tools to receive alerts and query metrics:

1. **Datadog**: Metrics, logs, and alerts from Datadog
2. **Prometheus**: Time-series database for metrics
3. **CloudWatch**: AWS monitoring service
4. **New Relic**: Application performance monitoring
5. **Dynatrace**: Full-stack monitoring
6. **Elastic**: ELK stack integration
7. **Grafana**: Metrics visualization
8. **Azure Monitor**: Microsoft Azure monitoring
9. **GCP Monitoring**: Google Cloud monitoring
10. **Splunk**: Log and metrics platform

### Communication Providers

Send notifications and messages to communication platforms:

1. **Slack**: Team messaging platform
2. **Microsoft Teams**: Microsoft's collaboration platform
3. **Discord**: Community messaging platform
4. **Email**: SMTP-based email delivery
5. **PagerDuty**: Incident response platform
6. **OpsGenie**: Alert management platform
7. **Webhook**: Generic webhook integration
8. **SMS**: Text message delivery
9. **Telegram**: Messaging platform
10. **WhatsApp**: Business messaging

### Ticketing Providers

Create and manage tickets and issues in tracking systems:

1. **Jira**: Atlassian's issue tracking
2. **ServiceNow**: IT service management platform
3. **GitHub Issues**: Issue tracking in GitHub
4. **GitLab Issues**: Issue tracking in GitLab
5. **Linear**: Modern issue tracking
6. **Zendesk**: Customer service platform
7. **Asana**: Project management tool
8. **Trello**: Card-based project management
9. **Azure DevOps**: Microsoft's development platform
10. **Shortcut**: Project management for software teams

### AI Providers

Connect to AI and LLM services for automated analysis and response:

1. **OpenAI**: GPT models (3.5, 4, etc.)
2. **Anthropic**: Claude models
3. **Google AI (Gemini)**: Google's AI models
4. **Mistral AI**: Open-weight models
5. **Cohere**: Embeddings and text generation
6. **DeepSeek**: DeepSeek LLMs
7. **Ollama**: Local LLM runtime
8. **Hugging Face**: Model hub integration
9. **Grok**: xAI's models
10. **LlamaIndex**: RAG framework integration

## Provider Operations

### Common Operations

Providers support various operations depending on their category:

1. **Alert Management**:
   - Receiving alerts
   - Acknowledging alerts
   - Resolving alerts
   - Querying alert history

2. **Incident Management**:
   - Creating incidents
   - Updating incidents
   - Assigning incidents
   - Resolving incidents

3. **Communication**:
   - Sending messages
   - Creating channels/rooms
   - Inviting users
   - Posting updates

4. **Data Retrieval**:
   - Querying metrics
   - Retrieving logs
   - Searching for entities
   - Fetching configurations

### Method Parameters

Provider methods accept parameters specific to their functionality:

```yaml
# Example of a Jira create_issue action in a workflow
create_ticket:
  action: jira.create_issue
  params:
    project: OPS
    summary: "Critical incident in production"
    description: "Service is experiencing high error rates"
    issuetype: Incident
    priority: Highest
    components: ["Backend"]
    labels: ["production", "critical"]
```

### Result Processing

Provider methods return structured results that can be used in workflow context:

```yaml
# Using the result of a Jira create_issue action
add_comment:
  depends_on: create_ticket
  action: jira.add_comment
  params:
    issue_id: "{{ context.create_ticket.result.id }}"
    comment: "Automatically created by Keep"
```

## Provider Authentication

### Authentication Flow

The authentication flow varies by provider and authentication type:

1. **OAuth2 Flow**:
   - User initiates authentication
   - Keep redirects to provider authorization page
   - User grants access
   - Provider redirects back with authorization code
   - Keep exchanges code for access/refresh tokens
   - Keep securely stores tokens

2. **API Key Flow**:
   - User obtains API key from provider
   - User enters API key in Keep
   - Keep validates the key
   - Keep securely stores the key

### Secrets Management

Provider credentials are securely stored using the Secrets Manager:

1. **Storage Options**:
   - File-based storage (development)
   - Kubernetes Secrets
   - Google Cloud Secret Manager
   - HashiCorp Vault
   - AWS Secrets Manager

2. **Encryption**:
   - Credentials are encrypted at rest
   - Encryption keys are managed securely
   - Access is restricted by permissions

## Provider Configuration

### Configuration Schema

Each provider defines a configuration schema:

```python
config_spec = {
    "project": {
        "type": "string",
        "required": True,
        "description": "Default project key"
    },
    "issue_type": {
        "type": "string",
        "required": False,
        "description": "Default issue type",
        "default": "Task"
    },
    "labels": {
        "type": "array",
        "required": False,
        "description": "Default labels to apply"
    }
}
```

### UI Configuration

The provider system generates configuration UI based on the schema:

1. **Forms**: Auto-generated based on the config schema
2. **Validation**: Client and server-side validation
3. **Testing**: Connection testing functionality
4. **Documentation**: Inline help and documentation

## Extensibility

### Custom Providers

Users can create custom providers for specific needs:

1. **Provider SDK**: Development toolkit for custom providers
2. **Documentation**: Implementation guidelines and examples
3. **Testing Tools**: Tools for testing custom providers
4. **Deployment**: Process for deploying custom providers

### Extending Existing Providers

Existing providers can be extended with additional capabilities:

1. **Method Overrides**: Override existing methods
2. **Method Additions**: Add new methods
3. **Configuration Extensions**: Extend configuration options
4. **Authentication Extensions**: Extend authentication mechanisms

## Future Directions for Agentic AI Integration

The Provider System is well-positioned for enhancement with Agentic AI capabilities:

### Agent Provider Type

A new `AgentProvider` type could extend the `BaseProvider` class:

```python
class AgentProvider(BaseProvider):
    provider_type = "agent"
    
    @provider_method
    def run_tool(self, tool_name: str, tool_params: dict) -> dict:
        """
        Run a specific tool with the agent.
        """
        # Implementation
    
    @provider_method
    def investigate(self, incident_id: str, investigation_scope: str) -> dict:
        """
        Perform an autonomous investigation of an incident.
        """
        # Implementation
```

### Tool-Based Interaction

Agents could interact with the system through a tools framework:

1. **Tool Registry**: Register tools available to agents
2. **Tool Permissions**: Control what tools agents can use
3. **Tool Execution**: Execute tools on behalf of agents
4. **Result Processing**: Process tool results for agent consumption

### Multi-Agent Orchestration

The Provider System could enable orchestration of multiple specialized agents:

1. **Agent Registry**: Register available agents
2. **Agent Roles**: Define specialized roles for agents
3. **Communication Protocol**: Enable agent-to-agent communication
4. **Task Delegation**: Allow agents to delegate tasks to other agents

## Conclusion

The Keep Provider System offers a powerful and extensible framework for integrating with external services. Its modular architecture, standardized interfaces, and comprehensive security features make it adaptable to a wide range of use cases. The system's design principles facilitate both the use of built-in providers and the development of custom integrations, ensuring that Keep can connect to virtually any external service required for effective incident management. 