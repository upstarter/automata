defmodule Automata.Perceptory.Supervisor do
  @moduledoc """
  Supervisor for the Perceptory system components.
  
  This supervisor manages the various components of the enhanced perception system,
  ensuring proper initialization, fault tolerance, and resource management.
  It coordinates the lifecycle of perception components and provides a unified
  interface for the rest of the system to interact with perception capabilities.
  """
  use Supervisor
  
  alias Automata.Perceptory
  alias Automata.Perceptory.PatternMatcher
  alias Automata.Perceptory.TemporalPattern
  alias Automata.Perceptory.AttentionController
  alias Automata.Perceptory.AssociativeMemory
  alias Automata.Perceptory.ModalityFusion
  
  @doc """
  Starts the perceptory supervisor.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    agent_id = Keyword.get(opts, :agent_id)
    
    if agent_id == nil do
      {:error, :missing_agent_id}
    else
      Supervisor.start_link(__MODULE__, {agent_id, opts}, name: name)
    end
  end
  
  @impl true
  def init({agent_id, opts}) do
    # Define configuration for each component
    perceptory_name = via_tuple(agent_id, :perceptory)
    pattern_matcher_name = via_tuple(agent_id, :pattern_matcher)
    temporal_pattern_name = via_tuple(agent_id, :temporal_pattern)
    attention_name = via_tuple(agent_id, :attention)
    associative_memory_name = via_tuple(agent_id, :associative_memory)
    modality_fusion_name = via_tuple(agent_id, :modality_fusion)
    
    children = [
      # Main Perceptory server
      %{
        id: :perceptory,
        start: {Perceptory, :start_link, [
          Keyword.merge(opts, [agent_id: agent_id, name: perceptory_name])
        ]}
      },
      
      # Pattern Matcher
      %{
        id: :pattern_matcher,
        start: {GenServer, :start_link, [
          pattern_matcher_worker(agent_id, opts),
          pattern_matcher_name
        ]}
      },
      
      # Temporal Pattern Detector
      %{
        id: :temporal_pattern,
        start: {GenServer, :start_link, [
          temporal_pattern_worker(agent_id, opts),
          temporal_pattern_name
        ]}
      },
      
      # Attention Controller
      %{
        id: :attention,
        start: {GenServer, :start_link, [
          attention_worker(agent_id, opts),
          attention_name
        ]}
      },
      
      # Associative Memory
      %{
        id: :associative_memory,
        start: {GenServer, :start_link, [
          associative_memory_worker(agent_id, opts),
          associative_memory_name
        ]}
      },
      
      # Modality Fusion
      %{
        id: :modality_fusion,
        start: {GenServer, :start_link, [
          modality_fusion_worker(agent_id, opts),
          modality_fusion_name
        ]}
      }
    ]
    
    # Use one_for_one strategy - if a component crashes, only restart that one
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  # Helper functions for worker modules
  
  defp pattern_matcher_worker(agent_id, opts) do
    matcher_config = Keyword.get(opts, :pattern_matcher, %{})
    
    # Define the GenServer implementation
    quote do
      use GenServer
      alias Automata.Perceptory.PatternMatcher
      
      @matcher PatternMatcher.new(unquote(Macro.escape(matcher_config)))
      
      def init(_) do
        {:ok, @matcher}
      end
      
      def handle_call({:process, input}, _from, matcher) do
        {matches, updated_matcher} = PatternMatcher.process(matcher, input)
        {:reply, matches, updated_matcher}
      end
      
      def handle_call({:add_pattern, pattern}, _from, matcher) do
        updated_matcher = PatternMatcher.add_pattern(matcher, pattern)
        {:reply, :ok, updated_matcher}
      end
      
      def handle_call({:add_extractor, extractor}, _from, matcher) do
        updated_matcher = PatternMatcher.add_extractor(matcher, extractor)
        {:reply, :ok, updated_matcher}
      end
      
      def handle_call(:get_state, _from, matcher) do
        {:reply, matcher, matcher}
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
  
  defp temporal_pattern_worker(agent_id, opts) do
    temporal_config = Keyword.get(opts, :temporal_pattern, %{})
    
    # Define the GenServer implementation
    quote do
      use GenServer
      alias Automata.Perceptory.TemporalPattern
      
      @detector TemporalPattern.new(unquote(Macro.escape(temporal_config)))
      
      def init(_) do
        {:ok, @detector}
      end
      
      def handle_call({:process_event, event}, _from, detector) do
        {patterns, updated_detector} = TemporalPattern.process_event(detector, event)
        {:reply, patterns, updated_detector}
      end
      
      def handle_call({:add_sequence_pattern, pattern}, _from, detector) do
        updated_detector = TemporalPattern.add_sequence_pattern(detector, pattern)
        {:reply, :ok, updated_detector}
      end
      
      def handle_call(:get_active_sequences, _from, detector) do
        active = TemporalPattern.get_active_sequences(detector)
        {:reply, active, detector}
      end
      
      def handle_call(:get_identified_patterns, _from, detector) do
        patterns = TemporalPattern.get_identified_patterns(detector)
        {:reply, patterns, detector}
      end
      
      def handle_call(:predict_next_events, _from, detector) do
        predictions = TemporalPattern.predict_next_events(detector)
        {:reply, predictions, detector}
      end
      
      def handle_call(:get_state, _from, detector) do
        {:reply, detector, detector}
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
  
  defp attention_worker(agent_id, opts) do
    attention_config = Keyword.get(opts, :attention, %{})
    
    # Define the GenServer implementation
    quote do
      use GenServer
      alias Automata.Perceptory.AttentionController
      
      @controller AttentionController.new(unquote(Macro.escape(attention_config)))
      
      def init(_) do
        {:ok, @controller}
      end
      
      def handle_call({:update, input, context}, _from, controller) do
        {focus, updated_controller} = AttentionController.update(controller, input, context)
        {:reply, focus, updated_controller}
      end
      
      def handle_call({:set_goal, goal}, _from, controller) do
        updated_controller = AttentionController.set_goal(controller, goal)
        {:reply, :ok, updated_controller}
      end
      
      def handle_call({:direct_attention, focus}, _from, controller) do
        updated_controller = AttentionController.direct_attention(controller, focus)
        {:reply, :ok, updated_controller}
      end
      
      def handle_call(:get_attention_distribution, _from, controller) do
        distribution = AttentionController.get_attention_distribution(controller)
        {:reply, distribution, controller}
      end
      
      def handle_call({:has_attention, item_id}, _from, controller) do
        has_attention = AttentionController.has_attention?(controller, item_id)
        {:reply, has_attention, controller}
      end
      
      def handle_call(:get_state, _from, controller) do
        {:reply, controller, controller}
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
  
  defp associative_memory_worker(agent_id, opts) do
    memory_config = Keyword.get(opts, :associative_memory, %{})
    
    # Define the GenServer implementation
    quote do
      use GenServer
      alias Automata.Perceptory.AssociativeMemory
      
      @memory AssociativeMemory.new(unquote(Macro.escape(memory_config)))
      
      def init(_) do
        {:ok, @memory}
      end
      
      def handle_call({:store, memory}, _from, memory_system) do
        updated_system = AssociativeMemory.store(memory_system, memory)
        {:reply, :ok, updated_system}
      end
      
      def handle_call({:retrieve, query, max_results}, _from, memory_system) do
        {retrieved, updated_system} = AssociativeMemory.retrieve(memory_system, query, max_results)
        {:reply, retrieved, updated_system}
      end
      
      def handle_call({:associate, id1, id2, strength}, _from, memory_system) do
        updated_system = AssociativeMemory.associate(memory_system, id1, id2, strength)
        {:reply, :ok, updated_system}
      end
      
      def handle_call({:forget, memory_id}, _from, memory_system) do
        updated_system = AssociativeMemory.forget(memory_system, memory_id)
        {:reply, :ok, updated_system}
      end
      
      def handle_call({:get_activation, memory_id}, _from, memory_system) do
        activation = AssociativeMemory.get_activation(memory_system, memory_id)
        {:reply, activation, memory_system}
      end
      
      def handle_call(:get_metrics, _from, memory_system) do
        metrics = AssociativeMemory.get_metrics(memory_system)
        {:reply, metrics, memory_system}
      end
      
      def handle_call(:get_state, _from, memory_system) do
        {:reply, memory_system, memory_system}
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
  
  defp modality_fusion_worker(agent_id, opts) do
    fusion_config = Keyword.get(opts, :modality_fusion, %{})
    
    # Define the GenServer implementation
    quote do
      use GenServer
      alias Automata.Perceptory.ModalityFusion
      
      @fusion ModalityFusion.new(unquote(Macro.escape(fusion_config)))
      
      def init(_) do
        {:ok, @fusion}
      end
      
      def handle_call({:process_input, modality, data}, _from, fusion) do
        {percepts, updated_fusion} = ModalityFusion.process_input(fusion, modality, data)
        {:reply, percepts, updated_fusion}
      end
      
      def handle_call({:get_latest_fusion, fusion_type}, _from, fusion) do
        {percepts, updated_fusion} = ModalityFusion.get_latest_fusion(fusion, fusion_type)
        {:reply, percepts, updated_fusion}
      end
      
      def handle_call({:get_modality_confidence, modality}, _from, fusion) do
        confidence = ModalityFusion.get_modality_confidence(fusion, modality)
        {:reply, confidence, fusion}
      end
      
      def handle_call({:configure_modality, modality, config}, _from, fusion) do
        updated_fusion = ModalityFusion.configure_modality(fusion, modality, config)
        {:reply, :ok, updated_fusion}
      end
      
      def handle_call(:get_state, _from, fusion) do
        {:reply, fusion, fusion}
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
  
  # Helper functions for worker access
  
  def via_tuple(agent_id, component) do
    {:via, Registry, {:perceptory_registry, {agent_id, component}}}
  end
  
  @doc """
  Returns a specification for starting the perceptory registry.
  
  This registry should be started by the application supervisor.
  """
  def registry_spec do
    {Registry, keys: :unique, name: :perceptory_registry}
  end
end