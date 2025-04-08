# LangGraph Integration: Technical Implementation

This document provides technical details for implementing the LangGraph-based Agentic features in the Keep AIOps platform.

## Architecture Components

### 1. Agent Provider System

The Agent Provider is an extension of Keep's provider ecosystem that enables integration with LangGraph-based agents.

#### Implementation Details

```python
# Example Agent Provider implementation
from sqlmodel import Field, SQLModel
from typing import Dict, Any, Optional, List
from keep.providers.base import BaseProvider
from langchain_core.language_models import BaseChatModel
from langgraph.graph import StateGraph

class AgentProviderConfig(SQLModel, table=True):
    """Configuration for Agent Provider."""
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    description: Optional[str] = None
    llm_provider: str  # e.g., "openai", "anthropic", etc.
    llm_model: str  # e.g., "gpt-4", "claude-3-opus", etc.
    api_key_secret: str  # Reference to stored API key
    tools_config: Dict[str, Any] = Field(default={})
    system_prompt: str
    max_tokens: int = 4096
    temperature: float = 0.7

class AgentProvider(BaseProvider):
    """Provider for LangGraph-based agents."""
    
    config_model = AgentProviderConfig
    
    def __init__(self, config: AgentProviderConfig):
        super().__init__(config)
        self.llm = self._initialize_llm()
        self.tools = self._initialize_tools()
        self.graph = self._create_agent_graph()
        
    def _initialize_llm(self) -> BaseChatModel:
        """Initialize the LLM based on config."""
        # Implementation depends on specific LLM providers
        pass
        
    def _initialize_tools(self) -> List[Any]:
        """Initialize tools based on config."""
        # Register and initialize tools
        pass
        
    def _create_agent_graph(self) -> StateGraph:
        """Create the LangGraph state graph for this agent."""
        # Define the agent's workflow using LangGraph
        pass
        
    async def enrich_alert(self, alert_data: Dict[str, Any]) -> Dict[str, Any]:
        """Enrich alert with additional context."""
        # Run the agent to gather context about the alert
        pass
        
    async def analyze_incident(self, incident_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze an incident and provide insights."""
        # Run the agent to analyze the incident
        pass
        
    async def suggest_workflow(self, incident_data: Dict[str, Any]) -> Dict[str, Any]:
        """Suggest appropriate workflow for incident remediation."""
        # Run the agent to recommend workflows
        pass
```

### 2. Agent Memory Store

The Agent Memory Store provides persistent storage for agent observations, reasoning, and learning.

#### Implementation Details

```python
# Example Agent Memory Store implementation
from sqlmodel import Field, SQLModel, create_engine, Session
from typing import Dict, Any, Optional, List
from datetime import datetime

class AgentMemoryEntry(SQLModel, table=True):
    """Model for storing agent memory entries."""
    id: Optional[int] = Field(default=None, primary_key=True)
    agent_id: str = Field(index=True)
    incident_id: Optional[str] = Field(default=None, index=True)
    memory_type: str  # e.g., "observation", "reasoning", "decision"
    content: Dict[str, Any]
    metadata: Dict[str, Any] = Field(default={})
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class AgentMemoryStore:
    """Interface for agent memory operations."""
    
    def __init__(self, connection_string: str):
        self.engine = create_engine(connection_string)
        SQLModel.metadata.create_all(self.engine)
        
    async def store_memory(self, 
                          agent_id: str, 
                          memory_type: str,
                          content: Dict[str, Any],
                          incident_id: Optional[str] = None,
                          metadata: Optional[Dict[str, Any]] = None) -> AgentMemoryEntry:
        """Store a memory entry for an agent."""
        entry = AgentMemoryEntry(
            agent_id=agent_id,
            incident_id=incident_id,
            memory_type=memory_type,
            content=content,
            metadata=metadata or {}
        )
        
        with Session(self.engine) as session:
            session.add(entry)
            session.commit()
            session.refresh(entry)
            return entry
            
    async def retrieve_memories(self,
                              agent_id: str,
                              memory_type: Optional[str] = None,
                              incident_id: Optional[str] = None,
                              limit: int = 10) -> List[AgentMemoryEntry]:
        """Retrieve memories for an agent."""
        with Session(self.engine) as session:
            query = session.query(AgentMemoryEntry).filter(AgentMemoryEntry.agent_id == agent_id)
            
            if memory_type:
                query = query.filter(AgentMemoryEntry.memory_type == memory_type)
                
            if incident_id:
                query = query.filter(AgentMemoryEntry.incident_id == incident_id)
                
            return query.order_by(AgentMemoryEntry.timestamp.desc()).limit(limit).all()
```

### 3. Tool Registry

The Tool Registry exposes Keep's existing provider actions as tools for LangGraph agents.

#### Implementation Details

```python
# Example Tool Registry implementation
from typing import Dict, Any, List, Callable, Optional
from pydantic import BaseModel, Field

class ToolDefinition(BaseModel):
    """Definition of a tool that can be used by agents."""
    name: str
    description: str
    parameters_schema: Dict[str, Any]
    return_schema: Dict[str, Any]
    function: Callable
    required_permissions: List[str] = Field(default_factory=list)
    provider_id: Optional[str] = None

class ToolRegistry:
    """Registry for tools that can be used by agents."""
    
    def __init__(self):
        self.tools: Dict[str, ToolDefinition] = {}
        
    def register_tool(self, tool: ToolDefinition) -> None:
        """Register a tool in the registry."""
        self.tools[tool.name] = tool
        
    def register_provider_action(self, provider_id: str, action_name: str, 
                                description: str, permissions: List[str]) -> None:
        """Register a provider action as a tool."""
        # Introspect provider action and create tool definition
        pass
        
    def get_tool(self, name: str) -> Optional[ToolDefinition]:
        """Get a tool by name."""
        return self.tools.get(name)
        
    def list_tools(self, required_permissions: Optional[List[str]] = None) -> List[ToolDefinition]:
        """List all tools, optionally filtered by required permissions."""
        if not required_permissions:
            return list(self.tools.values())
            
        return [tool for tool in self.tools.values() 
                if all(perm in required_permissions for perm in tool.required_permissions)]
                
    def get_tools_for_agent(self, agent_permissions: List[str]) -> List[Dict[str, Any]]:
        """Get tools formatted for agent consumption based on permissions."""
        tools = self.list_tools(agent_permissions)
        
        # Format tools for agent (e.g., in OpenAI tool format)
        formatted_tools = []
        for tool in tools:
            formatted_tools.append({
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": {
                        "type": "object",
                        "properties": tool.parameters_schema,
                        "required": [k for k, v in tool.parameters_schema.items() 
                                    if v.get("required", False)]
                    }
                }
            })
            
        return formatted_tools
```

### 4. Agent Workflow Engine

The Agent Workflow Engine uses LangGraph to orchestrate agent execution flows.

#### Implementation Details

```python
# Example LangGraph Workflow implementation
from typing import Dict, Any, List, TypedDict, Annotated, Literal
from langgraph.graph import StateGraph
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_core.language_models import BaseChatModel

# Define the state for our agent
class AgentState(TypedDict):
    messages: List[Any]  # List of messages in the conversation
    context: Dict[str, Any]  # Context information
    tools: List[Dict[str, Any]]  # Available tools
    tool_results: Dict[str, Any]  # Results from tool invocations
    next_steps: List[str]  # Potential next steps to take
    reasoning: List[str]  # Internal reasoning trace
    status: Literal["running", "complete", "failed"]  # Status of execution

def create_agent_workflow(
    llm: BaseChatModel,
    system_prompt: str,
    tools: List[Dict[str, Any]]
) -> StateGraph:
    """Create an agent workflow using LangGraph."""
    
    # Define the nodes for our graph
    def analyze_and_plan(state: AgentState) -> AgentState:
        """Analyze the situation and plan next steps."""
        # Implementation using the LLM to analyze and plan
        messages = state["messages"]
        context = state["context"]
        tools = state["tools"]
        
        # LLM call to analyze situation and decide on next steps
        pass
        
    def execute_tool(state: AgentState) -> AgentState:
        """Execute a selected tool."""
        # Implementation to execute a tool based on agent decision
        pass
        
    def evaluate_progress(state: AgentState) -> Literal["continue", "complete"]:
        """Evaluate progress and decide whether to continue or complete."""
        # Implementation to determine if more steps are needed
        pass
    
    # Build the graph
    graph = StateGraph(AgentState)
    
    # Add nodes
    graph.add_node("analyze_and_plan", analyze_and_plan)
    graph.add_node("execute_tool", execute_tool)
    
    # Add edges
    graph.add_edge("analyze_and_plan", "execute_tool")
    graph.add_conditional_edges(
        "execute_tool",
        evaluate_progress,
        {
            "continue": "analyze_and_plan",
            "complete": "END"
        }
    )
    
    # Set entry point
    graph.set_entry_point("analyze_and_plan")
    
    return graph
```

### 5. Human Feedback Mechanism

The Human Feedback Mechanism allows operators to provide feedback on agent suggestions.

#### Implementation Details

```python
# Example Human Feedback implementation
from sqlmodel import Field, SQLModel, Session
from typing import Dict, Any, Optional, List
from datetime import datetime
from enum import Enum

class FeedbackType(str, Enum):
    ACCEPT = "accept"
    REJECT = "reject"
    MODIFY = "modify"
    COMMENT = "comment"

class AgentFeedback(SQLModel, table=True):
    """Model for storing feedback on agent actions."""
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    agent_id: str = Field(index=True)
    incident_id: Optional[str] = Field(default=None, index=True)
    action_id: str = Field(index=True)  # ID of the specific agent action
    feedback_type: FeedbackType
    content: str
    modified_action: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class HumanFeedbackService:
    """Service for managing human feedback on agent actions."""
    
    def __init__(self, session: Session):
        self.session = session
        
    async def store_feedback(self, 
                           user_id: str,
                           agent_id: str,
                           action_id: str,
                           feedback_type: FeedbackType,
                           content: str,
                           incident_id: Optional[str] = None,
                           modified_action: Optional[Dict[str, Any]] = None) -> AgentFeedback:
        """Store feedback for an agent action."""
        feedback = AgentFeedback(
            user_id=user_id,
            agent_id=agent_id,
            incident_id=incident_id,
            action_id=action_id,
            feedback_type=feedback_type,
            content=content,
            modified_action=modified_action
        )
        
        self.session.add(feedback)
        self.session.commit()
        self.session.refresh(feedback)
        return feedback
        
    async def get_feedback_for_agent(self, 
                                   agent_id: str,
                                   limit: int = 100) -> List[AgentFeedback]:
        """Get feedback for a specific agent."""
        return self.session.query(AgentFeedback)\
                .filter(AgentFeedback.agent_id == agent_id)\
                .order_by(AgentFeedback.timestamp.desc())\
                .limit(limit)\
                .all()
                
    async def get_feedback_summary(self, 
                                 agent_id: str) -> Dict[str, Any]:
        """Get a summary of feedback for an agent."""
        feedbacks = self.session.query(AgentFeedback)\
                   .filter(AgentFeedback.agent_id == agent_id)\
                   .all()
                   
        total = len(feedbacks)
        by_type = {}
        for feedback_type in FeedbackType:
            count = sum(1 for f in feedbacks if f.feedback_type == feedback_type)
            by_type[feedback_type.value] = {
                "count": count,
                "percentage": (count / total * 100) if total > 0 else 0
            }
            
        return {
            "total": total,
            "by_type": by_type
        }
```

## Integration with Keep Core

### Workflow Integration

The following example shows how to integrate agent capabilities into the existing workflow system:

```python
# Example workflow definition with agent integration
from typing import Dict, Any

async def enrich_alert_with_agent(alert: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
    """Workflow step that uses an agent to enrich an alert."""
    agent_provider = context.get_provider("agent")
    enriched_data = await agent_provider.enrich_alert(alert)
    
    # Merge enriched data into the alert
    alert["enriched_context"] = enriched_data
    
    return alert

async def agent_suggested_workflow(incident: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
    """Action that suggests workflows for an incident."""
    agent_provider = context.get_provider("agent")
    suggestions = await agent_provider.suggest_workflow(incident)
    
    # Store suggestions in the context
    context["workflow_suggestions"] = suggestions
    
    return {
        "incident_id": incident["id"],
        "suggested_workflows": suggestions["workflows"],
        "reasoning": suggestions["reasoning"]
    }

# Example workflow that incorporates agent steps
workflow_definition = {
    "name": "Agent-Enhanced Incident Response",
    "description": "Incident response workflow with agent enrichment and analysis",
    "triggers": [
        {
            "type": "alert",
            "provider": "sentry",
            "conditions": [
                {"field": "severity", "operator": "equals", "value": "critical"}
            ]
        }
    ],
    "steps": [
        {
            "id": "enrich_alert",
            "name": "Enrich Alert with Agent",
            "action": "enrich_alert_with_agent",
            "provider": "system"
        },
        {
            "id": "analyze_incident",
            "name": "Analyze Incident",
            "action": "agent_analyze_incident",
            "provider": "agent"
        }
    ],
    "actions": [
        {
            "id": "suggest_workflows",
            "name": "Suggest Appropriate Workflows",
            "action": "agent_suggested_workflow",
            "provider": "system",
            "conditions": [
                {"field": "steps.analyze_incident.risk_level", "operator": "greater_than", "value": 7}
            ]
        },
        {
            "id": "notify_slack",
            "name": "Notify Slack Channel",
            "action": "send_message",
            "provider": "slack",
            "inputs": {
                "channel": "#incidents",
                "message": "Critical incident detected: {{alert.title}}. Agent analysis: {{steps.analyze_incident.summary}}"
            }
        }
    ]
}
```

## API Extensions

The following API endpoints will be added to support the agent functionality:

```python
# Example FastAPI routes for agent functionality
from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List
from pydantic import BaseModel

router = APIRouter(prefix="/api/agents", tags=["agents"])

class AgentRequest(BaseModel):
    """Request model for agent operations."""
    agent_id: str
    input_data: Dict[str, Any]
    context: Dict[str, Any] = {}

class AgentResponse(BaseModel):
    """Response model for agent operations."""
    agent_id: str
    result: Dict[str, Any]
    reasoning: List[str]
    execution_time: float

@router.post("/run", response_model=AgentResponse)
async def run_agent(request: AgentRequest):
    """Run an agent with the provided input."""
    # Implementation to run the agent
    pass

@router.post("/feedback", response_model=Dict[str, Any])
async def submit_feedback(feedback: AgentFeedback):
    """Submit feedback for an agent action."""
    # Implementation to store feedback
    pass

@router.get("/suggestions/{incident_id}", response_model=List[Dict[str, Any]])
async def get_workflow_suggestions(incident_id: str):
    """Get workflow suggestions for an incident."""
    # Implementation to retrieve suggestions
    pass
```

## Configuration Extensions

The following configuration options will be added to support agent functionality:

```yaml
# Example configuration extensions
keep:
  # Existing configuration...
  
  agents:
    enabled: true
    default_llm_provider: "openai"
    default_llm_model: "gpt-4"
    max_tokens_per_request: 4096
    request_timeout: 60
    memory:
      enabled: true
      storage: "database"  # Options: "database", "redis", "file"
    tools:
      max_per_agent: 20
      default_timeout: 30
    feedback:
      required_for_actions: ["create_ticket", "restart_service", "update_config"]
```

## UI Extensions

The following UI components will be added to support agent functionality:

1. Agent Dashboard
2. Agent Configuration UI
3. Agent Feedback Interface
4. Agent Reasoning Viewer
5. Workflow Suggestion Interface

## Testing Approach

The agent functionality will be tested using the following methods:

1. **Unit Testing**: Individual components (Tool Registry, Memory Store)
2. **Integration Testing**: Agent Provider integration with Keep
3. **Scenario Testing**: End-to-end scenarios with mock LLM responses
4. **Evaluation Framework**: Automated evaluation of agent performance
5. **Synthetic Incidents**: Generated test cases for agent handling

## Deployment Considerations

The agent functionality introduces dependencies on external LLM services, which requires additional deployment considerations:

1. **API Key Management**: Secure storage and rotation of LLM API keys
2. **Network Requirements**: Ensure outbound connectivity to LLM APIs
3. **Rate Limiting**: Implement rate limiting to manage API usage
4. **Fallback Mechanisms**: Define fallback procedures when LLM services are unavailable
5. **Monitoring**: Add monitoring for LLM service availability and response times

## Conclusion

This implementation plan provides a technical foundation for integrating LangGraph-based agents into the Keep AIOps platform. The approach leverages Keep's existing architecture while introducing new components that enable intelligent, adaptive agent behaviors for enhancing incident management capabilities. 