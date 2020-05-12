defmodule Automaton.Types.BT.ComponentServer do
  @moduledoc """
  When a component behavior is complete and returns its status code,
  then the Composite it is a child of decides whether to continue through its
  children or whether to stop there and then and return a value.

  Supervised by the `Automaton.Types.BT.CompositeServer` which is the parent
  of the component.
  """
  alias Automaton.Types.BT.{ComponentServer, Action}

  @types [:action, :decorator, :condition]
  def types, do: @types

  defmacro __using__(opts) do
    user_config = opts[:user_config]

    a_types = ComponentServer.types()
    node_type = user_config[:node_type]

    control =
      if Enum.member?(a_types, node_type) do
        quote do
          use(Action, user_config: unquote(user_config))
        end
      end

    [control]
  end
end
