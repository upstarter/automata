defmodule Automata.AdaptiveLearning.MultiAgentRL do
  @moduledoc """
  Multi-Agent Reinforcement Learning system.
  
  This module implements a framework for multi-agent reinforcement learning with
  support for coordinated exploration, experience sharing, policy fusion, and
  distributed value functions. It enables agents to collaboratively learn optimal
  policies in complex environments.
  """
  
  use GenServer
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type agent_id :: String.t()
  @type state :: any()
  @type action :: any()
  @type reward :: float()
  @type experience :: %{
    state: state(),
    action: action(),
    reward: reward(),
    next_state: state(),
    done: boolean()
  }
  
  # Client API
  
  @doc """
  Starts the Multi-Agent Reinforcement Learning system.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Registers a new learning agent.
  """
  def register_agent(agent_id, algorithm \\ :q_learning, params \\ %{}) do
    GenServer.call(__MODULE__, {:register_agent, agent_id, algorithm, params})
  end
  
  @doc """
  Records an experience tuple for an agent.
  """
  def record_experience(agent_id, experience) do
    GenServer.cast(__MODULE__, {:record_experience, agent_id, experience})
  end
  
  @doc """
  Batch records multiple experiences for an agent.
  """
  def record_experiences(agent_id, experiences) when is_list(experiences) do
    GenServer.cast(__MODULE__, {:record_experiences, agent_id, experiences})
  end
  
  @doc """
  Gets the best action for a state according to the agent's policy.
  """
  def get_action(agent_id, state, epsilon \\ 0.1) do
    GenServer.call(__MODULE__, {:get_action, agent_id, state, epsilon})
  end
  
  @doc """
  Updates an agent's value function/policy based on collected experiences.
  """
  def update(agent_id, params \\ %{}) do
    GenServer.call(__MODULE__, {:update, agent_id, params})
  end
  
  @doc """
  Triggers synchronization of experience and policies among agents.
  """
  def synchronize(group_id \\ :all) do
    GenServer.cast(__MODULE__, {:synchronize, group_id})
  end
  
  @doc """
  Retrieves metrics and performance statistics for an agent.
  """
  def get_agent_metrics(agent_id) do
    GenServer.call(__MODULE__, {:get_agent_metrics, agent_id})
  end
  
  @doc """
  Gets the current policy for an agent.
  """
  def get_policy(agent_id) do
    GenServer.call(__MODULE__, {:get_policy, agent_id})
  end
  
  @doc """
  Gets information about all registered agents.
  """
  def list_agents do
    GenServer.call(__MODULE__, :list_agents)
  end
  
  @doc """
  Creates a joint policy from multiple agents.
  """
  def create_joint_policy(agent_ids) when is_list(agent_ids) do
    GenServer.call(__MODULE__, {:create_joint_policy, agent_ids})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Extract configuration options
    environment = Keyword.get(opts, :environment, %{})
    knowledge_context = Keyword.get(opts, :knowledge_context)
    experience_sharing = Keyword.get(opts, :experience_sharing, true)
    coordination_strategy = Keyword.get(opts, :coordination_strategy, :independent)
    sync_interval = Keyword.get(opts, :sync_interval, 1000)
    
    # Setup knowledge system integration if context provided
    knowledge_system = 
      if knowledge_context do
        {:ok, ks} = KnowledgeSystem.start_link()
        ks
      else
        nil
      end
    
    # Setup periodic synchronization
    if experience_sharing do
      schedule_sync(sync_interval)
    end
    
    # Initialize state
    state = %{
      agents: %{},
      environment: environment,
      knowledge_system: knowledge_system,
      knowledge_context: knowledge_context,
      experience_sharing: experience_sharing,
      coordination_strategy: coordination_strategy,
      sync_interval: sync_interval,
      shared_experiences: [],
      metrics: %{
        updates: 0,
        experiences: 0,
        synchronizations: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_agent, agent_id, algorithm, params}, _from, state) do
    # Check if agent already exists
    if Map.has_key?(state.agents, agent_id) do
      {:reply, {:error, :already_registered}, state}
    else
      # Create new agent
      new_agent = create_agent(algorithm, params, state)
      
      # Add to agents map
      updated_agents = Map.put(state.agents, agent_id, new_agent)
      
      {:reply, {:ok, agent_id}, %{state | agents: updated_agents}}
    end
  end
  
  @impl true
  def handle_call({:get_action, agent_id, state_input, epsilon}, _from, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        # Get action based on agent's algorithm
        {action, updated_agent} = select_action(agent, state_input, epsilon)
        
        # Update agent
        updated_agents = Map.put(state.agents, agent_id, updated_agent)
        
        {:reply, {:ok, action}, %{state | agents: updated_agents}}
        
      :error ->
        {:reply, {:error, :agent_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:update, agent_id, params}, _from, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        # Update agent's value function/policy
        case update_agent(agent, params) do
          {:ok, updated_agent, metrics} ->
            # Update agent and metrics
            updated_agents = Map.put(state.agents, agent_id, updated_agent)
            updated_metrics = %{state.metrics | updates: state.metrics.updates + 1}
            
            {:reply, {:ok, metrics}, %{state | agents: updated_agents, metrics: updated_metrics}}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
        
      :error ->
        {:reply, {:error, :agent_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:get_agent_metrics, agent_id}, _from, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        {:reply, {:ok, agent.metrics}, state}
        
      :error ->
        {:reply, {:error, :agent_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:get_policy, agent_id}, _from, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        {:reply, {:ok, agent.policy}, state}
        
      :error ->
        {:reply, {:error, :agent_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:list_agents, _from, state) do
    # Create summaries of all agents
    agent_summaries = 
      Enum.map(state.agents, fn {id, agent} ->
        %{
          id: id,
          algorithm: agent.algorithm,
          experiences: length(agent.experience_buffer),
          last_updated: agent.last_updated
        }
      end)
      
    {:reply, {:ok, agent_summaries}, state}
  end
  
  @impl true
  def handle_call({:create_joint_policy, agent_ids}, _from, state) do
    # Validate that all agents exist
    agents = 
      Enum.reduce_while(agent_ids, [], fn id, acc ->
        case Map.fetch(state.agents, id) do
          {:ok, agent} -> {:cont, [agent | acc]}
          :error -> {:halt, :error}
        end
      end)
      
    case agents do
      :error ->
        {:reply, {:error, :agent_not_found}, state}
        
      agents_list ->
        # Create joint policy using policy fusion
        joint_policy = create_fused_policy(agents_list, state.coordination_strategy)
        
        # Store in knowledge system if available
        if state.knowledge_system != nil do
          KnowledgeSystem.create_frame(
            "joint_policy_#{Enum.join(agent_ids, "_")}",
            %{
              type: :policy,
              agents: agent_ids,
              policy: joint_policy,
              created_at: DateTime.utc_now()
            }
          )
        end
        
        {:reply, {:ok, joint_policy}, state}
    end
  end
  
  @impl true
  def handle_cast({:record_experience, agent_id, experience}, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        # Add experience to agent's buffer
        updated_experience_buffer = [experience | agent.experience_buffer]
        
        # Update agent
        updated_agent = %{agent | 
          experience_buffer: updated_experience_buffer,
          metrics: %{agent.metrics | 
            total_experiences: agent.metrics.total_experiences + 1,
            total_reward: agent.metrics.total_reward + experience.reward
          }
        }
        
        # Add to shared experiences if sharing is enabled
        updated_shared_experiences = 
          if state.experience_sharing do
            # Tag with source agent
            tagged_experience = Map.put(experience, :source_agent, agent_id)
            [tagged_experience | state.shared_experiences]
          else
            state.shared_experiences
          end
        
        # Update agent and metrics
        updated_agents = Map.put(state.agents, agent_id, updated_agent)
        updated_metrics = %{state.metrics | experiences: state.metrics.experiences + 1}
        
        {:noreply, %{state | 
          agents: updated_agents, 
          shared_experiences: updated_shared_experiences,
          metrics: updated_metrics
        }}
        
      :error ->
        # Agent not found, ignore
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:record_experiences, agent_id, experiences}, state) do
    # Check if agent exists
    case Map.fetch(state.agents, agent_id) do
      {:ok, agent} ->
        # Add experiences to agent's buffer
        updated_experience_buffer = experiences ++ agent.experience_buffer
        
        # Calculate total reward
        total_reward = Enum.reduce(experiences, 0, fn exp, acc -> acc + exp.reward end)
        
        # Update agent
        updated_agent = %{agent | 
          experience_buffer: updated_experience_buffer,
          metrics: %{agent.metrics | 
            total_experiences: agent.metrics.total_experiences + length(experiences),
            total_reward: agent.metrics.total_reward + total_reward
          }
        }
        
        # Add to shared experiences if sharing is enabled
        updated_shared_experiences = 
          if state.experience_sharing do
            # Tag with source agent
            tagged_experiences = 
              Enum.map(experiences, fn exp -> Map.put(exp, :source_agent, agent_id) end)
            
            tagged_experiences ++ state.shared_experiences
          else
            state.shared_experiences
          end
        
        # Update agent and metrics
        updated_agents = Map.put(state.agents, agent_id, updated_agent)
        updated_metrics = %{state.metrics | experiences: state.metrics.experiences + length(experiences)}
        
        {:noreply, %{state | 
          agents: updated_agents, 
          shared_experiences: updated_shared_experiences,
          metrics: updated_metrics
        }}
        
      :error ->
        # Agent not found, ignore
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:synchronize, group_id}, state) do
    # Skip if no experience sharing
    if not state.experience_sharing do
      {:noreply, state}
    else
      # Synchronize experiences and policies among agents
      {updated_agents, updated_shared_experiences} = synchronize_agents(
        state.agents, 
        state.shared_experiences, 
        group_id, 
        state.coordination_strategy
      )
      
      # Update metrics
      updated_metrics = %{state.metrics | 
        synchronizations: state.metrics.synchronizations + 1
      }
      
      {:noreply, %{state | 
        agents: updated_agents, 
        shared_experiences: updated_shared_experiences,
        metrics: updated_metrics
      }}
    end
  end
  
  @impl true
  def handle_info(:sync, state) do
    # Perform periodic synchronization
    {updated_agents, updated_shared_experiences} = synchronize_agents(
      state.agents, 
      state.shared_experiences, 
      :all, 
      state.coordination_strategy
    )
    
    # Update metrics
    updated_metrics = %{state.metrics | 
      synchronizations: state.metrics.synchronizations + 1
    }
    
    # Schedule next sync
    schedule_sync(state.sync_interval)
    
    {:noreply, %{state | 
      agents: updated_agents, 
      shared_experiences: updated_shared_experiences,
      metrics: updated_metrics
    }}
  end
  
  # Private Helper Functions
  
  defp create_agent(algorithm, params, state) do
    # Create new agent based on algorithm type
    base_agent = %{
      algorithm: algorithm,
      params: params,
      policy: %{},
      value_function: %{},
      experience_buffer: [],
      exploration_strategy: Map.get(params, :exploration_strategy, :epsilon_greedy),
      learning_rate: Map.get(params, :learning_rate, 0.1),
      discount_factor: Map.get(params, :discount_factor, 0.9),
      last_updated: DateTime.utc_now(),
      created_at: DateTime.utc_now(),
      metrics: %{
        total_experiences: 0,
        total_updates: 0,
        total_reward: 0,
        average_reward: 0,
        performance_trend: []
      }
    }
    
    # Add algorithm-specific components
    case algorithm do
      :q_learning ->
        # For Q-learning, add Q-table
        Map.merge(base_agent, %{
          q_table: %{},
          learning_rate: Map.get(params, :learning_rate, 0.1),
          discount_factor: Map.get(params, :discount_factor, 0.9)
        })
        
      :sarsa ->
        # For SARSA, add Q-table and eligibility traces
        Map.merge(base_agent, %{
          q_table: %{},
          eligibility_traces: %{},
          lambda: Map.get(params, :lambda, 0.9),
          learning_rate: Map.get(params, :learning_rate, 0.1),
          discount_factor: Map.get(params, :discount_factor, 0.9)
        })
        
      :dqn ->
        # For DQN, add neural network parameters
        Map.merge(base_agent, %{
          network_params: Map.get(params, :network_params, %{}),
          target_network_params: Map.get(params, :network_params, %{}),
          target_update_frequency: Map.get(params, :target_update_frequency, 100),
          batch_size: Map.get(params, :batch_size, 32),
          learning_rate: Map.get(params, :learning_rate, 0.001)
        })
        
      :actor_critic ->
        # For Actor-Critic, add actor and critic parameters
        Map.merge(base_agent, %{
          actor_params: Map.get(params, :actor_params, %{}),
          critic_params: Map.get(params, :critic_params, %{}),
          actor_learning_rate: Map.get(params, :actor_learning_rate, 0.001),
          critic_learning_rate: Map.get(params, :critic_learning_rate, 0.005)
        })
        
      :maddpg ->
        # For Multi-Agent DDPG, add additional parameters
        Map.merge(base_agent, %{
          actor_params: Map.get(params, :actor_params, %{}),
          critic_params: Map.get(params, :critic_params, %{}),
          target_actor_params: Map.get(params, :actor_params, %{}),
          target_critic_params: Map.get(params, :critic_params, %{}),
          action_dimension: Map.get(params, :action_dimension, 1),
          actor_learning_rate: Map.get(params, :actor_learning_rate, 0.001),
          critic_learning_rate: Map.get(params, :critic_learning_rate, 0.005),
          tau: Map.get(params, :tau, 0.01)  # Soft update parameter
        })
        
      _ ->
        # Default for unknown algorithms
        base_agent
    end
  end
  
  defp select_action(agent, state_input, epsilon) do
    case agent.algorithm do
      :q_learning ->
        select_q_learning_action(agent, state_input, epsilon)
        
      :sarsa ->
        select_sarsa_action(agent, state_input, epsilon)
        
      :dqn ->
        select_dqn_action(agent, state_input, epsilon)
        
      :actor_critic ->
        select_actor_critic_action(agent, state_input, epsilon)
        
      :maddpg ->
        select_maddpg_action(agent, state_input, epsilon)
        
      _ ->
        # Default random action
        {random_action(agent, state_input), agent}
    end
  end
  
  defp select_q_learning_action(agent, state_input, epsilon) do
    # Get state key (serialize state if needed)
    state_key = serialize_state(state_input)
    
    # Get available actions for this state
    available_actions = get_available_actions(agent, state_input)
    
    # Epsilon-greedy exploration
    if :rand.uniform() < epsilon do
      # Random action
      action = Enum.random(available_actions)
      {action, agent}
    else
      # Get Q-values for this state
      q_values = get_q_values(agent, state_key, available_actions)
      
      # Find action with maximum Q-value
      {action, _value} = 
        Enum.max_by(q_values, fn {_action, value} -> value end, fn -> {Enum.random(available_actions), 0} end)
      
      {action, agent}
    end
  end
  
  defp select_sarsa_action(agent, state_input, epsilon) do
    # Similar to Q-learning
    select_q_learning_action(agent, state_input, epsilon)
  end
  
  defp select_dqn_action(agent, state_input, epsilon) do
    # For DQN, we'd use the neural network to compute Q-values
    # This is a simplified version that just uses the existing policy
    
    # Get available actions for this state
    available_actions = get_available_actions(agent, state_input)
    
    # Epsilon-greedy exploration
    if :rand.uniform() < epsilon do
      # Random action
      action = Enum.random(available_actions)
      {action, agent}
    else
      # Get state representation
      state_key = serialize_state(state_input)
      
      # Use policy if available
      case Map.get(agent.policy, state_key) do
        nil ->
          # No policy yet, random action
          action = Enum.random(available_actions)
          {action, agent}
          
        action ->
          # Use policy action
          {action, agent}
      end
    end
  end
  
  defp select_actor_critic_action(agent, state_input, epsilon) do
    # For Actor-Critic, we'd use the actor network
    # This is a simplified version
    
    # Get available actions for this state
    available_actions = get_available_actions(agent, state_input)
    
    # Use policy with some exploration noise
    if :rand.uniform() < epsilon do
      # Random action
      action = Enum.random(available_actions)
      {action, agent}
    else
      # Get state representation
      state_key = serialize_state(state_input)
      
      # Use policy if available
      case Map.get(agent.policy, state_key) do
        nil ->
          # No policy yet, random action
          action = Enum.random(available_actions)
          {action, agent}
          
        action ->
          # Use policy action
          {action, agent}
      end
    end
  end
  
  defp select_maddpg_action(agent, state_input, epsilon) do
    # Similar to Actor-Critic
    select_actor_critic_action(agent, state_input, epsilon)
  end
  
  defp random_action(agent, state_input) do
    # Get available actions and select one randomly
    available_actions = get_available_actions(agent, state_input)
    Enum.random(available_actions)
  end
  
  defp get_available_actions(agent, state_input) do
    # If agent specifies valid actions, use those
    case agent.params do
      %{valid_actions: actions} when is_function(actions, 1) ->
        # Function that returns valid actions for a state
        actions.(state_input)
        
      %{valid_actions: actions} when is_list(actions) ->
        # Static list of valid actions
        actions
        
      _ ->
        # Default action space
        [:action1, :action2, :action3, :action4]
    end
  end
  
  defp get_q_values(agent, state_key, available_actions) do
    # Get Q-values for all available actions in this state
    Enum.map(available_actions, fn action ->
      action_key = serialize_action(action)
      q_value = get_in(agent.q_table, [state_key, action_key]) || 0
      {action, q_value}
    end)
  end
  
  defp update_agent(agent, params) do
    # Update agent based on algorithm
    case agent.algorithm do
      :q_learning ->
        update_q_learning_agent(agent, params)
        
      :sarsa ->
        update_sarsa_agent(agent, params)
        
      :dqn ->
        update_dqn_agent(agent, params)
        
      :actor_critic ->
        update_actor_critic_agent(agent, params)
        
      :maddpg ->
        update_maddpg_agent(agent, params)
        
      _ ->
        {:error, :unsupported_algorithm}
    end
  end
  
  defp update_q_learning_agent(agent, _params) do
    # Basic Q-learning update
    # For each experience in buffer, update Q-table
    {updated_q_table, experience_count, total_delta} = 
      Enum.reduce(agent.experience_buffer, {agent.q_table, 0, 0}, fn exp, {q_table, count, total_delta} ->
        # Get state and action keys
        state_key = serialize_state(exp.state)
        action_key = serialize_action(exp.action)
        next_state_key = serialize_state(exp.next_state)
        
        # Get current Q-value
        current_q = get_in(q_table, [state_key, action_key]) || 0
        
        # Get max Q-value for next state
        next_q_values = 
          get_available_actions(agent, exp.next_state)
          |> Enum.map(fn action ->
            next_action_key = serialize_action(action)
            get_in(q_table, [next_state_key, next_action_key]) || 0
          end)
          
        max_next_q = 
          if Enum.empty?(next_q_values) do
            0
          else
            Enum.max(next_q_values)
          end
        
        # Terminal state has no future reward
        max_next_q = if exp.done, do: 0, else: max_next_q
        
        # Calculate target Q-value
        target_q = exp.reward + agent.discount_factor * max_next_q
        
        # Calculate delta
        delta = target_q - current_q
        
        # Update Q-value
        new_q = current_q + agent.learning_rate * delta
        
        # Update Q-table
        updated_q_table = 
          q_table
          |> Map.put_new(state_key, %{})
          |> put_in([state_key, action_key], new_q)
        
        {updated_q_table, count + 1, total_delta + abs(delta)}
      end)
    
    # Create policy from Q-table
    policy = 
      Enum.reduce(updated_q_table, %{}, fn {state, actions}, acc ->
        # Find action with maximum Q-value
        {best_action, _value} = 
          Enum.max_by(actions, fn {_action, value} -> value end, fn -> {nil, 0} end)
        
        # Add to policy if we found a best action
        if best_action != nil do
          Map.put(acc, state, best_action)
        else
          acc
        end
      end)
    
    # Clear experience buffer
    updated_agent = %{agent |
      q_table: updated_q_table,
      policy: policy,
      experience_buffer: [],
      last_updated: DateTime.utc_now(),
      metrics: %{agent.metrics |
        total_updates: agent.metrics.total_updates + 1,
        average_reward: if(experience_count > 0, do: agent.metrics.total_reward / agent.metrics.total_experiences, else: 0),
        performance_trend: agent.metrics.performance_trend ++ [agent.metrics.total_reward]
      }
    }
    
    # Return metrics
    metrics = %{
      experiences_processed: experience_count,
      total_delta: total_delta,
      average_delta: if(experience_count > 0, do: total_delta / experience_count, else: 0),
      q_table_size: map_size(updated_q_table)
    }
    
    {:ok, updated_agent, metrics}
  end
  
  defp update_sarsa_agent(agent, _params) do
    # SARSA update (similar to Q-learning but uses actual next action)
    # This implementation simplifies by treating it like Q-learning
    update_q_learning_agent(agent, %{})
  end
  
  defp update_dqn_agent(agent, _params) do
    # DQN would require neural network operations
    # This is a simplified placeholder implementation
    
    # For simplicity, just use Q-learning update
    update_q_learning_agent(agent, %{})
  end
  
  defp update_actor_critic_agent(agent, _params) do
    # Actor-Critic would require separate actor and critic updates
    # This is a simplified placeholder implementation
    
    # Just use Q-learning update for now
    update_q_learning_agent(agent, %{})
  end
  
  defp update_maddpg_agent(agent, _params) do
    # MADDPG is complex and would require centralized critic updates
    # This is a simplified placeholder implementation
    
    # Just use Q-learning update for now
    update_q_learning_agent(agent, %{})
  end
  
  defp synchronize_agents(agents, shared_experiences, group_id, coordination_strategy) do
    # Based on coordination strategy, synchronize agents
    case coordination_strategy do
      :independent ->
        # No coordination, just clear shared experiences
        {agents, []}
        
      :experience_sharing ->
        # Share experiences among agents
        updated_agents = 
          Enum.reduce(agents, agents, fn {agent_id, agent}, acc_agents ->
            # Filter experiences not from this agent
            other_experiences = 
              Enum.filter(shared_experiences, fn exp ->
                exp.source_agent != agent_id
              end)
            
            # Add filtered experiences to agent's buffer
            updated_buffer = agent.experience_buffer ++ other_experiences
            
            # Update agent
            updated_agent = %{agent | experience_buffer: updated_buffer}
            
            # Add to accumulator
            Map.put(acc_agents, agent_id, updated_agent)
          end)
        
        # Clear shared experiences after distribution
        {updated_agents, []}
        
      :policy_averaging ->
        # Average policies across agents
        avg_policy = average_policies(agents)
        
        # Update all agents with averaged policy
        updated_agents = 
          Enum.reduce(agents, agents, fn {agent_id, agent}, acc_agents ->
            updated_agent = %{agent | policy: avg_policy}
            Map.put(acc_agents, agent_id, updated_agent)
          end)
        
        {updated_agents, shared_experiences}
        
      :value_function_fusion ->
        # Combine value functions across agents
        fused_value_function = fuse_value_functions(agents)
        
        # Update all agents with fused value function
        updated_agents = 
          Enum.reduce(agents, agents, fn {agent_id, agent}, acc_agents ->
            # Only update value function (Q-table)
            updated_agent = %{agent | q_table: fused_value_function}
            
            # Recompute policy from fused value function
            updated_agent_with_policy = update_policy_from_value_function(updated_agent)
            
            Map.put(acc_agents, agent_id, updated_agent_with_policy)
          end)
        
        {updated_agents, shared_experiences}
        
      _ ->
        # Default: no coordination
        {agents, shared_experiences}
    end
  end
  
  defp average_policies(agents) do
    # Extract policies
    policies = 
      Enum.map(agents, fn {_id, agent} -> agent.policy end)
    
    # Get all unique states across policies
    all_states = 
      Enum.flat_map(policies, fn policy -> Map.keys(policy) end)
      |> Enum.uniq()
    
    # For each state, find most common action
    Enum.reduce(all_states, %{}, fn state, acc ->
      actions = 
        Enum.map(policies, fn policy -> Map.get(policy, state) end)
        |> Enum.filter(&(&1 != nil))
      
      if Enum.empty?(actions) do
        acc
      else
        # Find most frequent action
        action_counts = Enum.frequencies(actions)
        
        {most_common_action, _count} = 
          Enum.max_by(action_counts, fn {_action, count} -> count end)
        
        Map.put(acc, state, most_common_action)
      end
    end)
  end
  
  defp fuse_value_functions(agents) do
    # Extract Q-tables
    q_tables = 
      Enum.map(agents, fn {_id, agent} -> agent.q_table end)
    
    # Get all unique states across Q-tables
    all_states = 
      Enum.flat_map(q_tables, fn q_table -> Map.keys(q_table) end)
      |> Enum.uniq()
    
    # For each state, combine Q-values
    Enum.reduce(all_states, %{}, fn state, acc_states ->
      # Get all action-value maps for this state
      action_maps = 
        Enum.map(q_tables, fn q_table -> Map.get(q_table, state, %{}) end)
      
      # Get all unique actions
      all_actions = 
        Enum.flat_map(action_maps, fn action_map -> Map.keys(action_map) end)
        |> Enum.uniq()
      
      # For each action, average Q-values
      actions_q_values = 
        Enum.reduce(all_actions, %{}, fn action, acc_actions ->
          # Get all Q-values for this action
          q_values = 
            Enum.map(action_maps, fn action_map -> Map.get(action_map, action) end)
            |> Enum.filter(&(&1 != nil))
          
          if Enum.empty?(q_values) do
            acc_actions
          else
            # Average Q-values
            avg_q = Enum.sum(q_values) / length(q_values)
            
            Map.put(acc_actions, action, avg_q)
          end
        end)
      
      # Add to accumulator
      Map.put(acc_states, state, actions_q_values)
    end)
  end
  
  defp update_policy_from_value_function(agent) do
    # Create policy from Q-table
    policy = 
      Enum.reduce(agent.q_table, %{}, fn {state, actions}, acc ->
        # Find action with maximum Q-value
        {best_action, _value} = 
          Enum.max_by(actions, fn {_action, value} -> value end, fn -> {nil, 0} end)
        
        # Add to policy if we found a best action
        if best_action != nil do
          Map.put(acc, state, best_action)
        else
          acc
        end
      end)
      
    %{agent | policy: policy}
  end
  
  defp create_fused_policy(agents_list, coordination_strategy) do
    # Create a joint policy based on coordination strategy
    case coordination_strategy do
      :policy_averaging ->
        # Simple average of individual policies
        agent_map = Enum.with_index(agents_list) |> Map.new(fn {agent, idx} -> {idx, agent} end)
        average_policies(agent_map)
        
      :value_function_fusion ->
        # Fuse value functions and derive policy
        agent_map = Enum.with_index(agents_list) |> Map.new(fn {agent, idx} -> {idx, agent} end)
        fused_values = fuse_value_functions(agent_map)
        
        # Create policy from fused values
        Enum.reduce(fused_values, %{}, fn {state, actions}, acc ->
          # Find action with maximum value
          {best_action, _value} = 
            Enum.max_by(actions, fn {_action, value} -> value end, fn -> {nil, 0} end)
          
          # Add to policy if we found a best action
          if best_action != nil do
            Map.put(acc, state, best_action)
          else
            acc
          end
        end)
        
      _ ->
        # Default: use first agent's policy
        case agents_list do
          [first | _] -> first.policy
          _ -> %{}
        end
    end
  end
  
  defp schedule_sync(interval) do
    Process.send_after(self(), :sync, interval)
  end
  
  defp serialize_state(state) do
    # Convert state to string for use as map key
    cond do
      is_binary(state) -> state
      is_atom(state) -> Atom.to_string(state)
      is_map(state) -> :erlang.term_to_binary(state) |> Base.encode64()
      is_tuple(state) -> :erlang.term_to_binary(state) |> Base.encode64()
      is_list(state) -> :erlang.term_to_binary(state) |> Base.encode64()
      true -> to_string(state)
    end
  end
  
  defp serialize_action(action) do
    # Convert action to string for use as map key
    cond do
      is_binary(action) -> action
      is_atom(action) -> Atom.to_string(action)
      is_map(action) -> :erlang.term_to_binary(action) |> Base.encode64()
      is_tuple(action) -> :erlang.term_to_binary(action) |> Base.encode64()
      is_list(action) -> :erlang.term_to_binary(action) |> Base.encode64()
      true -> to_string(action)
    end
  end
end