defmodule Automaton.Types.BT.Components.Decorator do
  @moduledoc """
  Base module for behavior tree decorators.
  
  Decorators modify the behavior of their child node in some way.
  They are used to create more complex behaviors without modifying
  the underlying node implementation.
  
  This module provides common functionality for all decorator types.
  """
  alias Automaton.Types.BT.Behavior
  
  defmodule State do
    @moduledoc false
    # Base state for all decorator types
    defstruct status: :bh_fresh,
              parent: nil,
              control: 0,
              child: nil,           # The child node that this decorator wraps
              child_pid: nil,       # PID of the child node process
              decorator_type: nil,  # Type of decorator (e.g., :inverter, :repeater)
              parameters: %{},      # Parameters specific to this decorator
              tick_freq: nil
  end
  
  @doc """
  Generic decorator initialization.
  """
  def on_init(%{child_pid: nil} = state) do
    # Child process hasn't been started yet
    state
  end
  
  def on_init(state) do
    # Initialize the child node
    GenServer.cast(state.child_pid, {:initialize, self()})
    state
  end
  
  @doc """
  Generic decorator termination.
  """
  def on_terminate(state) do
    if state.child_pid && Process.alive?(state.child_pid) do
      # Ensure child is terminated properly
      GenServer.call(state.child_pid, :abort)
    end
    
    state.status
  end
  
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      
      # Common functionality for all decorator types
      
      @doc """
      Returns the current status of the decorator.
      """
      def status(pid) do
        GenServer.call(pid, :status)
      end
      
      @doc """
      Sets a parameter for the decorator.
      """
      def set_parameter(pid, key, value) do
        GenServer.call(pid, {:set_parameter, key, value})
      end
      
      @doc """
      Gets a parameter value for the decorator.
      """
      def get_parameter(pid, key) do
        GenServer.call(pid, {:get_parameter, key})
      end
      
      @doc """
      Handler for setting decorator parameters.
      """
      def handle_call({:set_parameter, key, value}, _from, state) do
        new_parameters = Map.put(state.parameters, key, value)
        new_state = %{state | parameters: new_parameters}
        {:reply, :ok, new_state}
      end
      
      @doc """
      Handler for getting decorator parameters.
      """
      def handle_call({:get_parameter, key}, _from, state) do
        value = Map.get(state.parameters, key)
        {:reply, value, state}
      end
    end
  end
end

defmodule Automaton.Types.BT.Components.Decorator.Inverter do
  @moduledoc """
  Inverter decorator.
  
  Inverts the result of its child node:
  - If the child returns success, the inverter returns failure.
  - If the child returns failure, the inverter returns success.
  - If the child returns running, the inverter returns running.
  """
  use Automaton.Types.BT.Components.Decorator
  
  def update(%{child_pid: child_pid} = state) when is_pid(child_pid) do
    # Call the child node
    status = GenServer.call(child_pid, :tick, 10_000)
    
    # Invert the child's status
    new_status = case status do
      :bh_success -> :bh_failure
      :bh_failure -> :bh_success
      other -> other  # For :bh_running or other statuses, don't invert
    end
    
    {:ok, %{state | status: new_status, control: state.control + 1}}
  end
  
  # No child node yet
  def update(state) do
    {:ok, %{state | status: :bh_failure, control: state.control + 1}}
  end
end

defmodule Automaton.Types.BT.Components.Decorator.Repeater do
  @moduledoc """
  Repeater decorator.
  
  Repeats its child node a specified number of times or until it fails.
  """
  use Automaton.Types.BT.Components.Decorator
  
  def on_init(state) do
    # Initialize default parameters if not already set
    parameters = Map.merge(
      %{
        count: 1,            # How many times to repeat (nil for infinite)
        iterations: 0,       # Current iteration count
        until_fail: false    # Whether to repeat until failure
      },
      state.parameters
    )
    
    super(%{state | parameters: parameters})
  end
  
  def update(%{child_pid: child_pid} = state) when is_pid(child_pid) do
    # Get current state 
    %{count: count, iterations: iterations, until_fail: until_fail} = state.parameters
    
    # Check if we've reached our limit
    if count && iterations >= count do
      # We've repeated enough times, return success
      {:ok, %{state | status: :bh_success, control: state.control + 1}}
    else
      # Call the child node
      status = GenServer.call(child_pid, :tick, 10_000)
      
      case status do
        # Child is still running
        :bh_running ->
          {:ok, %{state | status: :bh_running, control: state.control + 1}}
          
        # Child failed and we're repeating until failure
        :bh_failure when until_fail ->
          {:ok, %{state | status: :bh_success, control: state.control + 1}}
          
        # Child failed but we're not repeating until failure
        :bh_failure ->
          {:ok, %{state | status: :bh_failure, control: state.control + 1}}
          
        # Child succeeded, increment iterations and reset child
        :bh_success ->
          new_parameters = %{state.parameters | iterations: iterations + 1}
          GenServer.call(child_pid, :reset)
          
          # Check if we should repeat again
          if count && iterations + 1 >= count do
            # We've repeated enough times, return success
            {:ok, %{state | status: :bh_success, parameters: new_parameters, control: state.control + 1}}
          else
            # More repetitions to go, return running
            {:ok, %{state | status: :bh_running, parameters: new_parameters, control: state.control + 1}}
          end
      end
    end
  end
  
  # No child node yet
  def update(state) do
    {:ok, %{state | status: :bh_failure, control: state.control + 1}}
  end
end

defmodule Automaton.Types.BT.Components.Decorator.Timeout do
  @moduledoc """
  Timeout decorator.
  
  Fails if its child node doesn't complete within a specified time.
  """
  use Automaton.Types.BT.Components.Decorator
  
  def on_init(state) do
    # Initialize default parameters if not already set
    parameters = Map.merge(
      %{
        duration: 1000,     # Duration in milliseconds
        start_time: nil     # When the timer started
      },
      state.parameters
    )
    
    # Record start time if this is the first run
    new_params = if parameters.start_time do
      parameters
    else
      %{parameters | start_time: :os.system_time(:millisecond)}
    end
    
    super(%{state | parameters: new_params})
  end
  
  def update(%{child_pid: child_pid} = state) when is_pid(child_pid) do
    # Calculate elapsed time
    now = :os.system_time(:millisecond)
    %{duration: duration, start_time: start_time} = state.parameters
    elapsed = now - start_time
    
    if elapsed > duration do
      # Timeout expired, fail and abort child
      GenServer.call(child_pid, :abort)
      {:ok, %{state | status: :bh_failure, control: state.control + 1}}
    else
      # Call the child node
      status = GenServer.call(child_pid, :tick, 10_000)
      
      case status do
        # Child still running, keep going
        :bh_running ->
          {:ok, %{state | status: :bh_running, control: state.control + 1}}
          
        # Child completed (success or failure), return its status
        _ ->
          {:ok, %{state | status: status, control: state.control + 1}}
      end
    end
  end
  
  # No child node yet
  def update(state) do
    {:ok, %{state | status: :bh_failure, control: state.control + 1}}
  end
  
  def on_terminate(state) do
    # Reset the start time to nil when terminated
    new_parameters = %{state.parameters | start_time: nil}
    super(%{state | parameters: new_parameters})
  end
end

defmodule Automaton.Types.BT.Components.Decorator.Conditional do
  @moduledoc """
  Conditional decorator.
  
  Only allows its child to execute if a condition is met.
  The condition is evaluated by checking a blackboard value.
  """
  use Automaton.Types.BT.Components.Decorator
  alias Automaton.Blackboard
  
  def on_init(state) do
    # Initialize default parameters if not already set
    parameters = Map.merge(
      %{
        blackboard_key: nil,   # Key to check in blackboard
        expected_value: true,  # Value to compare against
        behavior_id: nil,      # Behavior ID for blackboard
        invert: false          # Whether to invert the condition
      },
      state.parameters
    )
    
    super(%{state | parameters: parameters})
  end
  
  def update(%{child_pid: child_pid} = state) when is_pid(child_pid) do
    %{
      blackboard_key: key,
      expected_value: expected,
      behavior_id: behavior_id,
      invert: invert
    } = state.parameters
    
    # If no key is specified, just execute the child
    if is_nil(key) do
      status = GenServer.call(child_pid, :tick, 10_000)
      {:ok, %{state | status: status, control: state.control + 1}}
    else
      # Get the value from the blackboard
      {:ok, value} = Automaton.Blackboard.get_persistent(
        Automaton.Blackboard.via_tuple(self()), 
        behavior_id || "conditional_#{inspect(self())}", 
        key
      )
      
      # Check if condition is met
      condition_met = (value == expected)
      condition_result = if invert, do: !condition_met, else: condition_met
      
      if condition_result do
        # Condition met, execute child
        status = GenServer.call(child_pid, :tick, 10_000)
        {:ok, %{state | status: status, control: state.control + 1}}
      else
        # Condition not met, return failure
        {:ok, %{state | status: :bh_failure, control: state.control + 1}}
      end
    end
  end
  
  # No child node yet
  def update(state) do
    {:ok, %{state | status: :bh_failure, control: state.control + 1}}
  end
end