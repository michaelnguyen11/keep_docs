# Tool Registry Implementation

This document details the implementation of the Tool Registry component for the Keep AIOps platform's agentic capabilities.

## Overview

The Tool Registry is a central system that manages, registers, and provides tools for LangGraph-based agents. It enables agents to interact with Keep's existing systems and external services in a controlled and secure manner.

## Key Components

### 1. Base Tool Interfaces

```python
# keep/providers/agent/tools/base.py
from typing import Dict, Any, List, Optional, Callable, Type, Union
from pydantic import BaseModel, Field
import inspect
from abc import ABC, abstractmethod
import asyncio
from enum import Enum

class ToolCategory(str, Enum):
    """Categories for agent tools."""
    READ = "read"       # Tools that only read data (safe)
    WRITE = "write"     # Tools that modify data (potentially destructive)
    EXECUTE = "execute" # Tools that execute actions (potentially dangerous)
    INTERNAL = "internal" # Tools used internally by the agent

class BaseTool(ABC):
    """Base class for all agent tools."""
    
    name: str
    description: str
    category: ToolCategory
    
    @abstractmethod
    async def _run(self, **kwargs) -> Any:
        """Execute the tool functionality."""
        pass
    
    @property
    def input_schema(self) -> Type[BaseModel]:
        """Get the input schema for the tool."""
        return getattr(self, "_input_schema", None)
    
    @property
    def output_schema(self) -> Type[BaseModel]:
        """Get the output schema for the tool."""
        return getattr(self, "_output_schema", None)
    
    async def run(self, **kwargs) -> Any:
        """Run the tool with validation."""
        # Validate input if schema exists
        if self.input_schema:
            validated_input = self.input_schema(**kwargs)
            kwargs = validated_input.dict()
        
        # Execute the tool
        result = await self._run(**kwargs)
        
        # Validate output if schema exists
        if self.output_schema and result is not None:
            if isinstance(result, dict):
                result = self.output_schema(**result)
            else:
                raise ValueError(f"Tool output must be a dict when using output_schema, got {type(result)}")
        
        return result
    
    def to_langchain_tool(self) -> Dict[str, Any]:
        """Convert to LangChain tool format."""
        schema_properties = {}
        required = []
        
        if self.input_schema:
            for name, field in self.input_schema.__fields__.items():
                schema_properties[name] = {
                    "type": self._get_json_schema_type(field.type_),
                    "description": field.field_info.description or ""
                }
                if field.required:
                    required.append(name)
        
        return {
            "name": self.name,
            "description": self.description,
            "schema": {
                "type": "object",
                "properties": schema_properties,
                "required": required
            }
        }
    
    def _get_json_schema_type(self, type_):
        """Convert Python type to JSON schema type."""
        type_map = {
            str: "string",
            int: "integer",
            float: "number",
            bool: "boolean",
            list: "array",
            dict: "object"
        }
        
        return type_map.get(type_, "string")
```

### 2. Tool Registry Implementation

```python
# keep/providers/agent/tools/registry.py
from typing import Dict, List, Any, Optional, Type
from keep.providers.agent.tools.base import BaseTool, ToolCategory
import importlib
import inspect
import pkgutil
import logging

logger = logging.getLogger(__name__)

class ToolRegistry:
    """Registry for agent tools."""
    
    def __init__(self):
        self._tools: Dict[str, BaseTool] = {}
        self._tool_classes: Dict[str, Type[BaseTool]] = {}
        
    def register_tool(self, tool: BaseTool) -> None:
        """Register a tool instance."""
        if tool.name in self._tools:
            logger.warning(f"Tool {tool.name} already registered, overwriting")
        
        self._tools[tool.name] = tool
        
    def register_tool_class(self, tool_class: Type[BaseTool]) -> None:
        """Register a tool class."""
        # Get name from a temporary instance or class attribute
        try:
            name = tool_class.name
        except:
            # Create an instance to get the name
            try:
                instance = tool_class()
                name = instance.name
            except:
                raise ValueError(f"Cannot determine name for tool class {tool_class}")
        
        if name in self._tool_classes:
            logger.warning(f"Tool class {name} already registered, overwriting")
        
        self._tool_classes[name] = tool_class
    
    def get_tool(self, name: str) -> Optional[BaseTool]:
        """Get a registered tool by name."""
        # Check if tool instance exists
        if name in self._tools:
            return self._tools[name]
        
        # Try to instantiate from class if available
        if name in self._tool_classes:
            tool = self._tool_classes[name]()
            self._tools[name] = tool
            return tool
        
        return None
    
    def get_tools_for_agent(self, categories: List[ToolCategory]) -> List[Dict[str, Any]]:
        """Get tools matching the specified categories in LangChain format."""
        tools = []
        
        for tool in self._tools.values():
            if tool.category in categories:
                tools.append(tool.to_langchain_tool())
        
        return tools
    
    def list_available_tools(self) -> Dict[ToolCategory, List[str]]:
        """List all available tools grouped by category."""
        result = {category: [] for category in ToolCategory}
        
        for name, tool in self._tools.items():
            result[tool.category].append(name)
            
        for name, tool_class in self._tool_classes.items():
            if name not in self._tools:
                try:
                    # Create temporary instance to get category
                    temp_tool = tool_class()
                    result[temp_tool.category].append(name)
                except Exception as e:
                    logger.error(f"Error instantiating tool class {name}: {str(e)}")
        
        return result
    
    def discover_tools(self, package_name: str = "keep.providers.agent.tools") -> None:
        """Discover and register tools from the specified package."""
        package = importlib.import_module(package_name)
        
        for _, name, is_pkg in pkgutil.iter_modules(package.__path__, package.__name__ + "."):
            if is_pkg:
                # Recursively discover tools in subpackages
                self.discover_tools(name)
            else:
                try:
                    module = importlib.import_module(name)
                    
                    for item_name in dir(module):
                        item = getattr(module, item_name)
                        
                        # Check if it's a class that inherits from BaseTool
                        if (inspect.isclass(item) and 
                            item.__module__ == module.__name__ and
                            issubclass(item, BaseTool) and 
                            item != BaseTool):
                            
                            try:
                                self.register_tool_class(item)
                                logger.info(f"Discovered tool: {item_name}")
                            except Exception as e:
                                logger.error(f"Error registering tool {item_name}: {str(e)}")
                                
                except Exception as e:
                    logger.error(f"Error loading module {name}: {str(e)}")
```

### 3. Tool Implementations

#### System Tools

```python
# keep/providers/agent/tools/system.py
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field
from keep.providers.agent.tools.base import BaseTool, ToolCategory
import time

class GetCurrentTimeInput(BaseModel):
    timezone: Optional[str] = Field(
        default="UTC", 
        description="Timezone to return the time in"
    )

class GetCurrentTimeOutput(BaseModel):
    time: str = Field(description="The current time")
    timezone: str = Field(description="The timezone of the time")
    unix_timestamp: int = Field(description="Unix timestamp")

class GetCurrentTimeTool(BaseTool):
    """Tool for getting the current time."""
    
    name = "get_current_time"
    description = "Get the current system time in the specified timezone"
    category = ToolCategory.READ
    
    _input_schema = GetCurrentTimeInput
    _output_schema = GetCurrentTimeOutput
    
    async def _run(self, timezone: str = "UTC") -> Dict[str, Any]:
        """Get the current time."""
        # In a real implementation, we would use proper timezone handling
        # For simplicity, we're just returning UTC time here
        current_time = time.time()
        formatted_time = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(current_time))
        
        return {
            "time": formatted_time,
            "timezone": timezone,
            "unix_timestamp": int(current_time)
        }
```

#### Keep-Specific Tools

```python
# keep/providers/agent/tools/incidents.py
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field
from keep.providers.agent.tools.base import BaseTool, ToolCategory
from keep.api.models.incident import Incident
from sqlmodel import Session, select
import json

class GetIncidentInput(BaseModel):
    incident_id: str = Field(description="ID of the incident to retrieve")

class GetIncidentOutput(BaseModel):
    id: str = Field(description="Incident ID")
    title: str = Field(description="Incident title")
    description: Optional[str] = Field(description="Incident description")
    severity: str = Field(description="Incident severity")
    status: str = Field(description="Incident status")
    created_at: str = Field(description="Incident creation time")
    updated_at: str = Field(description="Incident last update time")
    alerts: List[Dict[str, Any]] = Field(description="Related alerts")
    assignee: Optional[str] = Field(description="Assigned user if any")

class GetIncidentTool(BaseTool):
    """Tool for retrieving incident details."""
    
    name = "get_incident"
    description = "Get details about a specific incident by its ID"
    category = ToolCategory.READ
    
    _input_schema = GetIncidentInput
    _output_schema = GetIncidentOutput
    
    def __init__(self, session: Session):
        self.session = session
    
    async def _run(self, incident_id: str) -> Dict[str, Any]:
        """Get incident details."""
        statement = select(Incident).where(Incident.id == incident_id)
        incident = self.session.exec(statement).first()
        
        if not incident:
            raise ValueError(f"Incident with ID {incident_id} not found")
        
        # Convert to dictionary with related alerts
        incident_dict = incident.dict()
        incident_dict["alerts"] = [alert.dict() for alert in incident.alerts]
        
        # Format timestamps
        incident_dict["created_at"] = incident.created_at.isoformat()
        incident_dict["updated_at"] = incident.updated_at.isoformat()
        
        return incident_dict
```

#### External Integration Tools

```python
# keep/providers/agent/tools/kubernetes.py
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field
from keep.providers.agent.tools.base import BaseTool, ToolCategory
from keep.providers.kubernetes.client import KubernetesClient
import json

class GetPodStatusInput(BaseModel):
    namespace: str = Field(description="Kubernetes namespace")
    pod_name: str = Field(description="Name of the pod to check")
    
class GetPodStatusOutput(BaseModel):
    pod_name: str = Field(description="Pod name")
    namespace: str = Field(description="Namespace")
    status: str = Field(description="Pod status")
    containers: List[Dict[str, Any]] = Field(description="Container statuses")
    start_time: Optional[str] = Field(description="Pod start time")
    host_ip: Optional[str] = Field(description="Host IP address")
    pod_ip: Optional[str] = Field(description="Pod IP address")

class GetPodStatusTool(BaseTool):
    """Tool for checking Kubernetes pod status."""
    
    name = "get_pod_status"
    description = "Get the status of a Kubernetes pod"
    category = ToolCategory.READ
    
    _input_schema = GetPodStatusInput
    _output_schema = GetPodStatusOutput
    
    def __init__(self, kubernetes_client: KubernetesClient):
        self.kubernetes_client = kubernetes_client
    
    async def _run(self, namespace: str, pod_name: str) -> Dict[str, Any]:
        """Get pod status."""
        pod = await self.kubernetes_client.get_pod(namespace, pod_name)
        
        if not pod:
            raise ValueError(f"Pod {pod_name} in namespace {namespace} not found")
        
        # Extract relevant information
        status = pod.status.phase
        containers = []
        
        for container_status in pod.status.container_statuses:
            container_info = {
                "name": container_status.name,
                "ready": container_status.ready,
                "restarts": container_status.restart_count,
                "state": list(container_status.state.to_dict().keys())[0]
            }
            containers.append(container_info)
        
        return {
            "pod_name": pod_name,
            "namespace": namespace,
            "status": status,
            "containers": containers,
            "start_time": pod.status.start_time.isoformat() if pod.status.start_time else None,
            "host_ip": pod.status.host_ip,
            "pod_ip": pod.status.pod_ip
        }
```

## Integration with Agent Provider

The Tool Registry is integrated into the Agent Provider to give agents access to tools:

```python
# keep/providers/agent/provider.py (updated section)
from keep.providers.agent.tools.registry import ToolRegistry
from keep.providers.agent.tools.system import GetCurrentTimeTool
from keep.providers.agent.tools.incidents import GetIncidentTool
from keep.providers.kubernetes.client import KubernetesClient
from keep.providers.agent.tools.kubernetes import GetPodStatusTool

class AgentProvider(BaseProvider):
    # ... existing code ...
    
    def __init__(self, config: AgentProviderConfig, session: Session):
        super().__init__(config)
        self.session = session
        self.config = config
        self.llm = initialize_llm(config.dict())
        
        # Initialize tool registry
        self.tool_registry = ToolRegistry()
        
        # Register system tools
        self.tool_registry.register_tool(GetCurrentTimeTool())
        
        # Register Keep-specific tools
        self.tool_registry.register_tool(GetIncidentTool(session))
        
        # Register external tools if configured
        if "kubernetes" in config.tools_config:
            k8s_config = config.tools_config["kubernetes"]
            k8s_client = KubernetesClient(
                api_url=k8s_config.get("api_url"),
                token=get_secret(k8s_config.get("token_secret")),
                ca_cert=k8s_config.get("ca_cert")
            )
            self.tool_registry.register_tool(GetPodStatusTool(k8s_client))
        
        # Discover additional tools
        if config.tools_config.get("auto_discover", False):
            self.tool_registry.discover_tools()
        
        # Complete the initialization
        self.memory_store = AgentMemoryStore(session)
        self.graph = self._create_agent_graph()
```

## Next Steps

After implementing the Tool Registry, proceed to:

1. Implement the [Agent Workflow Engine](./agent-workflow.md) for more complex agent reasoning patterns
2. Add [Memory System Integration](./memory-system.md) for persistent agent knowledge
3. Define additional tools specific to the Keep platform and use cases 