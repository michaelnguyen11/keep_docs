# Keep Workflow System

## Overview

The Keep Workflow System is a powerful automation engine that enables users to define and execute complex workflows for alert and incident management. Inspired by GitHub Actions, the workflow system uses a YAML-based configuration language to define triggers, steps, actions, and conditions.

## Core Components

### Workflow Engine

The Workflow Engine is responsible for:

1. **Workflow Definition Management**: Storing and validating workflow YAML definitions
2. **Trigger Processing**: Determining when workflows should be executed
3. **Workflow Execution**: Running the defined steps and actions
4. **Context Management**: Maintaining and providing access to execution context
5. **Provider Integration**: Executing actions through the provider system

### Context Manager

The Context Manager maintains the state during workflow execution:

1. **Variable Resolution**: Resolves context variables in templates using `{{ variable }}` syntax
2. **State Tracking**: Maintains the results of each step
3. **Parameter Resolution**: Resolves parameters for steps and actions
4. **CEL Evaluation**: Evaluates conditions using Common Expression Language

### Provider System

The Provider System enables interaction with external services:

1. **Authentication**: Manages credentials for external services
2. **Method Execution**: Executes provider-specific methods
3. **Result Processing**: Processes and normalizes results from external services
4. **Error Handling**: Handles errors and retries for external service calls

## Workflow Definition

Workflows are defined in YAML with the following structure:

```yaml
name: Workflow Name
description: Optional description
constants:
  KEY1: value1
  KEY2: value2
triggers:
  - type: alert
    filters:
      provider: provider_name
      severity: critical
  - type: incident
    filters:
      status: firing
  - type: schedule
    cron: "0 9 * * 1-5"
  - type: manual
steps:
  step_id:
    name: Step Name
    action: provider_name.method_name
    params:
      param1: value1
      param2: "{{ context.variable }}"
    continue_on_fail: false
    condition: context.step_id.success == true
  another_step:
    name: Another Step
    depends_on: step_id
    foreach: "{{ context.items }}"
    steps:
      nested_step:
        name: Nested Step
        action: provider_name.another_method
        params:
          param: "{{ context.foreach_item }}"
```

## Triggers

Workflows can be triggered by various events:

### Alert Triggers

Executes a workflow when an alert is received that matches specific filters:

```yaml
triggers:
  - type: alert
    filters:
      provider: datadog
      severity: critical
      source: production
```

### Incident Triggers

Executes a workflow when an incident is created or updated:

```yaml
triggers:
  - type: incident
    filters:
      status: firing
      severity: high
```

### Schedule Triggers

Executes a workflow on a regular schedule using cron syntax:

```yaml
triggers:
  - type: schedule
    cron: "0 9 * * 1-5"  # Every weekday at 9 AM
```

### Manual Triggers

Allows workflows to be triggered manually through the UI or API:

```yaml
triggers:
  - type: manual
    require_confirmation: true
```

## Steps and Actions

Workflows consist of steps, which can be either built-in steps or provider actions:

### Basic Steps

A simple step calling a provider action:

```yaml
get_incident_details:
  name: Get Incident Details
  action: keep.get_incident
  params:
    incident_id: "{{ context.incident.id }}"
```

### Conditional Execution

Steps can be conditionally executed based on CEL expressions:

```yaml
create_jira_ticket:
  name: Create Jira Ticket
  condition: context.incident.severity == "critical"
  action: jira.create_issue
  params:
    project: OPS
    summary: "Critical Incident: {{ context.incident.title }}"
    description: "{{ context.incident.description }}"
```

### Foreach Loops

Steps can iterate over lists using the `foreach` attribute:

```yaml
notify_on_call:
  name: Notify On-Call Engineers
  foreach: "{{ context.on_call_engineers }}"
  steps:
    send_sms:
      name: Send SMS
      action: twilio.send_sms
      params:
        to: "{{ context.foreach_item.phone }}"
        message: "Critical alert: {{ context.incident.title }}"
```

### Parallel Execution

Steps can be executed in parallel:

```yaml
parallel_actions:
  name: Parallel Actions
  parallel:
    create_ticket:
      name: Create Ticket
      action: jira.create_issue
      # ...
    send_slack:
      name: Send Slack Message
      action: slack.post_message
      # ...
```

### Step Dependencies

Steps can depend on other steps:

```yaml
create_ticket:
  name: Create Ticket
  action: jira.create_issue
  # ...

add_comment:
  name: Add Comment
  depends_on: create_ticket
  action: jira.add_comment
  params:
    issue_id: "{{ context.create_ticket.issue_id }}"
    comment: "This is a follow-up comment"
```

## Context System

The context system provides access to data within workflows using the `{{ }}` template syntax:

### Available Context Variables

1. **Alert Context**
   - `context.alert`: The alert that triggered the workflow
   - `context.alert.id`, `context.alert.name`, `context.alert.source`, etc.

2. **Incident Context**
   - `context.incident`: The incident that triggered the workflow
   - `context.incident.id`, `context.incident.title`, `context.incident.severity`, etc.

3. **Step Results**
   - `context.step_id`: Results from previous steps
   - `context.step_id.result`: The return value
   - `context.step_id.success`: Boolean success status

4. **Constants**
   - `context.constants.KEY`: Constants defined in the workflow

5. **Foreach Context**
   - `context.foreach_item`: The current item in a foreach loop
   - `context.foreach_index`: The current index in a foreach loop

### Context Usage Examples

```yaml
# Using alert context
create_ticket:
  action: jira.create_issue
  params:
    summary: "Alert: {{ context.alert.name }}"
    description: "{{ context.alert.description }}"

# Using step results
add_comment:
  depends_on: create_ticket
  action: jira.add_comment
  params:
    issue_id: "{{ context.create_ticket.result.id }}"
    comment: "Additional information"

# Using constants
notify_team:
  action: slack.post_message
  params:
    channel: "{{ context.constants.SLACK_CHANNEL }}"
    message: "New alert: {{ context.alert.name }}"
```

## Conditions

Conditions use Common Expression Language (CEL) to determine whether steps should be executed:

### Condition Syntax

Conditions are CEL expressions that evaluate to a boolean:

```yaml
step_id:
  condition: context.alert.severity == "critical" && context.alert.source == "production"
  # ...
```

### Available CEL Functions

- **String functions**: `startsWith()`, `endsWith()`, `contains()`
- **Array functions**: `in`, `size()`, `filter()`
- **Object functions**: `has()`, `get()`
- **Logical operators**: `&&`, `||`, `!`
- **Comparison operators**: `==`, `!=`, `>`, `<`, `>=`, `<=`

### Condition Examples

```yaml
# Check alert severity
high_severity_action:
  condition: context.alert.severity in ["critical", "high"]
  # ...

# Check previous step result
conditional_step:
  condition: context.previous_step.success && context.previous_step.result.status == "ok"
  # ...

# Complex condition
complex_condition:
  condition: context.incident.services.filter(s, s.contains("api")).size() > 0
  # ...
```

## Provider Actions

Provider actions enable integration with external services:

### Built-in Providers

1. **keep**: Built-in actions for the Keep platform
   - `keep.get_alert`
   - `keep.get_incident`
   - `keep.update_incident`
   - `keep.run_workflow`

2. **http**: Generic HTTP requests
   - `http.get`
   - `http.post`
   - `http.put`
   - `http.delete`

### External Providers

1. **Observability**
   - `datadog`, `prometheus`, `cloudwatch`, etc.

2. **Communication**
   - `slack`, `teams`, `discord`, `email`, etc.

3. **Ticketing**
   - `jira`, `servicenow`, `linear`, `zendesk`, etc.

4. **AI**
   - `openai`, `anthropic`, `gemini`, etc.

### Action Parameters

Each provider action accepts specific parameters:

```yaml
slack_notification:
  action: slack.post_message
  params:
    channel: "#incidents"
    message: "Critical alert: {{ context.alert.name }}"
    blocks:
      - type: header
        text: "Critical Alert"
      - type: section
        text: "{{ context.alert.description }}"
```

## Workflow Examples

### Alert Enrichment

```yaml
name: Alert Enrichment
description: Enriches alerts with additional context
triggers:
  - type: alert
    filters:
      severity: critical
steps:
  get_service_info:
    name: Get Service Information
    action: keep.get_service
    params:
      service: "{{ context.alert.service }}"
  
  add_runbook:
    name: Add Runbook Link
    depends_on: get_service_info
    action: keep.update_alert
    params:
      alert_id: "{{ context.alert.id }}"
      additional_properties:
        runbook_url: "{{ context.get_service_info.result.runbook_url }}"
        team_owner: "{{ context.get_service_info.result.team }}"
```

### Incident Response

```yaml
name: Critical Incident Response
description: Automated response to critical incidents
triggers:
  - type: incident
    filters:
      severity: critical
      status: firing
steps:
  create_slack_channel:
    name: Create Slack Channel
    action: slack.create_channel
    params:
      name: "incident-{{ context.incident.id }}"
  
  create_jira_ticket:
    name: Create Jira Ticket
    action: jira.create_issue
    params:
      project: OPS
      summary: "{{ context.incident.title }}"
      description: "{{ context.incident.description }}"
      issuetype: Incident
      priority: Highest
  
  notify_team:
    name: Notify On-Call Team
    action: pagerduty.create_incident
    params:
      service: "{{ context.incident.service }}"
      title: "{{ context.incident.title }}"
      body: "{{ context.incident.description }}"
      urgency: high
```

### Business Hours Response

```yaml
name: Business Hours Response
description: Different response based on business hours
triggers:
  - type: alert
    filters:
      severity: high
steps:
  check_business_hours:
    name: Check Business Hours
    action: keep.business_hours
    params:
      timezone: America/New_York
  
  slack_notification:
    name: Send Slack Notification
    action: slack.post_message
    params:
      channel: "#alerts"
      message: "High Severity Alert: {{ context.alert.name }}"
  
  pagerduty_notification:
    name: Page On-Call Engineer
    condition: context.check_business_hours.result == false
    action: pagerduty.create_incident
    params:
      service: "{{ context.alert.service }}"
      title: "{{ context.alert.name }}"
      body: "{{ context.alert.description }}"
```

## AI-Enhanced Workflows

Keep's workflow system integrates with AI providers to enable intelligent automation:

### AI Enrichment

```yaml
name: AI Alert Analysis
description: Use AI to analyze and categorize alerts
triggers:
  - type: alert
steps:
  analyze_alert:
    name: Analyze Alert with AI
    action: openai.chat
    params:
      model: gpt-4
      messages:
        - role: system
          content: "You are an expert at analyzing system alerts. Categorize the alert, estimate severity, and suggest next steps."
        - role: user
          content: |
            Alert Name: {{ context.alert.name }}
            Description: {{ context.alert.description }}
            Source: {{ context.alert.source }}
            
  update_alert:
    name: Update Alert with AI Analysis
    depends_on: analyze_alert
    action: keep.update_alert
    params:
      alert_id: "{{ context.alert.id }}"
      additional_properties:
        ai_analysis: "{{ context.analyze_alert.result.choices[0].message.content }}"
```

### Automated Investigation

```yaml
name: Automated Investigation
description: Use AI to investigate incidents
triggers:
  - type: incident
    filters:
      severity: high
steps:
  gather_metrics:
    name: Gather Related Metrics
    action: prometheus.query_range
    params:
      query: 'sum(rate(http_requests_total{service="{{ context.incident.service }}",code=~"5.."}[5m]))'
      start: "{{ context.incident.created_date - 3600 }}"
      end: "{{ context.incident.created_date }}"
      step: 60
  
  analyze_metrics:
    name: Analyze Metrics with AI
    depends_on: gather_metrics
    action: anthropic.complete
    params:
      model: claude-3-sonnet
      max_tokens: 1000
      messages:
        - role: system
          content: "You are a system reliability expert. Analyze these metrics and suggest root causes."
        - role: user
          content: |
            Incident: {{ context.incident.title }}
            Description: {{ context.incident.description }}
            Metrics: {{ context.gather_metrics.result | tojson }}
  
  create_investigation_doc:
    name: Create Investigation Document
    depends_on: analyze_metrics
    action: notion.create_page
    params:
      parent_page_id: "{{ context.constants.NOTION_INCIDENTS_PAGE }}"
      title: "Investigation: {{ context.incident.title }}"
      content: |
        # Incident Investigation: {{ context.incident.title }}
        
        ## Incident Details
        - ID: {{ context.incident.id }}
        - Created: {{ context.incident.created_date }}
        - Severity: {{ context.incident.severity }}
        
        ## AI Analysis
        {{ context.analyze_metrics.result.content[0].text }}
```

## Workflow Permissions

Workflows can have different permission levels that determine what actions they can perform:

### Permission Levels

1. **Read-only**: Can only read data from the Keep platform
2. **Alert Management**: Can update and manage alerts
3. **Incident Management**: Can create and update incidents
4. **Provider Operations**: Can perform operations using external providers
5. **Administrative**: Can perform administrative actions

### Permission Configuration

```yaml
name: Critical Response Workflow
permissions:
  - alert:write
  - incident:write
  - provider:slack:write
  - provider:jira:write
# ...
```

## Conclusion

The Keep Workflow System provides a powerful and flexible way to automate incident response and alert management. By combining triggers, steps, actions, and conditions with the context system, users can create complex automation workflows that integrate with external services and leverage AI capabilities. 