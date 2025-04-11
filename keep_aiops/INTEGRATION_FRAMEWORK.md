# Keep AIOps Integration Framework

## Overview

The Integration Framework is a crucial component of the Keep AIOps platform that enables seamless connectivity with various monitoring systems, ticketing tools, notification services, and other external systems. It allows both ingestion of alerts from external systems and actions to be taken in response to incidents.

The framework follows a provider-based architecture where each integration is implemented as a provider with standardized interfaces. This makes it easy to add new integrations and maintain existing ones.

## Key Components

### Provider Architecture

1. **Base Provider Classes**:
   - `BaseProvider`: The foundation for all providers, implements common functionality
   - `BaseTopologyProvider`: For providers that can fetch topology information
   - `BaseIncidentProvider`: For providers that can fetch and interact with incidents

2. **Provider Factory**:
   - `ProvidersFactory`: Central factory that loads, instantiates, and manages providers
   - Handles provider configuration, validation, and caching

3. **Provider Configuration**:
   - Each provider defines its configuration requirements using Pydantic models
   - Supports authentication, connection settings, and provider-specific parameters
   - Handles sensitive information securely

4. **Provider Scopes**:
   - Define capabilities and permissions for each provider
   - Used for validation and access control

## Alert Ingestion Pathways

Keep offers several ways to ingest alerts from external systems:

### 1. Webhook API Endpoints

The platform exposes several webhook endpoints to receive alerts:

- **Generic Webhook** (`POST /api/alerts/event`): 
  - Accepts generic alerts in Keep's alert format
  - Requires API key authentication
  - Returns 202 Accepted status

- **Provider-Specific Webhook** (`POST /api/alerts/event/{provider_type}`):
  - Accepts alerts in provider's native format
  - Automatically formats and processes based on provider type
  - Supports various authentication methods (Basic, API key, custom headers)

### 2. Pull-Based Integration

Providers can implement the `_get_alerts()` method to actively fetch alerts from external systems:

```python
def _get_alerts(self) -> list[AlertDto]:
    """Implementation fetches alerts from an external system"""
    # Provider-specific code to fetch alerts
    return alert_dtos
```

This is used for systems that don't support webhooks or when polling is preferred.

### 3. Alert Processing

When alerts are received:

1. They're validated and normalized to Keep's internal format
2. Fingerprinting is applied for deduplication
3. Alerts are enriched with additional context
4. They're processed asynchronously through a task queue (ARQ+Redis)
5. The correlation engine analyzes them for potential incident creation

## Integration Development

### Creating a New Provider

To integrate a new monitoring system, you need to:

1. Create a new directory under `keep/providers/[provider_name]_provider/`
2. Implement a provider class that extends `BaseProvider`
3. Define the authentication configuration class
4. Implement required methods:
   - `validate_config()`: Validate provider configuration
   - `dispose()`: Clean up resources
   - `_notify()` or `_query()`: Implement provider-specific actions

Example skeleton:

```python
class MyMonitoringProviderAuthConfig:
    url: pydantic.AnyHttpUrl = dataclasses.field(
        metadata={
            "required": True,
            "description": "API URL",
            "validation": "any_http_url",
        }
    )
    api_key: str = dataclasses.field(
        metadata={
            "required": True,
            "description": "API Key",
            "sensitive": True
        }
    )

class MyMonitoringProvider(BaseProvider):
    PROVIDER_CATEGORY = ["Monitoring"]
    PROVIDER_TAGS = ["alert"]
    FINGERPRINT_FIELDS = ["id", "name"]

    def validate_config(self):
        self.authentication_config = MyMonitoringProviderAuthConfig(
            **self.config.authentication
        )

    def dispose(self):
        # Clean up resources
        pass

    def _get_alerts(self) -> list[AlertDto]:
        # Fetch alerts from your monitoring system
        response = requests.get(
            f"{self.authentication_config.url}/alerts",
            headers={"Authorization": f"Bearer {self.authentication_config.api_key}"}
        )
        response.raise_for_status()
        alerts_data = response.json()
        # Convert to Keep's format
        return self._format_alert(alerts_data)

    @staticmethod
    def _format_alert(event: dict) -> list[AlertDto]:
        # Transform provider-specific alert format to Keep's format
        # ...
```

### Alert Format Transformation

A critical part of integration is translating between Keep's alert format and the provider's native format:

```python
@staticmethod
def _format_alert(event: dict) -> list[AlertDto]:
    alert_dtos = []
    for alert in event.get("alerts", []):
        alert_dto = AlertDto(
            id=alert.get("id"),
            name=alert.get("name"),
            description=alert.get("description", ""),
            status=AlertStatus.FIRING,  # Map provider status to Keep status
            service=alert.get("service"),
            lastReceived=datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
            environment=alert.get("environment", "production"),
            severity=MyMonitoringProvider._map_severity(alert.get("severity")),
            source=["my_monitoring_system"],
            fingerprint=alert.get("fingerprint", ""),  # Use provider fingerprint or generate one
            labels=alert.get("labels", {}),
            annotations=alert.get("annotations", {})
        )
        alert_dtos.append(alert_dto)
    return alert_dtos
```

### Webhook Setup

For systems that support webhooks, you can implement automatic webhook setup:

```python
def setup_webhook(self, tenant_id: str, keep_api_url: str, api_key: str, setup_alerts: bool = True) -> dict:
    """Set up webhooks in the provider's system to send alerts to Keep"""
    webhook_url = f"{keep_api_url}/api/alerts/event/{self.provider_type}?provider_id={self.provider_id}"
    
    # Provider-specific code to register webhook
    response = requests.post(
        f"{self.authentication_config.url}/webhooks",
        headers={"Authorization": f"Bearer {self.authentication_config.api_key}"},
        json={
            "url": webhook_url,
            "auth": {
                "type": "basic",
                "username": "api_key",
                "password": api_key
            },
            "events": ["alerts"]
        }
    )
    
    return {"status": "success", "webhook_id": response.json().get("id")}
```

## Rate Limiting and Throttling

The Integration Framework includes built-in rate limiting and throttling to prevent overwhelming external systems:

1. **Step Throttling**: In workflows, steps can be throttled to prevent too many actions in a short period
2. **Provider-Level Rate Limiting**: Some providers implement rate limiting based on API quotas

## Authentication and Security

The framework supports various authentication methods:

1. **Basic Authentication**: Username/password
2. **API Key**: Token-based authentication
3. **OAuth**: For providers that require OAuth flow
4. **Custom Headers**: For providers with unique authentication requirements

Sensitive configuration (passwords, tokens) is stored securely and never exposed in logs or UI.

## Monitoring and Troubleshooting

Integration health can be monitored via:

1. **Provider Status**: Check if the provider is connected and functioning
2. **Alert Error Logs**: View alerts that failed to process
3. **Provider Logs**: Detailed logs for each provider
4. **Integration Health Report**: For providers that implement the `ProviderHealthMixin`

## Available Integrations

Keep AIOps comes with a wide range of pre-built integrations, including:

### Monitoring Systems
- Prometheus
- Grafana
- CloudWatch
- DataDog
- Elastic
- New Relic
- Zabbix
- Many more...

### Notification Services
- Slack
- Teams
- Email (SMTP)
- PagerDuty
- OpsGenie
- Many more...

### Ticketing Systems
- Jira
- ServiceNow
- Zendesk
- Linear
- Many more...

## Best Practices for Integration

1. **Use Webhooks Where Possible**: Webhooks provide real-time alert ingestion vs. polling
2. **Implement Proper Error Handling**: Handle API failures gracefully
3. **Follow Rate Limits**: Respect API limits of external systems
4. **Use Fingerprinting**: Ensure proper alert deduplication
5. **Secure Credentials**: Always use secure storage for credentials

## Custom Integration Development

For systems not supported out-of-the-box:

1. Use the webhook provider for simple webhook forwarding
2. Implement a custom provider for deeper integration
3. Consider using HTTP or Python providers for quick custom solutions

## Getting Started with a New Integration

1. Check if Keep already supports your system in the provider directory
2. Configure provider with the necessary authentication
3. Set up webhook or polling based on your system's capabilities
4. Test alert flow from your system to Keep
5. Create workflows to automate responses to alerts 