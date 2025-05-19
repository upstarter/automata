defmodule Automata.Reasoning.Cognitive.ContextualReasoning.Config do
  @moduledoc """
  Configuration for the Contextual Reasoning Framework.
  
  This module defines the configuration options for the Contextual Reasoning
  Framework, including settings for context management, inference engine,
  knowledge representation, and memory integration.
  """
  
  @type t :: %__MODULE__{
    context_decay_rate: float(),
    inference_strategy: atom(),
    knowledge_schema: atom(),
    memory_integration_mode: atom()
  }
  
  defstruct [
    # Rate at which inactive contexts lose relevance
    context_decay_rate: 0.1,
    
    # Strategy for contextual inference (options: :bayesian, :fuzzy, :symbolic)
    inference_strategy: :bayesian,
    
    # Schema for knowledge representation (options: :semantic_network, :frame, :ontology)
    knowledge_schema: :semantic_network,
    
    # How context integrates with memory (options: :associative, :episodic, :semantic)
    memory_integration_mode: :associative
  ]
  
  @doc """
  Creates a new configuration with default values.
  """
  def new, do: %__MODULE__{}
  
  @doc """
  Creates a new configuration with the provided options.
  """
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end
end