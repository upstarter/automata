# Contextual Reasoning Framework

The Contextual Reasoning Framework is a cognitive architecture component for the Automata project that enables context-sensitive reasoning, allowing automata to adapt their reasoning processes based on the current situation and past experiences.

## Structure

The framework is organized into the following components:

1. **Context Management** - Manages activation, deactivation, and switching between contexts
2. **Inference Engine** - Performs reasoning based on current context and available knowledge
3. **Knowledge Representation** - Stores knowledge in a context-sensitive format (semantic network)
4. **Memory Integration** - Integrates percepts and context information with episodic and semantic memory

## Usage

Basic usage of the Contextual Reasoning Framework:

```elixir
# Create a new framework with default configuration
framework = Automata.Reasoning.Cognitive.ContextualReasoning.new()

# Customize the configuration
config = Automata.Reasoning.Cognitive.ContextualReasoning.Config.new(
  inference_strategy: :symbolic,
  memory_integration_mode: :episodic
)
framework = Automata.Reasoning.Cognitive.ContextualReasoning.new(config)

# Add knowledge with contextual information
framework = framework
  |> Automata.Reasoning.Cognitive.ContextualReasoning.add_knowledge(
    "apple",
    "Apple",
    %{color: "red", type: "fruit"},
    ["food_context"]
  )
  |> Automata.Reasoning.Cognitive.ContextualReasoning.add_knowledge(
    "fruit",
    "Fruit",
    %{type: "food_category"},
    ["food_context"]
  )

# Add relationships with contextual information
framework = Automata.Reasoning.Cognitive.ContextualReasoning.add_relationship(
  framework,
  "apple",
  "fruit",
  :is_a,
  1.0,
  ["food_context"]
)

# Process percepts through the reasoning framework
percepts = [
  %{type: :visual, value: "red apple"},
  %{type: :taste, value: "sweet"}
]

{inference_result, updated_framework} = 
  Automata.Reasoning.Cognitive.ContextualReasoning.process_percepts(framework, percepts)

# Extract conclusion and confidence
%{
  conclusion: conclusion,
  confidence: confidence,
  context_id: context_id,
  reasoning_trace: reasoning_trace
} = inference_result

# Retrieve context-specific knowledge
contextual_knowledge = 
  Automata.Reasoning.Cognitive.ContextualReasoning.get_contextual_knowledge(
    updated_framework, 
    context_id
  )

# Retrieve context-specific memories
contextual_memories = 
  Automata.Reasoning.Cognitive.ContextualReasoning.get_contextual_memories(
    updated_framework, 
    context_id
  )
```

## Components

### Context Manager

The Context Manager handles the activation, deactivation, and switching between different contexts. It maintains:

- Active contexts with their activation levels
- Context history
- Context relationships and associations

### Inference Engine

The Inference Engine performs reasoning based on the current context. It supports multiple reasoning strategies:

- Bayesian inference (probabilistic reasoning)
- Fuzzy logic inference (continuous truth values)
- Symbolic inference (rule-based reasoning)

### Knowledge Representation

The Knowledge Representation component stores knowledge in a context-sensitive format. Currently, it implements:

- Semantic Network - concepts connected through labeled relationships

### Memory Integration

The Memory Integration component connects percepts and contexts with memory systems:

- Episodic memory (event memories in specific contexts)
- Semantic memory (general knowledge associated with contexts)
- Associative memory (connections between memories based on context)

## Future Enhancements

- Context learning and adaptation
- Hierarchical context representation
- Integration with other reasoning components
- Performance optimizations for large knowledge bases
- Context-based predictive reasoning