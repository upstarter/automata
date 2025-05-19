defmodule Automata.Reasoning.Cognitive.ContextualReasoning.InferenceEngine.ContextualInference do
  @moduledoc """
  Provides contextual inference capabilities for reasoning in specific contexts.
  
  The ContextualInference engine allows for reasoning that is sensitive to the
  current active contexts. It can:
  
  - Apply inference rules from active contexts
  - Derive new assertions based on context-specific rules
  - Handle uncertainty and conflicting information across contexts
  - Perform reasoning with context inheritance
  - Support meta-reasoning about contexts themselves
  """
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  require Logger
  
  @type assertion :: {atom(), [any()]}
  @type rule :: {atom(), [assertion()], assertion(), float()}
  @type inference_result :: {:ok, [assertion()]} | {:error, atom()}
  
  @doc """
  Performs inference within the active contexts.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - query: The query assertion or pattern
  - max_depth: Maximum inference depth
  
  ## Returns
  List of derived assertions matching the query
  """
  @spec infer(pid(), assertion() | term(), integer()) :: inference_result()
  def infer(context_manager, query, max_depth \\ 10) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(context_manager)
    
    # Collect all assertions and rules from active contexts
    {assertions, rules} = collect_context_knowledge(active_contexts)
    
    # Perform forward chaining inference
    try do
      derived_assertions = forward_chain(assertions, rules, max_depth)
      
      # Filter results based on query
      matching_assertions = filter_assertions(derived_assertions, query)
      
      {:ok, matching_assertions}
    catch
      :max_depth_exceeded ->
        {:error, :max_depth_exceeded}
      
      error ->
        Logger.error("Inference error: #{inspect(error)}")
        {:error, :inference_failed}
    end
  end
  
  @doc """
  Performs goal-directed inference to prove a specific assertion.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - goal: The assertion to prove
  - max_depth: Maximum inference depth
  
  ## Returns
  Boolean indicating if the goal can be proven, and a proof trace
  """
  @spec prove(pid(), assertion(), integer()) :: {:ok, boolean(), [any()]} | {:error, atom()}
  def prove(context_manager, goal, max_depth \\ 10) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(context_manager)
    
    # Collect all assertions and rules from active contexts
    {assertions, rules} = collect_context_knowledge(active_contexts)
    
    # Perform backward chaining to prove the goal
    try do
      {result, proof_trace} = backward_chain(goal, assertions, rules, [], max_depth)
      
      {:ok, result, proof_trace}
    catch
      :max_depth_exceeded ->
        {:error, :max_depth_exceeded}
      
      error ->
        Logger.error("Proof error: #{inspect(error)}")
        {:error, :proof_failed}
    end
  end
  
  @doc """
  Checks if an assertion is consistent with the active contexts.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - assertion: The assertion to check
  
  ## Returns
  Tuple with boolean indicating consistency and list of conflicting assertions
  """
  @spec consistent?(pid(), assertion()) :: {boolean(), [assertion()]}
  def consistent?(context_manager, assertion) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(context_manager)
    
    # Collect all assertions from active contexts
    {assertions, _} = collect_context_knowledge(active_contexts)
    
    # Check for contradictions
    conflicts = find_conflicts(assertion, assertions)
    
    {Enum.empty?(conflicts), conflicts}
  end
  
  @doc """
  Applies a rule to derive new assertions in a given context.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - context_id: ID of the context to apply the rule in
  - rule: The rule to apply
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  @spec apply_rule(pid(), atom(), rule()) :: :ok | {:error, atom()}
  def apply_rule(context_manager, context_id, rule = {rule_id, conditions, conclusion, _}) do
    # Get the context
    case ContextManager.get_context(context_manager, context_id) do
      nil ->
        {:error, :context_not_found}
        
      context ->
        # Check if conditions are satisfied in the context
        if conditions_satisfied?(conditions, context.assertions) do
          # Add the conclusion to the context
          updated_context = Context.add_assertion(context, conclusion)
          |> Context.add_rule(rule)
          
          # Update the context
          ContextManager.update_context(context_manager, updated_context)
        else
          {:error, :conditions_not_satisfied}
        end
    end
  end
  
  @doc """
  Explains the reasoning path for a derived assertion.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - assertion: The assertion to explain
  
  ## Returns
  Explanation structure with reasoning steps
  """
  @spec explain(pid(), assertion()) :: {:ok, map()} | {:error, atom()}
  def explain(context_manager, assertion) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(context_manager)
    
    # Collect all assertions and rules from active contexts
    {assertions, rules} = collect_context_knowledge(active_contexts)
    
    # Find explanation by backward reasoning
    try do
      {result, proof_trace} = backward_chain(assertion, assertions, rules, [], 20)
      
      if result do
        # Format explanation
        explanation = format_explanation(assertion, proof_trace, active_contexts)
        {:ok, explanation}
      else
        {:error, :not_provable}
      end
    catch
      error ->
        Logger.error("Explanation error: #{inspect(error)}")
        {:error, :explanation_failed}
    end
  end
  
  # Private helper functions
  
  defp collect_context_knowledge(contexts) do
    # Collect all assertions and rules from the given contexts
    Enum.reduce(contexts, {MapSet.new(), []}, fn context, {acc_assertions, acc_rules} ->
      # Add assertions from this context
      updated_assertions = MapSet.union(acc_assertions, context.assertions)
      
      # Add rules from this context
      updated_rules = acc_rules ++ context.rules
      
      {updated_assertions, updated_rules}
    end)
  end
  
  defp forward_chain(assertions, rules, max_depth, depth \\ 0) do
    if depth >= max_depth do
      throw :max_depth_exceeded
    end
    
    # Find rules that can be applied
    applicable_rules = Enum.filter(rules, fn {_, conditions, _, _} ->
      conditions_satisfied?(conditions, assertions)
    end)
    
    if Enum.empty?(applicable_rules) do
      # No more rules can be applied - fixed point reached
      assertions
    else
      # Apply rules to derive new assertions
      new_assertions = Enum.reduce(applicable_rules, assertions, fn {_, _, conclusion, _}, acc ->
        MapSet.put(acc, conclusion)
      end)
      
      if MapSet.equal?(new_assertions, assertions) do
        # No new assertions were derived - fixed point reached
        assertions
      else
        # Continue forward chaining with new assertions
        forward_chain(new_assertions, rules, max_depth, depth + 1)
      end
    end
  end
  
  defp backward_chain(goal, assertions, rules, proof_trace, max_depth, depth \\ 0) do
    if depth >= max_depth do
      throw :max_depth_exceeded
    end
    
    # Check if goal is already in assertions
    if MapSet.member?(assertions, goal) do
      {true, [{:fact, goal} | proof_trace]}
    else
      # Find rules that can derive the goal
      relevant_rules = Enum.filter(rules, fn {_, _, conclusion, _} ->
        matches_pattern?(conclusion, goal)
      end)
      
      # Try to prove the goal using the rules
      Enum.reduce_while(relevant_rules, {false, proof_trace}, fn {rule_id, conditions, conclusion, certainty}, acc ->
        # For each condition, try to prove it
        {all_satisfied, condition_traces} = Enum.reduce_while(conditions, {true, []}, fn condition, {_, traces} ->
          {satisfied, sub_trace} = backward_chain(condition, assertions, rules, [], max_depth, depth + 1)
          
          if satisfied do
            {:cont, {true, [sub_trace | traces]}}
          else
            {:halt, {false, traces}}
          end
        end)
        
        if all_satisfied do
          # All conditions are satisfied, goal is proven
          rule_trace = {:rule, rule_id, conditions, conclusion, certainty, condition_traces}
          {:halt, {true, [rule_trace | proof_trace]}}
        else
          # Continue trying other rules
          {:cont, acc}
        end
      end)
    end
  end
  
  defp conditions_satisfied?(conditions, assertions) do
    Enum.all?(conditions, fn condition ->
      Enum.any?(assertions, fn assertion ->
        matches_pattern?(assertion, condition)
      end)
    end)
  end
  
  defp matches_pattern?({pred, args1}, {pred, args2}) do
    # Same predicate, check if arguments match
    args_match?(args1, args2)
  end
  
  defp matches_pattern?(_, _), do: false
  
  defp args_match?(args1, args2) when length(args1) != length(args2), do: false
  
  defp args_match?(args1, args2) do
    Enum.zip(args1, args2)
    |> Enum.all?(fn {a1, a2} ->
      cond do
        is_function(a2, 1) -> a2.(a1)  # a2 is a matching function
        is_atom(a2) and a2 == :_ -> true  # Wildcard
        true -> a1 == a2  # Exact match
      end
    end)
  end
  
  defp filter_assertions(assertions, :all), do: MapSet.to_list(assertions)
  
  defp filter_assertions(assertions, query) do
    MapSet.to_list(assertions)
    |> Enum.filter(fn assertion ->
      matches_pattern?(assertion, query)
    end)
  end
  
  defp find_conflicts(assertion, assertions) do
    # In a more sophisticated system, this would use contradiction rules
    # For now, we just check for direct negations
    {pred, args} = assertion
    
    case pred do
      :not ->
        # Check if the positive form exists
        [positive] = args
        if MapSet.member?(assertions, positive) do
          [positive]
        else
          []
        end
        
      _ ->
        # Check if the negative form exists
        negative = {:not, [assertion]}
        if MapSet.member?(assertions, negative) do
          [negative]
        else
          []
        end
    end
  end
  
  defp format_explanation(assertion, proof_trace, contexts) do
    context_names = Enum.map(contexts, fn c -> c.name end)
    
    %{
      assertion: assertion,
      contexts: context_names,
      proof: proof_trace_to_string(proof_trace),
      confidence: calculate_confidence(proof_trace)
    }
  end
  
  defp proof_trace_to_string(proof_trace) do
    # Format proof trace to human-readable explanation
    # This is a simplified implementation
    Enum.map(proof_trace, fn
      {:fact, fact} ->
        "Direct fact: #{inspect(fact)}"
        
      {:rule, rule_id, conditions, conclusion, certainty, _} ->
        conditions_str = Enum.map_join(conditions, ", ", &inspect/1)
        "Rule #{rule_id}: If #{conditions_str} then #{inspect(conclusion)} (certainty: #{certainty})"
    end)
  end
  
  defp calculate_confidence(proof_trace) do
    # Calculate overall confidence based on rule certainties
    # This is a simplified implementation using minimum certainty
    Enum.reduce(proof_trace, 1.0, fn
      {:rule, _, _, _, certainty, _}, acc -> min(acc, certainty)
      _, acc -> acc
    end)
  end
end