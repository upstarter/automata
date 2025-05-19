defmodule Automata.Infrastructure.Event.EventHandler do
  @moduledoc """
  Base behavior for implementing event handlers in the Automata system.
  
  Event handlers subscribe to specific events and process them without
  blocking the event bus. They can also emit new events as a result of
  processing.
  """
  
  @callback init(args :: term) :: {:ok, state :: term} | {:error, reason :: term}
  @callback handle_event(event :: map, state :: term) :: 
    {:ok, state :: term} | 
    {:emit, events :: list(map), state :: term} | 
    {:error, reason :: term, state :: term}
  @callback terminate(reason :: term, state :: term) :: term
  
  @doc """
  Defines an event handler module.
  """
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Automata.Infrastructure.Event.EventHandler
      
      use GenServer
      require Logger
      
      # Default implementations
      @impl Automata.Infrastructure.Event.EventHandler
      def init(_args), do: {:ok, %{}}
      
      @impl Automata.Infrastructure.Event.EventHandler
      def handle_event(_event, state), do: {:ok, state}
      
      @impl Automata.Infrastructure.Event.EventHandler
      def terminate(_reason, _state), do: :ok
      
      # Allow overriding
      defoverridable init: 1, handle_event: 2, terminate: 1
      
      # Server implementation
      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end
      
      # Subscribe to events based on configuration
      @impl GenServer
      def init(args) do
        Process.flag(:trap_exit, true)
        
        case Automata.Infrastructure.Event.EventHandler.init(args, __MODULE__) do
          {:ok, state} ->
            # Subscribe to specified events
            event_patterns = Keyword.get(unquote(opts), :events, [:all])
            
            # Handle both single pattern and list of patterns
            patterns = if is_list(event_patterns), do: event_patterns, else: [event_patterns]
            
            # Subscribe to each pattern
            Enum.each(patterns, fn pattern ->
              Automata.Infrastructure.Event.EventBus.subscribe(pattern)
            end)
            
            Logger.info("Started event handler: #{inspect(__MODULE__)}")
            
            {:ok, state}
            
          {:error, reason} ->
            {:stop, reason}
        end
      end
      
      @impl GenServer
      def handle_info({:event, event}, state) do
        # Call the behavior's implementation
        case handle_event(event, state) do
          {:ok, new_state} ->
            {:noreply, new_state}
            
          {:emit, events, new_state} ->
            # Publish new events
            Enum.each(events, fn event ->
              Automata.Infrastructure.Event.EventBus.publish(event)
            end)
            
            {:noreply, new_state}
            
          {:error, reason, new_state} ->
            Logger.error("Error handling event in #{inspect(__MODULE__)}: #{inspect(reason)}")
            {:noreply, new_state}
        end
      end
      
      @impl GenServer
      def terminate(reason, state) do
        # Call the behavior's implementation
        __MODULE__.terminate(reason, state)
      end
    end
  end
  
  @doc """
  Initializes the handler by calling the implementation's init function.
  """
  def init(args, module) do
    module.init(args)
  end
end