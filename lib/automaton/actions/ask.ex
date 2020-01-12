# defmodule Automaton.Control.Ask do
#   @moduledoc """
#     Supervises user-defined selector actions
#   """
#   use GenServer
#
#   # atoms not garbage collectable, use a rich registry instead
#   @name :"ask_#{question_number}"
#
#   ## Client API
#   def start_link(opts \\ []) do
#     GenServer.start_link(__MODULE__, :ok, opts ++ [name: @name])
#   end
#
#   def ask do
#     # question_number = pick_question(...)
#     # GenServer.call(:"ask_#{question_number}", ...)
#   end
#
#   ## Callbacks
#   def init(:ok) do
#     IO.inspect(@name, label: __MODULE__)
#
#     {:ok, %{}}
#   end
#
#   ## Helper Functions
# end
