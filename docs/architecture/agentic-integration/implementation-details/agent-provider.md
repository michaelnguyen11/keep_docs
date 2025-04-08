# Agent Provider Implementation

This document details the implementation of the Agent Provider component for the Keep AIOps platform.

## Overview

The Agent Provider component serves as the bridge between Keep's provider ecosystem and LangGraph-based agent capabilities. It extends Keep's `BaseProvider` class and implements the necessary interfaces to integrate with the platform.

## Key Components

### 1. Agent Provider Configuration

```python
# keep/api/models/agent.py
from sqlmodel import Field, SQLModel
from typing import Dict, Any, Optional, List
from pydantic import validator

class AgentProviderConfig(SQLModel, table=True):
    """Configuration for Agent Provider."""
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    description: Optional[str] = None
    llm_provider: str  # e.g., "openai", "anthropic", etc.
    llm_model: str  # e.g., "gpt-4", "claude-3-opus", etc.
    api_key_secret: str  # Reference to stored API key
    system_prompt: str
    tools_config: Dict[str, Any] = Field(default={})
    max_tokens: int = 4096
    temperature: float = 0.7
    
    @validator("llm_provider")
    def validate_llm_provider(cls, v):
        valid_providers = ["openai", "anthropic", "local"]
        if v not in valid_providers:
            raise ValueError(f"LLM provider must be one of {valid_providers}")
        return v
```

### 2. LLM Initialization

```python
# keep/providers/agent/llm.py
from typing import Dict, Any
from langchain_core.language_models import BaseChatModel
from langchain_openai import ChatOpenAI
from keep.core.secrets import get_secret

def initialize_llm(config: Dict[str, Any]) -> BaseChatModel:
    """Initialize LLM based on configuration."""
    llm_provider = config["llm_provider"]
    llm_model = config["llm_model"]
    
    # Get API key from secrets
    api_key = get_secret(config["api_key_secret"])
    
    if llm_provider == "openai":
        return ChatOpenAI(
            model=llm_model,
            api_key=api_key,
            temperature=config.get("temperature", 0.7),
            max_tokens=config.get("max_tokens", 4096),
        )
    elif llm_provider == "anthropic":
        # Import here to avoid unnecessary dependencies
        from langchain_anthropic import ChatAnthropic
        
        return ChatAnthropic(
            model=llm_model,
            api_key=api_key,
            temperature=config.get("temperature", 0.7),
            max_tokens=config.get("max_tokens", 4096),
        )
    elif llm_provider == "local":
        # Import here to avoid unnecessary dependencies
        from langchain_community.llms import LlamaCpp
        
        return LlamaCpp(
            model_path=config.get("model_path", "/path/to/model.gguf"),
            temperature=config.get("temperature", 0.7),
            max_tokens=config.get("max_tokens", 4096),
            n_ctx=config.get("context_window", 8192),
        )
    else:
        raise ValueError(f"Unsupported LLM provider: {llm_provider}")
```

### 3. Agent Provider Implementation

```python
# keep/providers/agent/provider.py
from sqlmodel import Field, SQLModel, Session
from typing import Dict, Any, Optional, List
from keep.providers.base import BaseProvider
from langchain_core.language_models import BaseChatModel
from langgraph.graph import StateGraph
from keep.api.models.agent import AgentProviderConfig
from keep.providers.agent.llm import initialize_llm
from keep.providers.agent.tools import ToolRegistry
from keep.providers.agent.graph import create_agent_graph
from keep.providers.agent.memory import AgentMemoryStore
import time

class AgentProvider(BaseProvider):
    """LangGraph-based agent provider for Keep."""
    
    config_model = AgentProviderConfig
    
    def __init__(self, config: AgentProviderConfig, session: Session):
        super().__init__(config)
        self.session = session
        self.config = config
        self.llm = initialize_llm(config.dict())
        self.tool_registry = ToolRegistry()
        self.memory_store = AgentMemoryStore(session)
        self.graph = self._create_agent_graph()
        
    def _create_agent_graph(self) -> StateGraph:
        """Create the LangGraph state graph for this agent."""
        system_prompt = self.config.system_prompt
        tools = self.tool_registry.get_tools_for_agent(["read"]) # Start with read-only tools
        
        return create_agent_graph(
            llm=self.llm,
            system_prompt=system_prompt,
            tools=tools
        )
        
    async def enrich_alert(self, alert_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Enrich an alert with additional context."""
        start_time = time.time()
        context = context or {}
        
        # Retrieve related memories
        related_memories = await self.memory_store.retrieve_memories(
            agent_id=self.config.name,
            memory_type="alert_observation",
            limit=5
        )
        
        # Extract memory content
        memory_content = [memory.get_content() for memory in related_memories]
        
        # Create initial state
        state = {
            "messages": [
                {"role": "user", "content": f"Enrich this alert with additional context: {alert_data}"}
            ],
            "context": {
                "alert": alert_data,
                "context": context,
                "memories": memory_content
            },
            "tools": self.tool_registry.get_tools_for_agent(["read"]),
            "tool_results": {},
            "reasoning": [],
            "status": "running",
            "start_time": start_time
        }
        
        # Run the agent graph
        final_state = await self.graph.arun(state)
        
        # Store observations
        await self.memory_store.store_memory(
            agent_id=self.config.name,
            memory_type="alert_observation",
            content={
                "alert": alert_data,
                "enrichment": final_state.get("enriched_data", {}),
                "reasoning": final_state.get("reasoning", [])
            }
        )
        
        # Return results
        return {
            "enriched_data": final_state.get("enriched_data", {}),
            "reasoning": final_state.get("reasoning", []),
            "execution_time": time.time() - start_time,
        }
        
    async def analyze_incident(self, incident_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Analyze an incident and provide insights."""
        start_time = time.time()
        context = context or {}
        
        # Create initial state
        state = {
            "messages": [
                {"role": "user", "content": f"Analyze this incident and provide insights: {incident_data}"}
            ],
            "context": {
                "incident": incident_data,
                "context": context
            },
            "tools": self.tool_registry.get_tools_for_agent(["read"]),
            "tool_results": {},
            "reasoning": [],
            "status": "running",
            "start_time": start_time
        }
        
        # Run the agent graph
        final_state = await self.graph.arun(state)
        
        # Store analysis
        await self.memory_store.store_memory(
            agent_id=self.config.name,
            memory_type="incident_analysis",
            content={
                "incident": incident_data,
                "analysis": {
                    "classification": final_state.get("classification", "unknown"),
                    "severity": final_state.get("severity", "unknown"),
                    "affected_systems": final_state.get("affected_systems", []),
                    "summary": final_state.get("summary", "")
                },
                "reasoning": final_state.get("reasoning", [])
            },
            incident_id=incident_data.get("id")
        )
        
        # Return analysis
        return {
            "classification": final_state.get("classification", "unknown"),
            "severity": final_state.get("severity", "unknown"),
            "affected_systems": final_state.get("affected_systems", []),
            "summary": final_state.get("summary", ""),
            "reasoning": final_state.get("reasoning", []),
            "execution_time": time.time() - start_time
        }
        
    async def suggest_workflow(self, incident_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Suggest appropriate workflow for incident remediation."""
        start_time = time.time()
        context = context or {}
        
        # Create initial state
        state = {
            "messages": [
                {"role": "user", "content": f"Suggest appropriate workflows for this incident: {incident_data}"}
            ],
            "context": {
                "incident": incident_data,
                "context": context,
                "available_workflows": context.get("available_workflows", [])
            },
            "tools": self.tool_registry.get_tools_for_agent(["read"]),
            "tool_results": {},
            "reasoning": [],
            "status": "running",
            "start_time": start_time
        }
        
        # Run the agent graph
        final_state = await self.graph.arun(state)
        
        # Return suggestions
        return {
            "workflows": final_state.get("suggested_workflows", []),
            "reasoning": final_state.get("reasoning", []),
            "execution_time": time.time() - start_time
        }
```

## Integration with Keep

The Agent Provider integrates with Keep through the provider registry system:

```python
# keep/api/routes/providers.py (addition to existing file)
from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any
from sqlmodel import Session
from keep.api.deps import get_db, get_current_user
from keep.api.models.agent import AgentProviderConfig
from keep.providers.registry import register_provider
from keep.providers.agent.provider import AgentProvider

@router.post("/agent", response_model=Dict[str, Any])
async def create_agent_provider(
    config: AgentProviderConfig,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Create a new agent provider."""
    try:
        # Add provider to database
        db.add(config)
        db.commit()
        db.refresh(config)
        
        # Create provider instance
        provider = AgentProvider(config, db)
        
        # Register provider in registry
        register_provider(provider, db)
        
        return {"id": config.id, "name": config.name, "status": "created"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
```

## Next Steps

After implementing the Agent Provider, proceed to:

1. Implement the [Tool Registry](./tool-registry.md) to enable tool usage by agents
2. Create the [Agent Workflow Engine](./agent-workflow.md) for more complex agent reasoning patterns
3. Implement the [Memory System](./memory-system.md) for persistent knowledge 