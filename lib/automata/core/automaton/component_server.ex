defmodule Automaton.ComponentServer do
  @moduledoc """
  When a component behavior is complete and returns its status code,
  then the Composite it is a child of decides whether to continue through its
  children or whether to stop there and then and return a value.
  """
  alias Automaton.{ComponentServer, Action}

  @types [:action, :decorator, :condition]
  def types, do: @types

  defmacro __using__(opts) do
    user_opts = opts[:user_opts]

    a_types = ComponentServer.types()
    node_type = user_opts[:node_type]

    control =
      if Enum.member?(a_types, node_type) do
        quote do
          use(Action, user_opts: unquote(user_opts))
        end
      end

    [control]
  end
end
