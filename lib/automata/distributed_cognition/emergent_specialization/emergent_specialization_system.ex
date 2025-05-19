defmodule Automata.DistributedCognition.EmergentSpecialization.EmergentSpecializationSystem do
  @moduledoc """
  Main entry point for the Emergent Specialization Framework.
  
  This module integrates the capability profiling, role adaptation, and specialization
  emergence components into a cohesive system for managing emergent specialization
  in distributed agent systems.
  """
  
  use GenServer
  
  alias Automata.DistributedCognition.EmergentSpecialization.CapabilityProfiling
  alias Automata.DistributedCognition.EmergentSpecialization.RoleAdaptation
  alias Automata.DistributedCognition.EmergentSpecialization.SpecializationEmergence
  alias Automata.DistributedCognition.BeliefArchitecture.DecentralizedBeliefSystem
  
  # Client API
  
  @doc """
  Starts the Emergent Specialization System.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Creates a capability profile for an agent.
  """
  def create_capability_profile(server \\ __MODULE__, agent_id, initial_capabilities \\ %{}) do
    GenServer.call(server, {:create_capability_profile, agent_id, initial_capabilities})
  end
  
  @doc """
  Records a performance event for an agent's capability.
  """
  def record_performance_event(server \\ __MODULE__, agent_id, capability_id, event_data) do
    GenServer.call(server, {:record_performance_event, agent_id, capability_id, event_data})
  end
  
  @doc """
  Creates a new role in the system.
  """
  def create_role(server \\ __MODULE__, id, name, description, opts \\ []) do
    GenServer.call(server, {:create_role, id, name, description, opts})
  end
  
  @doc """
  Assigns a role to an agent.
  """
  def assign_role(server \\ __MODULE__, agent_id, role_id, opts \\ []) do
    GenServer.call(server, {:assign_role, agent_id, role_id, opts})
  end
  
  @doc """
  Finds the best role for an agent.
  """
  def find_best_role(server \\ __MODULE__, agent_id) do
    GenServer.call(server, {:find_best_role, agent_id})
  end
  
  @doc """
  Records feedback on an agent's performance in a role.
  """
  def record_feedback(server \\ __MODULE__, agent_id, role_id, source, feedback_data) do
    GenServer.call(server, {:record_feedback, agent_id, role_id, source, feedback_data})
  end
  
  @doc """
  Detects potential specialization patterns.
  """
  def detect_specialization_patterns(server \\ __MODULE__, agent_ids, opts \\ []) do
    GenServer.call(server, {:detect_specialization_patterns, agent_ids, opts})
  end
  
  @doc """
  Reinforces an emerging specialization pattern.
  """
  def reinforce_specialization(server \\ __MODULE__, pattern_id, agent_ids, pressure_level \\ 0.5) do
    GenServer.call(server, {:reinforce_specialization, pattern_id, agent_ids, pressure_level})
  end
  
  @doc """
  Identifies complementary specialization patterns.
  """
  def identify_complementary_patterns(server \\ __MODULE__) do
    GenServer.call(server, :identify_complementary_patterns)
  end
  
  @doc """
  Ensures diversity of specializations across the agent population.
  """
  def ensure_specialization_diversity(server \\ __MODULE__, min_coverage \\ 0.8) do
    GenServer.call(server, {:ensure_specialization_diversity, min_coverage})
  end
  
  @doc """
  Adapts the system's organizational structure to support emerging specializations.
  """
  def adapt_organization(server \\ __MODULE__) do
    GenServer.call(server, :adapt_organization)
  end
  
  @doc """
  Runs a comprehensive specialization cycle.
  """
  def run_specialization_cycle(server \\ __MODULE__, opts \\ []) do
    GenServer.call(server, {:run_specialization_cycle, opts})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    # Initialize with default config
    initial_state = %{
      capability_profiles: %{},
      roles: %{},
      role_assignments: %{},
      specialization_patterns: %{},
      performance_events: [],
      feedback_records: [],
      reinforcement_records: [],
      current_structure: %{},
      current_allocation: %{},
      current_pathways: %{},
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic detection if enabled
    if initial_state.config.periodic_detection_enabled do
      schedule_periodic_detection(initial_state.config.detection_interval)
    end
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_capability_profile, agent_id, initial_capabilities}, _from, state) do
    # Create profile
    profile = CapabilityProfiling.CapabilityProfile.new(agent_id, initial_capabilities)
    
    # Update state
    updated_profiles = Map.put(state.capability_profiles, agent_id, profile)
    
    {:reply, {:ok, profile}, %{state | capability_profiles: updated_profiles}}
  end
  
  @impl true
  def handle_call({:record_performance_event, agent_id, capability_id, event_data}, _from, state) do
    # Get the agent's profile
    case Map.fetch(state.capability_profiles, agent_id) do
      {:ok, profile} ->
        # Extract performance metrics from event data
        metrics = extract_performance_metrics(capability_id, event_data)
        
        # Update the profile
        updated_profile = CapabilityProfiling.CapabilityProfile.update_capability(
          profile,
          capability_id,
          metrics
        )
        
        # Update state
        updated_profiles = Map.put(state.capability_profiles, agent_id, updated_profile)
        updated_events = [
          %{agent_id: agent_id, capability_id: capability_id, metrics: metrics, timestamp: DateTime.utc_now()}
          | state.performance_events
        ]
        
        {:reply, {:ok, updated_profile}, %{
          state |
          capability_profiles: updated_profiles,
          performance_events: updated_events
        }}
        
      :error ->
        # Profile doesn't exist, create it
        profile = CapabilityProfiling.CapabilityProfile.new(agent_id)
        
        # Extract performance metrics
        metrics = extract_performance_metrics(capability_id, event_data)
        
        # Update with capability
        updated_profile = CapabilityProfiling.CapabilityProfile.update_capability(
          profile,
          capability_id,
          metrics
        )
        
        # Update state
        updated_profiles = Map.put(state.capability_profiles, agent_id, updated_profile)
        updated_events = [
          %{agent_id: agent_id, capability_id: capability_id, metrics: metrics, timestamp: DateTime.utc_now()}
          | state.performance_events
        ]
        
        {:reply, {:ok, updated_profile}, %{
          state |
          capability_profiles: updated_profiles,
          performance_events: updated_events
        }}
    end
  end
  
  @impl true
  def handle_call({:create_role, id, name, description, opts}, _from, state) do
    # Create role
    role = RoleAdaptation.Role.new(id, name, description, opts)
    
    # Update state
    updated_roles = Map.put(state.roles, id, role)
    
    {:reply, {:ok, role}, %{state | roles: updated_roles}}
  end
  
  @impl true
  def handle_call({:assign_role, agent_id, role_id, opts}, _from, state) do
    # Get the role
    case Map.fetch(state.roles, role_id) do
      {:ok, role} ->
        # Get the agent's capability profile
        case Map.fetch(state.capability_profiles, agent_id) do
          {:ok, profile} ->
            # Calculate fit score
            fit_score = RoleAdaptation.Role.calculate_fit(role, profile)
            
            # Create assignment
            assignment = %{
              agent_id: agent_id,
              role_id: role_id,
              fit_score: fit_score,
              assigned_at: DateTime.utc_now(),
              assigned_until: Keyword.get(opts, :duration) && 
                              DateTime.add(DateTime.utc_now(), Keyword.get(opts, :duration), :second),
              status: :active
            }
            
            # Update state
            updated_assignments = Map.put(state.role_assignments, agent_id, assignment)
            
            {:reply, {:ok, assignment}, %{state | role_assignments: updated_assignments}}
            
          :error ->
            # No capability profile, create a default one
            profile = CapabilityProfiling.CapabilityProfile.new(agent_id)
            
            # Calculate fit score
            fit_score = RoleAdaptation.Role.calculate_fit(role, profile)
            
            # Create assignment
            assignment = %{
              agent_id: agent_id,
              role_id: role_id,
              fit_score: fit_score,
              assigned_at: DateTime.utc_now(),
              assigned_until: Keyword.get(opts, :duration) && 
                              DateTime.add(DateTime.utc_now(), Keyword.get(opts, :duration), :second),
              status: :active
            }
            
            # Update state
            updated_profiles = Map.put(state.capability_profiles, agent_id, profile)
            updated_assignments = Map.put(state.role_assignments, agent_id, assignment)
            
            {:reply, {:ok, assignment}, %{
              state |
              capability_profiles: updated_profiles,
              role_assignments: updated_assignments
            }}
        end
        
      :error ->
        # Role doesn't exist
        {:reply, {:error, :role_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:find_best_role, agent_id}, _from, state) do
    # Get the agent's capability profile
    case Map.fetch(state.capability_profiles, agent_id) do
      {:ok, profile} ->
        # Calculate fit for each role
        role_fits = Enum.map(state.roles, fn {_id, role} ->
          fit = RoleAdaptation.Role.calculate_fit(role, profile)
          {role, fit}
        end)
        
        # Find the best fit
        if Enum.empty?(role_fits) do
          {:reply, {:error, :no_roles_available}, state}
        else
          {best_role, best_fit} = Enum.max_by(role_fits, fn {_role, fit} -> fit end)
          
          if best_fit > 0.7 do  # Threshold for acceptable fit
            {:reply, {:ok, best_role, best_fit}, state}
          else
            {:reply, {:error, :no_suitable_role}, state}
          end
        end
        
      :error ->
        # No capability profile
        {:reply, {:error, :profile_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:record_feedback, agent_id, role_id, source, feedback_data}, _from, state) do
    # Process feedback
    processed_feedback = process_feedback(feedback_data)
    
    # Create feedback record
    feedback_record = %{
      agent_id: agent_id,
      role_id: role_id,
      source: source,
      feedback: processed_feedback,
      timestamp: DateTime.utc_now()
    }
    
    # Update state
    updated_feedback = [feedback_record | state.feedback_records]
    
    {:reply, {:ok, feedback_record}, %{state | feedback_records: updated_feedback}}
  end
  
  @impl true
  def handle_call({:detect_specialization_patterns, agent_ids, opts}, _from, state) do
    # Get capability profiles for specified agents
    agent_profiles = Enum.reduce(agent_ids, %{}, fn agent_id, acc ->
      case Map.fetch(state.capability_profiles, agent_id) do
        {:ok, profile} ->
          Map.put(acc, agent_id, profile)
          
        :error ->
          # Skip agents without profiles
          acc
      end
    end)
    
    # Detect patterns
    {:ok, patterns} = SpecializationEmergence.SpecializationDetection.comprehensive_detection(
      Map.keys(agent_profiles),
      opts
    )
    
    # Update state with new patterns
    updated_patterns = Enum.reduce(patterns, state.specialization_patterns, fn pattern, acc ->
      Map.put(acc, pattern.id, pattern)
    end)
    
    {:reply, {:ok, patterns}, %{state | specialization_patterns: updated_patterns}}
  end
  
  @impl true
  def handle_call({:reinforce_specialization, pattern_id, agent_ids, pressure_level}, _from, state) do
    # Get the pattern
    case Map.fetch(state.specialization_patterns, pattern_id) do
      {:ok, pattern} ->
        # Apply selective pressure
        results = SpecializationEmergence.SpecializationReinforcement.apply_selective_pressure(
          pattern,
          agent_ids,
          pressure_level
        )
        
        # Record reinforcement
        reinforcement_record = %{
          pattern_id: pattern_id,
          agent_ids: agent_ids,
          pressure_level: pressure_level,
          results: results,
          timestamp: DateTime.utc_now()
        }
        
        # Update state
        updated_records = [reinforcement_record | state.reinforcement_records]
        
        {:reply, {:ok, results}, %{state | reinforcement_records: updated_records}}
        
      :error ->
        # Pattern doesn't exist
        {:reply, {:error, :pattern_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:identify_complementary_patterns, _from, state) do
    # Get all patterns
    patterns = Map.values(state.specialization_patterns)
    
    # Identify complementary patterns
    {:ok, complementary_groups} = SpecializationEmergence.ComplementarySpecialization.identify_complementary_patterns(
      patterns
    )
    
    # Update patterns with complementary information
    updated_patterns = Enum.reduce(complementary_groups, state.specialization_patterns, fn group, acc ->
      # For each pattern in the group, update its complementary_patterns list
      Enum.reduce(group, acc, fn pattern, inner_acc ->
        # Get other patterns in this group
        other_patterns = Enum.reject(group, fn p -> p.id == pattern.id end)
        other_ids = Enum.map(other_patterns, & &1.id)
        
        # Get current pattern from state
        current = Map.get(inner_acc, pattern.id)
        
        if current do
          # Update complementary patterns
          updated = SpecializationEmergence.SpecializationPattern.update(current, %{
            complementary_patterns: other_ids
          })
          
          Map.put(inner_acc, pattern.id, updated)
        else
          # Pattern not in state, ignore
          inner_acc
        end
      end)
    end)
    
    {:reply, {:ok, complementary_groups}, %{state | specialization_patterns: updated_patterns}}
  end
  
  @impl true
  def handle_call({:ensure_specialization_diversity, min_coverage}, _from, state) do
    # Get all patterns and agents
    patterns = Map.values(state.specialization_patterns)
    agents = Map.keys(state.capability_profiles)
    
    # Ensure diversity
    result = SpecializationEmergence.ComplementarySpecialization.ensure_specialization_diversity(
      patterns,
      agents,
      min_coverage
    )
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:adapt_organization, _from, state) do
    # Get all patterns
    patterns = Map.values(state.specialization_patterns)
    
    # Adapt organization
    {:ok, adaptations} = SpecializationEmergence.SystemAdaptation.adapt_organization(
      patterns,
      state.current_structure
    )
    
    # Apply adaptations to structure
    new_structure = apply_structure_adaptations(state.current_structure, adaptations)
    
    {:reply, {:ok, adaptations}, %{state | current_structure: new_structure}}
  end
  
  @impl true
  def handle_call({:run_specialization_cycle, opts}, _from, state) do
    # Get all agents
    agent_ids = Map.keys(state.capability_profiles)
    
    # 1. Detect specialization patterns
    detection_opts = Keyword.get(opts, :detection_opts, [])
    {:ok, patterns} = SpecializationEmergence.SpecializationDetection.comprehensive_detection(
      agent_ids,
      detection_opts
    )
    
    # Update state with new patterns
    updated_patterns = Enum.reduce(patterns, state.specialization_patterns, fn pattern, acc ->
      Map.put(acc, pattern.id, pattern)
    end)
    
    # 2. Identify complementary patterns
    all_patterns = Map.values(updated_patterns)
    {:ok, complementary_groups} = SpecializationEmergence.ComplementarySpecialization.identify_complementary_patterns(
      all_patterns
    )
    
    # 3. Ensure specialization diversity
    min_coverage = Keyword.get(opts, :min_coverage, 0.8)
    SpecializationEmergence.ComplementarySpecialization.ensure_specialization_diversity(
      all_patterns,
      agent_ids,
      min_coverage
    )
    
    # 4. Reinforce patterns
    pressure_level = Keyword.get(opts, :pressure_level, 0.5)
    reinforcement_results = Enum.map(patterns, fn pattern ->
      # Apply selective pressure
      results = SpecializationEmergence.SpecializationReinforcement.apply_selective_pressure(
        pattern,
        agent_ids,
        pressure_level
      )
      
      {pattern.id, results}
    end)
    |> Enum.into(%{})
    
    # 5. Create roles from patterns
    role_results = SpecializationEmergence.SpecializationReinforcement.create_roles_from_patterns(
      all_patterns,
      0.7
    )
    
    # Update roles in state
    updated_roles = Enum.reduce(role_results, state.roles, fn result, acc ->
      case result do
        {:created, role} ->
          Map.put(acc, role.id, role)
          
        {:adapted, role} ->
          Map.put(acc, role.id, role)
      end
    end)
    
    # 6. Adapt organization if needed
    organization_threshold = Keyword.get(opts, :organization_threshold, 0.8)
    organization_needs_update = Enum.any?(patterns, fn pattern ->
      pattern.emergence_score >= organization_threshold &&
      pattern.stability >= organization_threshold
    end)
    
    updated_structure = if organization_needs_update do
      {:ok, adaptations} = SpecializationEmergence.SystemAdaptation.adapt_organization(
        all_patterns,
        state.current_structure
      )
      
      apply_structure_adaptations(state.current_structure, adaptations)
    else
      state.current_structure
    end
    
    # 7. Record cycle results
    cycle_record = %{
      timestamp: DateTime.utc_now(),
      patterns_detected: length(patterns),
      complementary_groups: length(complementary_groups),
      reinforcement_results: reinforcement_results,
      roles_created: Enum.count(role_results, fn r -> elem(r, 0) == :created end),
      roles_adapted: Enum.count(role_results, fn r -> elem(r, 0) == :adapted end),
      organization_updated: organization_needs_update
    }
    
    # Return cycle results and update state
    {:reply, {:ok, cycle_record}, %{
      state |
      specialization_patterns: updated_patterns,
      roles: updated_roles,
      current_structure: updated_structure
    }}
  end
  
  @impl true
  def handle_info(:run_periodic_detection, state) do
    # Get all agents
    agent_ids = Map.keys(state.capability_profiles)
    
    if length(agent_ids) > 0 do
      # Run detection
      {:ok, patterns} = SpecializationEmergence.SpecializationDetection.comprehensive_detection(
        agent_ids,
        []
      )
      
      # Update state with new patterns
      updated_patterns = Enum.reduce(patterns, state.specialization_patterns, fn pattern, acc ->
        Map.put(acc, pattern.id, pattern)
      end)
      
      # Schedule next detection
      schedule_periodic_detection(state.config.detection_interval)
      
      {:noreply, %{state | specialization_patterns: updated_patterns}}
    else
      # No agents, just reschedule
      schedule_periodic_detection(state.config.detection_interval)
      
      {:noreply, state}
    end
  end
  
  # Private functions
  
  defp default_config do
    %{
      # Capability profiling
      min_capability_performance: 0.7,
      performance_history_limit: 10,
      
      # Role adaptation
      min_role_fit: 0.7,
      role_adaptation_rate: 0.3,
      
      # Specialization detection
      detection_threshold: 0.7,
      periodic_detection_enabled: true,
      detection_interval: 60_000,  # 1 minute
      
      # Specialization reinforcement
      default_pressure_level: 0.5,
      
      # System adaptation
      organization_update_threshold: 0.8
    }
  end
  
  defp extract_performance_metrics(capability_id, event_data) do
    # Extract metrics from event data
    # Default values ensure we have all required metrics
    %{
      efficiency: Map.get(event_data, :efficiency, 0.7),
      quality: Map.get(event_data, :quality, 0.7),
      reliability: Map.get(event_data, :reliability, 0.8),
      latency: Map.get(event_data, :latency, 0.3)
    }
  end
  
  defp process_feedback(feedback_data) do
    # Ensure all required fields are present with default values
    required_fields = [:performance, :satisfaction, :fit]
    
    Enum.reduce(required_fields, feedback_data, fn field, acc ->
      Map.put_new(acc, field, 0.5)  # Default value
    end)
  end
  
  defp apply_structure_adaptations(current_structure, adaptations) do
    # Apply each adaptation to the structure
    Enum.reduce(adaptations, current_structure, fn adaptation, structure ->
      case adaptation.type do
        :add_component ->
          # Add component to structure
          components = Map.get(structure, :components, [])
          
          Map.put(
            structure,
            :components,
            [adaptation.component | components]
          )
          
        :modify_hierarchy ->
          # Modify hierarchy in structure
          hierarchy = Map.get(structure, :hierarchy, %{})
          
          # Apply hierarchy changes
          updated_hierarchy = Enum.reduce(adaptation.changes, hierarchy, fn change, h ->
            case change do
              {add_role_level, level} ->
                # Add role level to hierarchy
                levels = Map.get(h, :levels, [])
                Map.put(h, :levels, [level | levels])
                
              _ ->
                # Unsupported change, ignore
                h
            end
          end)
          
          Map.put(structure, :hierarchy, updated_hierarchy)
          
        _ ->
          # Unsupported adaptation type, ignore
          structure
      end
    end)
  end
  
  defp schedule_periodic_detection(interval) do
    Process.send_after(self(), :run_periodic_detection, interval)
  end
end