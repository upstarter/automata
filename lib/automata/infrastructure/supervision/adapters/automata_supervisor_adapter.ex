defmodule Automata.Infrastructure.Supervision.Adapters.AutomataSupervisorAdapter do
  @moduledoc """
  Adapter for Automata.AutomataSupervisor that bridges the original dynamic supervisor
  with the new distributed supervisor infrastructure.
  
  This adapter maintains compatibility with existing code by implementing the same
  interface while delegating actual supervision to the distributed components.
  """
  use GenServer
  
  alias Automata.Infrastructure.Supervision.DistributedSupervisor

  ####################
  # Public Interface #
  ####################

  @doc """
  Starts the adapter with the same interface as the original AutomataSupervisor.
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Maintains compatibility with the original child_spec function.
  """
  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker
    }
  end

  @doc """
  Starts a child in the distributed supervisor.
  This provides compatibility with the original DynamicSupervisor.start_child calls.
  """
  def start_child(supervisor_name, child_spec) do
    GenServer.call(__MODULE__, {:start_child, supervisor_name, child_spec})
  end

  ####################
  # Implementation   #
  ####################

  @impl GenServer
  def init([]) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:start_child, _supervisor_name, child_spec}, _from, state) do
    # Forward the request to the distributed supervisor
    result = DistributedSupervisor.start_child(child_spec)
    {:reply, result, state}
  end
end