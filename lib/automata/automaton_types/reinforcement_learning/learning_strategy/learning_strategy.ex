defmodule Automaton.Types.RL.LearningStrategy do
  @moduledoc """
  A framework for pluggable reinforcement learning algorithms.
  
  This module defines a behaviour and common functionality for different
  reinforcement learning strategies that can be used within the Automata system.
  By implementing this behaviour, different learning algorithms can be easily
  swapped in and out of the system while maintaining the same interface.
  
  Supported algorithms include:
  - Temporal Difference (TD) Learning
  - Q-Learning
  - SARSA
  - Experience Replay
  - Policy Gradient methods
  
  The framework allows for strategies to be combined and customized while
  maintaining a consistent interface for integration with behavior trees
  and other components of the system.
  """
  
  @doc """
  Initialize the learning strategy with provided options.
  """
  @callback init(opts :: Keyword.t()) :: map()
  
  @doc """
  Update the learning model based on a new experience tuple.
  
  The experience tuple contains:
  - state: The state in which the action was taken
  - action: The action that was taken
  - reward: The reward received after taking the action
  - next_state: The resulting state after the action
  - done: Boolean indicating if the episode is complete
  """
  @callback update(model :: map(), experience :: tuple()) :: map()
  
  @doc """
  Select an action based on the current state and learning model.
  
  Returns an action based on the model's policy, which may include
  exploration vs exploitation strategies.
  """
  @callback select_action(model :: map(), state :: any()) :: any()
  
  @doc """
  Optionally save the learning model to persistent storage.
  """
  @callback save(model :: map(), path :: String.t()) :: :ok | {:error, term()}
  
  @doc """
  Optionally load a learning model from persistent storage.
  """
  @callback load(path :: String.t()) :: {:ok, map()} | {:error, term()}
  
  @doc """
  Get debug information and metrics about the learning model.
  """
  @callback get_metrics(model :: map()) :: map()
  
  defmacro __using__(opts) do
    quote do
      @behaviour Automaton.Types.RL.LearningStrategy
      
      # Default implementations
      
      def init(opts) do
        %{
          name: __MODULE__,
          parameters: opts,
          learning_rate: Keyword.get(opts, :learning_rate, 0.1),
          discount_factor: Keyword.get(opts, :discount_factor, 0.9),
          model_state: %{}
        }
      end
      
      def save(model, path) do
        # Default implementation using :erlang.term_to_binary
        binary = :erlang.term_to_binary(model)
        
        # Ensure directory exists
        dirname = Path.dirname(path)
        File.mkdir_p(dirname)
        
        # Write to file
        case File.write(path, binary) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
      end
      
      def load(path) do
        # Default implementation using :erlang.binary_to_term
        case File.read(path) do
          {:ok, binary} -> 
            try do
              model = :erlang.binary_to_term(binary)
              {:ok, model}
            rescue
              _ -> {:error, :invalid_format}
            end
            
          {:error, reason} -> 
            {:error, reason}
        end
      end
      
      def get_metrics(model) do
        # Default basic metrics
        %{
          name: Map.get(model, :name, __MODULE__),
          learning_rate: Map.get(model, :learning_rate, 0.1),
          discount_factor: Map.get(model, :discount_factor, 0.9)
        }
      end
      
      # Override the default implementations as needed
      defoverridable init: 1, save: 2, load: 1, get_metrics: 1
    end
  end
end

defmodule Automaton.Types.RL.QLearnStrategy do
  @moduledoc """
  Q-Learning implementation of the learning strategy.
  
  Q-Learning is an off-policy TD control algorithm that learns the value of
  action-state pairs. It learns the optimal policy directly, independent of
  the agent's actions, by using the maximum reward of available actions.
  
  Q(s,a) = Q(s,a) + α * (r + γ * max(Q(s',a')) - Q(s,a))
  
  Where:
  - s is the current state
  - a is the action taken
  - r is the reward received
  - s' is the next state
  - α is the learning rate
  - γ is the discount factor
  """
  use Automaton.Types.RL.LearningStrategy
  
  @impl true
  def init(opts) do
    base = super(opts)
    
    # Q-Learning specific parameters
    epsilon = Keyword.get(opts, :epsilon, 0.1)
    epsilon_decay = Keyword.get(opts, :epsilon_decay, 0.995)
    min_epsilon = Keyword.get(opts, :min_epsilon, 0.01)
    
    q_table = %{}
    
    Map.merge(base, %{
      epsilon: epsilon,
      epsilon_decay: epsilon_decay,
      min_epsilon: min_epsilon,
      q_table: q_table,
      visited_states: MapSet.new()
    })
  end
  
  @impl true
  def update(model, {state, action, reward, next_state, done}) do
    # Get current Q-value
    q_table = Map.get(model, :q_table, %{})
    current_q = get_q_value(q_table, state, action)
    
    # Calculate maximum Q-value for next state
    next_q_max = if done do
      0.0
    else
      get_max_q_value(q_table, next_state)
    end
    
    # Q-Learning update formula
    # Q(s,a) = Q(s,a) + α * (r + γ * max(Q(s',a')) - Q(s,a))
    alpha = model.learning_rate
    gamma = model.discount_factor
    new_q = current_q + alpha * (reward + gamma * next_q_max - current_q)
    
    # Update Q-table
    updated_q_table = set_q_value(q_table, state, action, new_q)
    
    # Update visited states
    visited_states = MapSet.put(model.visited_states, state)
    
    # Update epsilon with decay
    new_epsilon = max(model.min_epsilon, model.epsilon * model.epsilon_decay)
    
    # Return updated model
    %{model | 
      q_table: updated_q_table, 
      visited_states: visited_states,
      epsilon: new_epsilon
    }
  end
  
  @impl true
  def select_action(model, state) do
    # Epsilon-greedy action selection
    if :rand.uniform() < model.epsilon do
      # Exploration: select random action
      available_actions = get_available_actions(state)
      Enum.random(available_actions)
    else
      # Exploitation: select best action
      q_table = Map.get(model, :q_table, %{})
      select_best_action(q_table, state)
    end
  end
  
  @impl true
  def get_metrics(model) do
    base_metrics = super(model)
    
    # Add Q-Learning specific metrics
    q_table = Map.get(model, :q_table, %{})
    num_states = MapSet.size(model.visited_states)
    
    # Calculate average Q-value as a basic metric
    total_q = Enum.reduce(q_table, 0.0, fn {{_state, _action}, q_value}, acc ->
      acc + q_value
    end)
    
    avg_q = if map_size(q_table) > 0, do: total_q / map_size(q_table), else: 0.0
    
    Map.merge(base_metrics, %{
      algorithm: "Q-Learning",
      epsilon: model.epsilon,
      states_visited: num_states,
      q_values: map_size(q_table),
      average_q_value: avg_q
    })
  end
  
  # Private helper functions
  
  # Get the Q-value for a state-action pair
  defp get_q_value(q_table, state, action) do
    Map.get(q_table, {state, action}, 0.0)
  end
  
  # Set the Q-value for a state-action pair
  defp set_q_value(q_table, state, action, value) do
    Map.put(q_table, {state, action}, value)
  end
  
  # Get the maximum Q-value for a state across all actions
  defp get_max_q_value(q_table, state) do
    available_actions = get_available_actions(state)
    
    # Get Q-values for all available actions
    q_values = Enum.map(available_actions, fn action ->
      get_q_value(q_table, state, action)
    end)
    
    # Return maximum Q-value (0.0 if no actions available)
    if Enum.empty?(q_values), do: 0.0, else: Enum.max(q_values)
  end
  
  # Select the action with highest Q-value
  defp select_best_action(q_table, state) do
    available_actions = get_available_actions(state)
    
    # Get Q-values for all available actions
    action_values = Enum.map(available_actions, fn action ->
      {action, get_q_value(q_table, state, action)}
    end)
    
    if Enum.empty?(action_values) do
      # No actions available, return nil
      nil
    else
      # Return action with highest Q-value
      {best_action, _value} = Enum.max_by(action_values, fn {_action, value} -> value end)
      best_action
    end
  end
  
  # Get available actions for a state
  # This should be overridden in specific implementations
  defp get_available_actions(_state) do
    [:action1, :action2, :action3]
  end
end

defmodule Automaton.Types.RL.SARSAStrategy do
  @moduledoc """
  SARSA (State-Action-Reward-State-Action) implementation of the learning strategy.
  
  SARSA is an on-policy TD learning algorithm that updates the policy based on
  the action actually taken in the next state, rather than the maximum reward
  available (as in Q-learning).
  
  Q(s,a) = Q(s,a) + α * (r + γ * Q(s',a') - Q(s,a))
  
  Where:
  - s is the current state
  - a is the action taken
  - r is the reward received
  - s' is the next state
  - a' is the action taken in the next state
  - α is the learning rate
  - γ is the discount factor
  """
  use Automaton.Types.RL.LearningStrategy
  
  @impl true
  def init(opts) do
    base = super(opts)
    
    # SARSA specific parameters
    epsilon = Keyword.get(opts, :epsilon, 0.1)
    epsilon_decay = Keyword.get(opts, :epsilon_decay, 0.995)
    min_epsilon = Keyword.get(opts, :min_epsilon, 0.01)
    
    q_table = %{}
    
    Map.merge(base, %{
      epsilon: epsilon,
      epsilon_decay: epsilon_decay,
      min_epsilon: min_epsilon,
      q_table: q_table,
      visited_states: MapSet.new(),
      last_state: nil,
      last_action: nil,
      steps: 0
    })
  end
  
  @impl true
  def update(model, {state, action, reward, next_state, done}) do
    # Get current Q-value
    q_table = Map.get(model, :q_table, %{})
    current_q = get_q_value(q_table, state, action)
    
    # Select next action using policy (this is key difference from Q-learning)
    next_action = select_action(model, next_state)
    
    # Get next state Q-value using the selected action (not the max)
    next_q = if done do
      0.0
    else
      get_q_value(q_table, next_state, next_action)
    end
    
    # SARSA update formula
    # Q(s,a) = Q(s,a) + α * (r + γ * Q(s',a') - Q(s,a))
    alpha = model.learning_rate
    gamma = model.discount_factor
    new_q = current_q + alpha * (reward + gamma * next_q - current_q)
    
    # Update Q-table
    updated_q_table = set_q_value(q_table, state, action, new_q)
    
    # Update visited states
    visited_states = MapSet.put(model.visited_states, state)
    
    # Update epsilon with decay
    new_epsilon = max(model.min_epsilon, model.epsilon * model.epsilon_decay)
    
    # Return updated model
    %{model | 
      q_table: updated_q_table, 
      visited_states: visited_states,
      epsilon: new_epsilon,
      last_state: next_state,
      last_action: next_action,
      steps: model.steps + 1
    }
  end
  
  @impl true
  def select_action(model, state) do
    # Epsilon-greedy action selection
    if :rand.uniform() < model.epsilon do
      # Exploration: select random action
      available_actions = get_available_actions(state)
      Enum.random(available_actions)
    else
      # Exploitation: select best action
      q_table = Map.get(model, :q_table, %{})
      select_best_action(q_table, state)
    end
  end
  
  @impl true
  def get_metrics(model) do
    base_metrics = super(model)
    
    # Add SARSA specific metrics
    q_table = Map.get(model, :q_table, %{})
    num_states = MapSet.size(model.visited_states)
    
    # Calculate average Q-value as a basic metric
    total_q = Enum.reduce(q_table, 0.0, fn {{_state, _action}, q_value}, acc ->
      acc + q_value
    end)
    
    avg_q = if map_size(q_table) > 0, do: total_q / map_size(q_table), else: 0.0
    
    Map.merge(base_metrics, %{
      algorithm: "SARSA",
      epsilon: model.epsilon,
      states_visited: num_states,
      q_values: map_size(q_table),
      average_q_value: avg_q,
      steps: model.steps
    })
  end
  
  # Private helper functions
  
  # Get the Q-value for a state-action pair
  defp get_q_value(q_table, state, action) do
    Map.get(q_table, {state, action}, 0.0)
  end
  
  # Set the Q-value for a state-action pair
  defp set_q_value(q_table, state, action, value) do
    Map.put(q_table, {state, action}, value)
  end
  
  # Select the action with highest Q-value
  defp select_best_action(q_table, state) do
    available_actions = get_available_actions(state)
    
    # Get Q-values for all available actions
    action_values = Enum.map(available_actions, fn action ->
      {action, get_q_value(q_table, state, action)}
    end)
    
    if Enum.empty?(action_values) do
      # No actions available, return nil
      nil
    else
      # Return action with highest Q-value
      {best_action, _value} = Enum.max_by(action_values, fn {_action, value} -> value end)
      best_action
    end
  end
  
  # Get available actions for a state
  # This should be overridden in specific implementations
  defp get_available_actions(_state) do
    [:action1, :action2, :action3]
  end
end

defmodule Automaton.Types.RL.ExperienceReplay do
  @moduledoc """
  Experience Replay buffer for reinforcement learning algorithms.
  
  Experience replay stores past experiences and allows learning algorithms
  to use them for training. This improves sample efficiency and stability
  by breaking the correlation between consecutive experiences.
  
  This module can be used with any learning strategy to enable batch learning
  and more efficient use of experience data.
  """
  
  @doc """
  Creates a new experience replay buffer.
  
  Options:
  - max_size: Maximum number of experiences to store (default: 10000)
  - batch_size: Size of batches to sample (default: 32)
  """
  def new(opts \\ []) do
    max_size = Keyword.get(opts, :max_size, 10000)
    batch_size = Keyword.get(opts, :batch_size, 32)
    
    %{
      buffer: :queue.new(),
      max_size: max_size,
      batch_size: batch_size,
      count: 0
    }
  end
  
  @doc """
  Adds an experience to the buffer.
  
  Experience is a tuple of {state, action, reward, next_state, done}.
  """
  def add(buffer, experience) do
    # Add experience to the buffer
    updated_buffer = :queue.in(experience, buffer.buffer)
    
    # If buffer is full, remove oldest experience
    {final_buffer, final_count} =
      if buffer.count >= buffer.max_size do
        {:queue.drop(updated_buffer), buffer.count}
      else
        {updated_buffer, buffer.count + 1}
      end
    
    %{buffer | buffer: final_buffer, count: final_count}
  end
  
  @doc """
  Samples a batch of experiences from the buffer.
  
  Returns a list of experience tuples.
  """
  def sample(buffer) do
    # Convert queue to list
    experiences = :queue.to_list(buffer.buffer)
    
    # Determine batch size (minimum of buffer size and requested batch size)
    batch_size = min(buffer.count, buffer.batch_size)
    
    # Randomly sample experiences
    1..batch_size
    |> Enum.map(fn _ -> Enum.random(experiences) end)
  end
  
  @doc """
  Updates a learning model using a batch of experiences from the buffer.
  
  Takes a learning strategy module and model, samples experiences,
  and updates the model with each experience.
  """
  def train(buffer, strategy_module, model) do
    # Sample batch of experiences
    batch = sample(buffer)
    
    # Update model with each experience
    Enum.reduce(batch, model, fn experience, acc_model ->
      strategy_module.update(acc_model, experience)
    end)
  end
  
  @doc """
  Returns the current size of the buffer.
  """
  def size(buffer) do
    buffer.count
  end
  
  @doc """
  Clears all experiences from the buffer.
  """
  def clear(buffer) do
    %{buffer | buffer: :queue.new(), count: 0}
  end
end