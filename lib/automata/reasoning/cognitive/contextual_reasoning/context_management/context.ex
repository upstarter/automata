defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context do
  @moduledoc """
  Defines the Context structure, a first-class entity in the Contextual Reasoning Framework.
  
  A Context represents a specific situation, environment, or perspective that influences
  how knowledge is interpreted and reasoning is performed. Contexts are hierarchical
  and compositional, allowing for complex contextual relationships.
  
  Each Context has:
  - A unique identifier
  - Activation level (how relevant the context is currently)
  - Parent contexts (inheritance relationships)
  - Parameters (contextual variables)
  - Assertions (facts that are true in this context)
  - Rules (inference rules specific to this context)
  - Meta-data (creation time, last activation, etc.)
  """
  
  alias __MODULE__
  
  @type activation_level :: float()  # 0.0 to 1.0
  @type context_id :: atom() | String.t()
  @type context_param :: {atom(), any()}
  @type assertion :: {atom(), [any()]}
  @type rule :: {atom(), [assertion()], assertion(), float()}
  
  defstruct [
    :id,                   # Unique identifier for the context
    :name,                 # Human-readable name
    :description,          # Description of the context
    :parent_ids,           # List of parent context IDs for inheritance
    :activation,           # Current activation level (0.0 to 1.0)
    :parameters,           # Map of context-specific parameters
    :assertions,           # Set of assertions (facts) true in this context
    :rules,                # List of inference rules specific to this context
    :metadata,             # Map of metadata (creation time, etc.)
    :children,             # List of child context IDs
    :activation_threshold, # Threshold for context to be considered active
    :decay_rate            # Rate at which activation decays over time
  ]
  
  @doc """
  Creates a new context.
  
  ## Parameters
  - id: Unique identifier
  - name: Human-readable name
  - description: Description of the context
  - parent_ids: List of parent context IDs
  - parameters: Initial parameters map
  - assertions: Initial assertions set
  - rules: Initial rules list
  - activation_threshold: Activation threshold (default: 0.5)
  - decay_rate: Activation decay rate (default: 0.05)
  
  ## Returns
  A new Context struct
  """
  def new(id, name, description, parent_ids \\ [], parameters \\ %{}, 
          assertions \\ MapSet.new(), rules \\ [], activation_threshold \\ 0.5,
          decay_rate \\ 0.05) do
    %Context{
      id: id,
      name: name,
      description: description,
      parent_ids: parent_ids,
      activation: 0.0,
      parameters: parameters,
      assertions: assertions,
      rules: rules,
      children: [],
      metadata: %{
        created_at: DateTime.utc_now(),
        last_activated: nil,
        activation_count: 0
      },
      activation_threshold: activation_threshold,
      decay_rate: decay_rate
    }
  end
  
  @doc """
  Activates a context with a specified activation value.
  
  ## Parameters
  - context: The context to activate
  - activation_value: Value to increase activation by (default: 1.0)
  
  ## Returns
  Updated context with increased activation
  """
  def activate(context, activation_value \\ 1.0) do
    new_activation = min(1.0, context.activation + activation_value)
    
    %{context | 
      activation: new_activation,
      metadata: Map.merge(context.metadata, %{
        last_activated: DateTime.utc_now(),
        activation_count: context.metadata.activation_count + 1
      })
    }
  end
  
  @doc """
  Deactivates a context with a specified value.
  
  ## Parameters
  - context: The context to deactivate
  - deactivation_value: Value to decrease activation by (default: 1.0)
  
  ## Returns
  Updated context with decreased activation
  """
  def deactivate(context, deactivation_value \\ 1.0) do
    new_activation = max(0.0, context.activation - deactivation_value)
    %{context | activation: new_activation}
  end
  
  @doc """
  Applies decay to context activation based on the context's decay rate.
  
  ## Parameters
  - context: The context to decay
  
  ## Returns
  Updated context with decayed activation
  """
  def apply_decay(context) do
    new_activation = max(0.0, context.activation * (1.0 - context.decay_rate))
    %{context | activation: new_activation}
  end
  
  @doc """
  Checks if a context is currently active.
  
  ## Parameters
  - context: The context to check
  
  ## Returns
  Boolean indicating if the context is active
  """
  def active?(context) do
    context.activation >= context.activation_threshold
  end
  
  @doc """
  Adds a child context to the current context.
  
  ## Parameters
  - context: The parent context
  - child_id: ID of the child context to add
  
  ## Returns
  Updated parent context with new child added
  """
  def add_child(context, child_id) do
    %{context | children: [child_id | context.children] |> Enum.uniq()}
  end
  
  @doc """
  Adds an assertion to the context.
  
  ## Parameters
  - context: The context to modify
  - assertion: The assertion to add
  
  ## Returns
  Updated context with the new assertion
  """
  def add_assertion(context, assertion) do
    %{context | assertions: MapSet.put(context.assertions, assertion)}
  end
  
  @doc """
  Removes an assertion from the context.
  
  ## Parameters
  - context: The context to modify
  - assertion: The assertion to remove
  
  ## Returns
  Updated context without the assertion
  """
  def remove_assertion(context, assertion) do
    %{context | assertions: MapSet.delete(context.assertions, assertion)}
  end
  
  @doc """
  Adds a rule to the context.
  
  ## Parameters
  - context: The context to modify
  - rule: The rule to add
  
  ## Returns
  Updated context with the new rule
  """
  def add_rule(context, rule) do
    %{context | rules: [rule | context.rules]}
  end
  
  @doc """
  Removes a rule from the context.
  
  ## Parameters
  - context: The context to modify
  - rule_id: The ID of the rule to remove
  
  ## Returns
  Updated context without the rule
  """
  def remove_rule(context, rule_id) do
    %{context | rules: Enum.reject(context.rules, fn {id, _, _, _} -> id == rule_id end)}
  end
  
  @doc """
  Sets a parameter in the context.
  
  ## Parameters
  - context: The context to modify
  - key: Parameter key
  - value: Parameter value
  
  ## Returns
  Updated context with the parameter set
  """
  def set_parameter(context, key, value) do
    %{context | parameters: Map.put(context.parameters, key, value)}
  end
  
  @doc """
  Gets a parameter from the context.
  
  ## Parameters
  - context: The context to query
  - key: Parameter key
  - default: Default value if parameter doesn't exist
  
  ## Returns
  Parameter value or default
  """
  def get_parameter(context, key, default \\ nil) do
    Map.get(context.parameters, key, default)
  end
  
  @doc """
  Merges two contexts, combining their parameters, assertions, and rules.
  
  ## Parameters
  - context1: First context
  - context2: Second context
  
  ## Returns
  New context with merged content
  """
  def merge(context1, context2) do
    %{context1 |
      parameters: Map.merge(context1.parameters, context2.parameters),
      assertions: MapSet.union(context1.assertions, context2.assertions),
      rules: context1.rules ++ context2.rules,
      parent_ids: (context1.parent_ids ++ context2.parent_ids) |> Enum.uniq(),
      children: (context1.children ++ context2.children) |> Enum.uniq()
    }
  end
end