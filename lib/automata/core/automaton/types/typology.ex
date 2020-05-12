defmodule Automaton.Types.Typology do
  @moduledoc """
  ## Types are builtin state space representations.

  Typology is for interpretation of what state space representation to use based
  on user configuration. Each type has a `config/` dir to handle user
  config parsing and interpretation specific to it's domain.
  """
  alias Automaton.Types.BT

  @types [:behavior_tree]
  def types, do: @types

  def call(user_opts) do
    type =
      cond do
        user_opts[:type] == :behavior_tree ->
          quote do: use(BT, user_opts: unquote(user_opts))

        # TODO: need this for children.
        # use parent type? raise error?
        user_opts[:type] == nil ->
          quote do: use(BT, user_opts: unquote(user_opts))
      end

    [type]
  end
end
