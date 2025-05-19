defmodule Automata.Infrastructure.Event.EventManager do
  @moduledoc """
  Manages the lifecycle of event handlers in the system.
  
  The Event Manager is responsible for:
  - Starting and supervising event handlers
  - Routing events to appropriate handlers
  - Monitoring handler health
  - Restarting failed handlers
  """
  
  use Supervisor
  require Logger
  
  # Client API
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @doc """
  Registers a new event handler to be supervised.
  
  Options:
  - id: unique identifier for the handler (default: module name)
  - args: arguments to pass to the handler's init function
  - restart: restart strategy (default: :permanent)
  """
  def register_handler(module, opts \\ []) do
    id = Keyword.get(opts, :id, module)
    args = Keyword.get(opts, :args, [])
    restart = Keyword.get(opts, :restart, :permanent)
    
    child_spec = %{
      id: id,
      start: {module, :start_link, [args]},
      restart: restart,
      shutdown: 5000,
      type: :worker
    }
    
    Supervisor.start_child(__MODULE__, child_spec)
  end
  
  @doc """
  Unregisters an event handler.
  """
  def unregister_handler(id) do
    Supervisor.terminate_child(__MODULE__, id)
    Supervisor.delete_child(__MODULE__, id)
  end
  
  @doc """
  Lists all registered event handlers.
  """
  def list_handlers do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {id, pid, type, modules} ->
      %{
        id: id,
        pid: pid,
        type: type,
        modules: modules,
        status: if(is_pid(pid), do: :running, else: :stopped)
      }
    end)
  end
  
  # Supervisor callbacks
  
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Event Manager")
    
    children = [
      # Event Bus
      Automata.Infrastructure.Event.EventBus,
      
      # Built-in handlers
      {Automata.Infrastructure.Event.SystemEventHandler, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Automata.Infrastructure.Event.SystemEventHandler do
  @moduledoc """
  A built-in event handler for system events.
  
  This handler processes events related to system operation, such as
  node joins/leaves, configuration changes, etc.
  """
  
  use Automata.Infrastructure.Event.EventHandler,
    events: [
      :system_started,
      :system_stopping,
      :node_joined,
      :node_left,
      :config_changed
    ]
  
  require Logger
  
  @impl true
  def init(_args) do
    {:ok, %{
      started_at: System.system_time(:millisecond),
      nodes: [Node.self() | Node.list()],
      event_counts: %{}
    }}
  end
  
  @impl true
  def handle_event(event, state) do
    Logger.info("System event: #{inspect(event.type)}")
    
    # Update event counts
    counts = Map.update(state.event_counts, event.type, 1, &(&1 + 1))
    
    # Handle specific events
    new_state = case event.type do
      :node_joined ->
        node = event.payload.node
        nodes = [node | state.nodes] |> Enum.uniq()
        %{state | nodes: nodes, event_counts: counts}
        
      :node_left ->
        node = event.payload.node
        nodes = state.nodes -- [node]
        %{state | nodes: nodes, event_counts: counts}
        
      :config_changed ->
        # Log configuration changes
        Logger.info("Configuration changed: #{inspect(event.payload.changes)}")
        %{state | event_counts: counts}
        
      _ ->
        %{state | event_counts: counts}
    end
    
    {:ok, new_state}
  end
end