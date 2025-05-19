defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager do
  @moduledoc """
  Manages the creation, activation, deactivation, and relationships between contexts.
  
  The ContextManager is responsible for:
  - Maintaining the context registry
  - Managing context activation levels
  - Handling context hierarchies and inheritance
  - Facilitating context switching
  - Predicting context activation based on perceptual input
  - Managing context lifecycles
  """
  
  use GenServer
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  
  require Logger
  
  defstruct [
    :contexts,              # Map of context_id to Context
    :active_contexts,       # Set of currently active context IDs
    :context_relations,     # Graph of context relationships
    :activation_history,    # History of context activations
    :perceptory,            # Reference to the perception system
    :max_active_contexts,   # Maximum number of simultaneously active contexts
    :context_decay_interval # Interval for context activation decay
  ]
  
  # Client API
  
  @doc """
  Starts the context manager.
  
  ## Parameters
  - perceptory: Reference to the perception system
  - opts: Options for GenServer
  
  ## Returns
  GenServer start result
  """
  def start_link(perceptory, opts \\ []) do
    GenServer.start_link(__MODULE__, perceptory, opts)
  end
  
  @doc """
  Creates a new context.
  
  ## Parameters
  - manager: The context manager
  - id: Unique identifier for the context
  - name: Human-readable name
  - description: Description of the context
  - parent_ids: List of parent context IDs
  - parameters: Initial parameters map
  - assertions: Initial assertions set
  - rules: Initial rules list
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def create_context(manager, id, name, description, parent_ids \\ [], 
                     parameters \\ %{}, assertions \\ MapSet.new(), rules \\ []) do
    GenServer.call(manager, {:create_context, id, name, description, 
                            parent_ids, parameters, assertions, rules})
  end
  
  @doc """
  Activates a context.
  
  ## Parameters
  - manager: The context manager
  - context_id: ID of the context to activate
  - activation_value: Value to increase activation by (default: 1.0)
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def activate_context(manager, context_id, activation_value \\ 1.0) do
    GenServer.call(manager, {:activate_context, context_id, activation_value})
  end
  
  @doc """
  Deactivates a context.
  
  ## Parameters
  - manager: The context manager
  - context_id: ID of the context to deactivate
  - deactivation_value: Value to decrease activation by (default: 1.0)
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def deactivate_context(manager, context_id, deactivation_value \\ 1.0) do
    GenServer.call(manager, {:deactivate_context, context_id, deactivation_value})
  end
  
  @doc """
  Gets a context by ID.
  
  ## Parameters
  - manager: The context manager
  - context_id: ID of the context to retrieve
  
  ## Returns
  The context or nil if not found
  """
  def get_context(manager, context_id) do
    GenServer.call(manager, {:get_context, context_id})
  end
  
  @doc """
  Gets all currently active contexts.
  
  ## Parameters
  - manager: The context manager
  
  ## Returns
  List of active contexts
  """
  def get_active_contexts(manager) do
    GenServer.call(manager, :get_active_contexts)
  end
  
  @doc """
  Updates a context.
  
  ## Parameters
  - manager: The context manager
  - context: Updated context
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def update_context(manager, context) do
    GenServer.call(manager, {:update_context, context})
  end
  
  @doc """
  Adds an assertion to a context.
  
  ## Parameters
  - manager: The context manager
  - context_id: ID of the context to modify
  - assertion: The assertion to add
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def add_assertion(manager, context_id, assertion) do
    GenServer.call(manager, {:add_assertion, context_id, assertion})
  end
  
  @doc """
  Predicts context activations based on perceptual input.
  
  ## Parameters
  - manager: The context manager
  - percepts: Current perceptual input
  
  ## Returns
  Map of context IDs to predicted activation values
  """
  def predict_context_activations(manager, percepts) do
    GenServer.call(manager, {:predict_activations, percepts})
  end
  
  @doc """
  Switches the active context based on perceptual input.
  
  ## Parameters
  - manager: The context manager
  - percepts: Current perceptual input
  
  ## Returns
  :ok on success
  """
  def switch_context_from_percepts(manager, percepts) do
    GenServer.cast(manager, {:switch_context, percepts})
  end
  
  # Server callbacks
  
  @impl true
  def init(perceptory) do
    # Schedule periodic context decay
    decay_interval = 1000  # 1 second
    schedule_decay(decay_interval)
    
    {:ok, %__MODULE__{
      contexts: %{},
      active_contexts: MapSet.new(),
      context_relations: %{},  # Graph structure
      activation_history: [],
      perceptory: perceptory,
      max_active_contexts: 5,  # Default max active contexts
      context_decay_interval: decay_interval
    }}
  end
  
  @impl true
  def handle_call({:create_context, id, name, description, parent_ids, 
                   parameters, assertions, rules}, _from, state) do
    case Map.has_key?(state.contexts, id) do
      true ->
        {:reply, {:error, :context_exists}, state}
        
      false ->
        context = Context.new(id, name, description, parent_ids, 
                             parameters, assertions, rules)
        
        # Update parent contexts to include this as a child
        updated_contexts = Enum.reduce(parent_ids, state.contexts, fn parent_id, acc ->
          case Map.get(acc, parent_id) do
            nil -> acc
            parent_context ->
              updated_parent = Context.add_child(parent_context, id)
              Map.put(acc, parent_id, updated_parent)
          end
        end)
        
        # Add the new context
        updated_contexts = Map.put(updated_contexts, id, context)
        
        # Update context relations graph
        updated_relations = Enum.reduce(parent_ids, state.context_relations, fn parent_id, acc ->
          parent_children = Map.get(acc, parent_id, [])
          Map.put(acc, parent_id, [id | parent_children])
        end)
        
        {:reply, :ok, %{state | 
          contexts: updated_contexts,
          context_relations: updated_relations
        }}
    end
  end
  
  @impl true
  def handle_call({:activate_context, context_id, activation_value}, _from, state) do
    case Map.get(state.contexts, context_id) do
      nil ->
        {:reply, {:error, :context_not_found}, state}
        
      context ->
        updated_context = Context.activate(context, activation_value)
        updated_contexts = Map.put(state.contexts, context_id, updated_context)
        
        # Update active contexts set if needed
        updated_active = if Context.active?(updated_context) do
          MapSet.put(state.active_contexts, context_id)
        else
          state.active_contexts
        end
        
        # Record activation in history
        updated_history = [{context_id, activation_value, DateTime.utc_now()} | 
                           state.activation_history] |> Enum.take(100)
        
        # Handle max active contexts limit
        {final_active, final_contexts} = enforce_max_active_contexts(
          updated_active, 
          updated_contexts, 
          state.max_active_contexts
        )
        
        {:reply, :ok, %{state | 
          contexts: final_contexts,
          active_contexts: final_active,
          activation_history: updated_history
        }}
    end
  end
  
  @impl true
  def handle_call({:deactivate_context, context_id, deactivation_value}, _from, state) do
    case Map.get(state.contexts, context_id) do
      nil ->
        {:reply, {:error, :context_not_found}, state}
        
      context ->
        updated_context = Context.deactivate(context, deactivation_value)
        updated_contexts = Map.put(state.contexts, context_id, updated_context)
        
        # Update active contexts set if needed
        updated_active = if Context.active?(updated_context) do
          state.active_contexts
        else
          MapSet.delete(state.active_contexts, context_id)
        end
        
        {:reply, :ok, %{state | 
          contexts: updated_contexts,
          active_contexts: updated_active
        }}
    end
  end
  
  @impl true
  def handle_call({:get_context, context_id}, _from, state) do
    {:reply, Map.get(state.contexts, context_id), state}
  end
  
  @impl true
  def handle_call(:get_active_contexts, _from, state) do
    active_context_objects = Enum.map(state.active_contexts, fn id ->
      Map.get(state.contexts, id)
    end) |> Enum.filter(&(&1 != nil))
    
    {:reply, active_context_objects, state}
  end
  
  @impl true
  def handle_call({:update_context, context}, _from, state) do
    context_id = context.id
    
    case Map.has_key?(state.contexts, context_id) do
      false ->
        {:reply, {:error, :context_not_found}, state}
        
      true ->
        updated_contexts = Map.put(state.contexts, context_id, context)
        
        # Update active contexts set if needed
        updated_active = if Context.active?(context) do
          MapSet.put(state.active_contexts, context_id)
        else
          MapSet.delete(state.active_contexts, context_id)
        end
        
        {:reply, :ok, %{state | 
          contexts: updated_contexts,
          active_contexts: updated_active
        }}
    end
  end
  
  @impl true
  def handle_call({:add_assertion, context_id, assertion}, _from, state) do
    case Map.get(state.contexts, context_id) do
      nil ->
        {:reply, {:error, :context_not_found}, state}
        
      context ->
        updated_context = Context.add_assertion(context, assertion)
        updated_contexts = Map.put(state.contexts, context_id, updated_context)
        
        {:reply, :ok, %{state | contexts: updated_contexts}}
    end
  end
  
  @impl true
  def handle_call({:predict_activations, percepts}, _from, state) do
    # Simple implementation - in a real system this would use more sophisticated
    # pattern matching or ML to predict which contexts are relevant
    
    # For each context, calculate a relevance score based on percepts
    context_scores = Enum.map(state.contexts, fn {id, context} ->
      score = calculate_context_relevance(context, percepts)
      {id, score}
    end) |> Enum.into(%{})
    
    {:reply, context_scores, state}
  end
  
  @impl true
  def handle_cast({:switch_context, percepts}, state) do
    # Predict context activations
    context_scores = Enum.map(state.contexts, fn {id, context} ->
      score = calculate_context_relevance(context, percepts)
      {id, score}
    end) |> Enum.into(%{})
    
    # Activate contexts with high scores, deactivate others
    updated_contexts = Enum.reduce(context_scores, state.contexts, fn {id, score}, acc ->
      context = Map.get(acc, id)
      
      updated_context = if score > 0.7 do  # Activation threshold
        Context.activate(context, score)
      else
        # Gradually deactivate contexts with low scores
        Context.deactivate(context, 0.2)
      end
      
      Map.put(acc, id, updated_context)
    end)
    
    # Update active contexts set
    updated_active = Enum.reduce(updated_contexts, MapSet.new(), fn {id, context}, acc ->
      if Context.active?(context) do
        MapSet.put(acc, id)
      else
        acc
      end
    end)
    
    # Handle max active contexts limit
    {final_active, final_contexts} = enforce_max_active_contexts(
      updated_active, 
      updated_contexts, 
      state.max_active_contexts
    )
    
    {:noreply, %{state | 
      contexts: final_contexts,
      active_contexts: final_active
    }}
  end
  
  @impl true
  def handle_info(:decay_contexts, state) do
    # Apply decay to all context activations
    updated_contexts = Enum.map(state.contexts, fn {id, context} ->
      {id, Context.apply_decay(context)}
    end) |> Enum.into(%{})
    
    # Update active contexts set
    updated_active = Enum.reduce(updated_contexts, MapSet.new(), fn {id, context}, acc ->
      if Context.active?(context) do
        MapSet.put(acc, id)
      else
        acc
      end
    end)
    
    # Schedule next decay
    schedule_decay(state.context_decay_interval)
    
    {:noreply, %{state | 
      contexts: updated_contexts,
      active_contexts: updated_active
    }}
  end
  
  # Private helper functions
  
  defp schedule_decay(interval) do
    Process.send_after(self(), :decay_contexts, interval)
  end
  
  defp calculate_context_relevance(context, percepts) do
    # This is a simplified implementation
    # In a real system, this would use more sophisticated pattern matching
    # or machine learning to calculate relevance
    
    # Look for matching assertions in the context
    assertion_match_count = Enum.reduce(percepts, 0, fn percept, count ->
      if MapSet.member?(context.assertions, percept_to_assertion(percept)) do
        count + 1
      else
        count
      end
    end)
    
    # Calculate score based on number of matching assertions
    case length(percepts) do
      0 -> 0.0
      n -> assertion_match_count / n
    end
  end
  
  defp percept_to_assertion(percept) do
    # Convert a perception to an assertion format
    # This is a simplified implementation
    {percept.type, percept.attributes}
  end
  
  defp enforce_max_active_contexts(active_contexts, contexts, max_count) do
    if MapSet.size(active_contexts) <= max_count do
      {active_contexts, contexts}
    else
      # Need to deactivate some contexts - keep the highest activation ones
      active_sorted = active_contexts
      |> Enum.map(fn id -> {id, Map.get(contexts, id)} end)
      |> Enum.filter(fn {_, context} -> context != nil end)
      |> Enum.sort_by(fn {_, context} -> context.activation end, :desc)
      
      # Keep the top max_count contexts active
      {to_keep, to_deactivate} = Enum.split(active_sorted, max_count)
      
      # Deactivate the excess contexts
      updated_contexts = Enum.reduce(to_deactivate, contexts, fn {id, context}, acc ->
        deactivated = Context.deactivate(context, 1.0)  # Fully deactivate
        Map.put(acc, id, deactivated)
      end)
      
      # Create new active set with only the kept contexts
      new_active = Enum.map(to_keep, fn {id, _} -> id end) |> MapSet.new()
      
      {new_active, updated_contexts}
    end
  end
end