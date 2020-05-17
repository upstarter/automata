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

  def start_link(automata_config) do
    GenServer.start_link(__MODULE__, automata_config, name: __MODULE__)
  end

  def status(automaton_name) do
    Automaton.AgentServer.status(automaton_name)
  end

  #############
  # Callbacks #
  #############

  @doc """
  The automata_config data flow is a key abstraction for meta-level control
  of the agents. This is a primary internal boundary point, before starting the
  individual agents one by one.

  The `automaton_config` data flow / signals transmitted from this point should
  be untouched until hitting the `Automaton.AgentServer`, a key boundary point
  providing lifecycle and argument interpretation before being expedited to the
  `Automaton` to be interpreted at both the builtins and custom built level. The
  layers pre, post, and in between are TBD, along with design of other potential
  servers off of the `Automaton.AgentSupervisor`.
  """
  def init(automata_config) do
    automata_config
    |> transform_automata_config()
    |> Enum.each(fn automaton_config ->
      send(self(), {:start_automaton_sup, automaton_config})
    end)

    {:ok, automata_config}
  end

  @doc """
  Primary boundary point for interpretation, re-organization of automata level
  control policy in order to determine automaton level control policies. We are
  transforming from policy -> policies.
  """
  def transform_automata_config(automata_config) do
    Automata.Types.Typology.call(automata_config)
  end

  def handle_info({:start_automaton_sup, automaton_config}, state) do
    {:ok, _tree_sup} =
      DynamicSupervisor.start_child(
        Automata.AutomataSupervisor,
        {Automata.AutomatonSupervisor, [automaton_config]}
      )

    {:noreply, state}
  end

  def child_spec([automata_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [automata_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end
