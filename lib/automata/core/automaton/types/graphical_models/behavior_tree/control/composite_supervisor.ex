defmodule Automaton.Types.BT.CompositeSupervisor do
  @moduledoc """
  The `CompositeServer` is injected into the user-defined automaton and manages
  the lifecycle of their children (the execution nodes), ie. starting, stopping, and handling messages.
  All components are children of a composite.
  """
  use DynamicSupervisor

  def start_link([composite_server, {_, _, _} = mfa, name]) do
    DynamicSupervisor.start_link(__MODULE__, [composite_server, mfa, name],
      name: :"#{name}CompositeSupervisor"
    )
  end

  @spec init([]) :: no_return
  def init([composite_server, {_m, _f, _a}, _name]) do
    Process.link(composite_server)

    opts = [
      strategy: :one_for_one,
      max_restart: 5,
      max_time: 3600
    ]

    DynamicSupervisor.init(opts)
  end

  def child_spec([[_composite_server, _mfa, name]] = args) do
    %{
      id: :"#{name}CompositeSupervisor",
      start: {__MODULE__, :start_link, args},
      shutdown: 10_000,
      restart: :temporary,
      type: :supervisor
    }
  end
end
