defmodule Automata do
  @moduledoc """

  """
  use Application

  def start(_type, _args) do
    # TODO: recursively autoload all the user-defined worlds from the worlds/ directory tree
    # to build the worlds_config data structure ie. config for each agent from world config
    # which defines which automata which are operating in that world.

    worlds_config = [
      MockWorld1: [
        # world_config: [name: "MockWorld1", mfa: {MockWorld1, :start_link, []}],
        automata_config: [
          # these lists end up as `automaton_config` from  `Automata.Server` on in
          # the supervision tree (past the `Automata` Control Boundary Layer and
          # into the `Automaton` Control Boundary)
          [name: "Automaton1", mfa: {MockSeq1, :start_link, []}]
          # [name: "Automaton2", mfa: {MockSel1, :start_link, []}]
        ]
      ]
    ]

    start_worlds(worlds_config, nil)
  end

  def start_worlds([{_world_name, config} | rest], _pid) do
    {:ok, pid} = start_world(config)
    start_worlds(rest, pid)
  end

  def start_worlds([], pid) do
    {:ok, pid}
  end

  def start_world([{:automata_config, automata_config} | _rest]) do
    start_automata(automata_config)
  end

  def start_automata(automata_config) do
    Automata.Supervisor.start_link(automata_config)
  end

  def status(automaton_name) do
    Automata.Server.status(automaton_name)
  end
end
