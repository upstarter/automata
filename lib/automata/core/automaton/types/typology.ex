defmodule Automaton.Types.Typology do
  alias Automaton.Types.BehaviorTree

  @types [:behavior_tree]
  def types, do: @types

  def call(user_opts) do
    cond do
      user_opts[:type] == :behavior_tree ->
        quote do: use(BehaviorTree, user_opts: unquote(user_opts))

      user_opts[:type] == nil ->
        quote do: use(BehaviorTree, user_opts: unquote(user_opts))
    end
  end
end
