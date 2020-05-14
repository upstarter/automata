defmodule Automata.Server do
  @moduledoc """
  Handles lifecycle of `Automata.AutomataSupervisor` as a delegate to keep the
  supervisor lean and mean, since it handles each `Automata.AutomatonSupervisor`,
  passing the user config, which flows through the entire tree. This
  data flow is a key abstraction for the agents.

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
    Automata.AgentServer.status(automaton_name)
  end

  #############
  # Callbacks #
  #############

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
