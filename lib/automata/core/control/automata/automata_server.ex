defmodule Automata.Server do
  @moduledoc """
  `Automata.Server` is a behavior which provides decentralized fault tolerance
  lifecycle management for a collection of user-defined agents.

  `Automata.AutomataSupervisor` delegates the logic for starting the
  user-defined  agents (along with their supervisors) to this process to keep
  the supervisor clean and thus more resilient to failure so it can do its
  primary job, keeping all the automata alive with the life changing magic of
  OTP supervision at the helm.

  This is a primary boundary point between the high level automata control
  policy layers and  the lower level (and highly variant) automaton control
  policy layers. The configured policies are handled by additional layers TBD.

  TODO: Automata.Config.Parser to have handler Automata.Types.Typology handle
  """
  use GenServer

  #######
  # API #
  #######

  def start_link(world_config) do
    GenServer.start_link(__MODULE__, [world_config], name: __MODULE__)
  end

  #############
  # Callbacks #
  #############

  @doc """
  The world_config data flow is a key abstraction for meta-level control
  of the agents. This is a primary internal boundary point, before starting the
  individual agents one by one.

  The `automaton_config` data flow / signals transmitted from this point should
  be untouched until hitting the `Automaton.AgentServer`, a key boundary point
  providing lifecycle and argument interpretation before being expedited to the
  `Automaton` to be interpreted at both the builtins and custom built level. The
  layers pre, post, and in between are TBD, along with design of other potential
  servers off of the `Automaton.AgentSupervisor`.
  """
  def init([world_config]) do
    world_config
    |> configure_automata()
    |> Enum.each(fn automaton_config ->
      send(self(), {:start_automaton_sup, [automaton_config, world_config]})
    end)

    {:ok, world_config}
  end

  @doc """
  Primary boundary point for initial interpretation, re-organization of automata
  level control policy in order to determine automaton level control policies.
  We are transforming from control policy -> control policies using information
  from the World, including all agent configurations.
  """
  def configure_automata(world_config) do
    world_config = Automata.Types.Typology.call(world_config)
    world_config.automata
  end

  def handle_info({:start_automaton_sup, [automaton_config, world_config]}, state) do
    {:ok, _tree_sup} =
      DynamicSupervisor.start_child(
        Automata.AutomataSupervisor,
        {Automata.AutomatonSupervisor, [automaton_config]}
      )

    {:ok, _tree_sup} =
      DynamicSupervisor.start_child(
        Automata.AutomataSupervisor,
        {Automata.World.Server, [world_config.world]}
      )

    {:noreply, state}
  end

  def child_spec([world_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [world_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end
