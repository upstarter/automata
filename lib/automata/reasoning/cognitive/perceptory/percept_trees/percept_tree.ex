defmodule PerceptTree do
  @moduledoc """
    A Tree of Percepts
    The Perception System takes the form of a Percept Tree. A Percept is an
    atomic classification and data extraction unit that models some aspect of
    the sensory inputs passed in by the Sensory System. Given a DataRecord it
    returns both a match probability (the BirdPercept will return the
    probability that a DataRecord represents the experience of seeing a bird)
    and, if the match is above a threshold, a piece of extracted data (such as
    body-space coordinates of the bird). The details of how the confidence is
    computed and what exact data is extracted are left to the individual
    percept. The percept structure might encapsulate a neural net or it might
    encapsulate a simple "if … then …else" clause. This freedom of form is one
    of the keys to making the Perception System extensible, since the system
    makes no assumptions about what a percept will detect, what type of data it
    will extract or how it will be implemented.
  """

  # a percept_tree is just tree of percepts
  @callback add_child(term) :: {:ok, list} | {:error, String.t()}
  @callback remove_child(term) :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, list} | {:error, String.t()}
  @callback continue_status() :: atom

  defmacro __using__(_opts) do
    quote do
      import __MODULE__
      @behaviour __MODULE__

      def add_child(child) do
        {:ok, []}
      end

      def remove_child(child) do
        {:ok, []}
      end

      def clear_children() do
        {:ok, []}
      end

      def continue_status() do
        {:ok, nil}
      end
    end
  end
end

defmodule Automata.Perceptory.PerceptTree do
  @moduledoc """
  Percept trees organize percepts hierarchically in terms of their specificity.
  
  For example, a ShapePercept will activate on the presence of any kind of shape
  whereas one of its children may activate only on a specific type of shape
  (e.g. a CircleShapePercept).
  
  The children of a percept will receive only the data that was extracted by its
  parent to process. This hierarchical structure is primarily an efficiency mechanism
  and is very similar to previous hierarchy-of-sensors approaches.
  
  Percepts can modulate their "receptive fields" (the space of inputs to which
  they will respond positively), and, in concert with the Action System, can
  modify the topology of the tree itself, dynamically growing a hierarchy of
  children in a process called innovation.
  """
  
  @type t :: %__MODULE__{
    root_percepts: list(Automata.Perceptory.Percept.t()),
    percept_registry: map(),  # Map of percept_id => percept
    activation_history: map() # Map of percept_id => list of activation timestamps
  }
  
  defstruct [
    root_percepts: [],
    percept_registry: %{},
    activation_history: %{}
  ]
  
  @doc """
  Creates a new empty percept tree.
  """
  def new() do
    %__MODULE__{
      root_percepts: [],
      percept_registry: %{},
      activation_history: %{}
    }
  end
  
  @doc """
  Adds a percept to the tree.
  
  If parent_path is empty, the percept is added as a root percept.
  Otherwise, it's added as a child of the percept at the specified path.
  """
  def add_percept(tree, percept, parent_path \\ []) do
    # Register the percept in the registry
    updated_registry = Map.put(tree.percept_registry, percept.id, percept)
    
    # If no parent, add as root percept
    if parent_path == [] do
      %{tree | 
        root_percepts: [percept | tree.root_percepts],
        percept_registry: updated_registry
      }
    else
      # Otherwise, find parent and add as child
      parent_id = List.last(parent_path)
      parent = Map.get(tree.percept_registry, parent_id)
      
      if parent do
        # Add child to parent
        updated_parent = %{parent | children: [percept | parent.children]}
        
        # Update registry with modified parent
        final_registry = Map.put(updated_registry, parent_id, updated_parent)
        
        %{tree | percept_registry: final_registry}
      else
        # Parent not found, add as root (with warning)
        IO.warn("Parent percept not found at path #{inspect(parent_path)}, adding as root")
        %{tree | 
          root_percepts: [percept | tree.root_percepts],
          percept_registry: updated_registry
        }
      end
    end
  end
  
  @doc """
  Processes sensory input through the percept tree.
  
  Returns a tuple of {matches, updated_tree} where matches is a map of
  percept_id => {confidence, extracted_data} for all percepts that matched.
  """
  def process(tree, sensory_input) do
    # Start with empty matches
    initial_acc = {%{}, tree}
    
    # Process through all root percepts
    Enum.reduce(tree.root_percepts, initial_acc, fn percept, {matches, current_tree} ->
      process_percept(percept, sensory_input, matches, current_tree)
    end)
  end
  
  @doc """
  Returns percepts that have been frequently activated.
  
  The threshold determines how many activations are required for a percept
  to be considered "frequently activated".
  """
  def get_frequently_activated(tree, threshold \\ 5, time_window \\ 60_000) do
    now = :os.system_time(:millisecond)
    cutoff = now - time_window
    
    Enum.filter(tree.percept_registry, fn {_id, percept} ->
      activations = Map.get(tree.activation_history, percept.id, [])
      # Count activations within time window
      recent_count = Enum.count(activations, fn timestamp -> timestamp > cutoff end)
      recent_count >= threshold
    end)
    |> Enum.map(fn {_id, percept} -> percept end)
  end
  
  # Private helpers
  
  # Process a single percept and its children
  defp process_percept(percept, sensory_input, matches, tree) do
    # Get the percept from the registry (it may have been updated)
    percept = Map.get(tree.percept_registry, percept.id, percept)
    
    # Check if this percept matches the input
    case Automata.Perceptory.Percept.process(percept, sensory_input) do
      {true, confidence, extracted_data} ->
        # Record activation
        now = :os.system_time(:millisecond)
        activation_history = Map.update(
          tree.activation_history, 
          percept.id, 
          [now], 
          fn timestamps -> [now | timestamps] |> Enum.take(20) end
        )
        
        # Add to matches
        updated_matches = Map.put(matches, percept.id, {confidence, extracted_data})
        updated_tree = %{tree | activation_history: activation_history}
        
        # Process children with the extracted data
        Enum.reduce(percept.children, {updated_matches, updated_tree}, fn child, {acc_matches, acc_tree} ->
          process_percept(child, extracted_data, acc_matches, acc_tree)
        end)
        
      {false, _, _} ->
        # No match, return unchanged
        {matches, tree}
    end
  end
end