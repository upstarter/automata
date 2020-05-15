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
  policy layers. This is a good place for more layers (TBD).

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
  of the agents. This is a good place for a boundary point, before starting the
  individual agents one by one.
  """
  def init(automata_config) do
    automata_config
    |> Enum.each(fn automaton_config ->
      send(self(), {:start_automaton_sup, automaton_config})
    end)

    {:ok, automata_config}
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
