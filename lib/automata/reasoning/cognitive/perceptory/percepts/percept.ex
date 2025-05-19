defmodule Percept do
  @moduledoc """
  Base module for the original Percept interface
  """

  @callback update(any()) :: any()

  defmacro __using__(_opts) do
  end
end

defmodule Automata.Perceptory.Percept do
  @moduledoc """
  A Percept is an atomic classification and data extraction unit that models
  some aspect of the sensory inputs.
  
  Given sensory input, a percept returns both a match confidence (probability) and,
  if the match is above a threshold, a piece of extracted data. The details of
  how the confidence is computed and what exact data is extracted are left to
  the individual percept implementation.
  
  The percept structure might encapsulate a neural net, a simple pattern matching
  rule, or any other classification mechanism. This freedom of form is one
  of the keys to making the Perception System extensible, since the system
  makes no assumptions about what a percept will detect, what type of data it
  will extract, or how it will be implemented.
  """
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    type: atom(),
    confidence_threshold: float(),
    children: list(t()),
    data_schema: map(),
    metadata: map()
  }
  
  defstruct [
    id: nil,
    name: "",
    type: :generic,
    confidence_threshold: 0.5,
    children: [],
    data_schema: %{},
    metadata: %{}
  ]
  
  @doc """
  Creates a new percept with the given attributes.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    %__MODULE__{
      id: id, 
      name: Map.get(attrs, :name, "Percept_#{id}"),
      type: Map.get(attrs, :type, :generic),
      confidence_threshold: Map.get(attrs, :confidence_threshold, 0.5),
      children: Map.get(attrs, :children, []),
      data_schema: Map.get(attrs, :data_schema, %{}),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end
  
  @doc """
  Processes sensory input with this percept.
  
  Returns a tuple of {matched, confidence, extracted_data} where:
  - matched: boolean indicating if the percept matched the input
  - confidence: the confidence level of the match (0.0 to 1.0)
  - extracted_data: any data extracted from the input, or nil if no match
  """
  def process(percept, sensory_input) do
    # This is a base implementation that should be overridden by concrete percepts
    # In a real implementation, each percept type would have its own processing logic
    
    # For demonstration purposes, we'll implement a simple generic matcher
    # that matches based on type
    {confidence, extracted_data} = process_by_type(percept.type, sensory_input)
    
    matched = confidence >= percept.confidence_threshold
    
    {matched, confidence, if(matched, do: extracted_data, else: nil)}
  end
  
  @doc """
  Adds a child percept to this percept.
  """
  def add_child(percept, child) do
    %{percept | children: [child | percept.children]}
  end
  
  @doc """
  Updates the metadata of this percept.
  """
  def update_metadata(percept, key, value) do
    updated_metadata = Map.put(percept.metadata, key, value)
    %{percept | metadata: updated_metadata}
  end
  
  @doc """
  Gets a value from the percept's metadata.
  """
  def get_metadata(percept, key) do
    Map.get(percept.metadata, key)
  end
  
  # Private helpers
  
  defp generate_id() do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  # Simple type-based processing for demonstration
  defp process_by_type(:visual, %{type: :visual} = input) do
    # For visual inputs, extract features like color, shape, position
    confidence = 0.8 # High confidence for matching type
    
    # Extract some basic data
    extracted_data = %{
      color: Map.get(input, :color, :unknown),
      position: Map.get(input, :position, {0, 0, 0}),
      size: Map.get(input, :size, :medium)
    }
    
    {confidence, extracted_data}
  end
  
  defp process_by_type(:audio, %{type: :audio} = input) do
    # For audio inputs, extract features like volume, frequency, duration
    confidence = 0.8
    
    extracted_data = %{
      volume: Map.get(input, :volume, 0),
      frequency: Map.get(input, :frequency, []),
      duration: Map.get(input, :duration, 0)
    }
    
    {confidence, extracted_data}
  end
  
  defp process_by_type(:text, %{type: :text} = input) do
    # For text inputs, extract the content
    confidence = 0.9
    
    extracted_data = %{
      content: Map.get(input, :content, ""),
      length: String.length(Map.get(input, :content, ""))
    }
    
    {confidence, extracted_data}
  end
  
  defp process_by_type(_type, _input) do
    # Default case for unrecognized types
    {0.1, %{}}
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automata.Perceptory.Percept
      
      @percept_type Keyword.get(unquote(opts), :type, :generic)
      @confidence_threshold Keyword.get(unquote(opts), :confidence_threshold, 0.5)
      
      def process(sensory_input) do
        # Override this in specific percept implementations
        Percept.process(%Percept{
          type: @percept_type,
          confidence_threshold: @confidence_threshold
        }, sensory_input)
      end
      
      defoverridable process: 1
    end
  end
end