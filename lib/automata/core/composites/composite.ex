# class Composite : public Behavior
# {
# public:
#     void addChild(Behavior* child) { m_Children.push_back(child); }
#     void removeChild(Behavior*);
#     void clearChildren();
# protected:
#     typedef std::vector<Behavior*> Behaviors;
#     Behaviors m_Children;
# };

defmodule Automaton.Composite do
  @moduledoc """
  When a child behavior is complete and returns its status code the Composite
  decides whether to continue through its children or whether to stop there and
  then and return a value.

  The behavior tree represents all possible Actions that your AI can take.
  The route from the top level to each leaf represents one course of action, and
  the behavior tree algorithm traverses among those courses of action in a
  left-to-right manner. In other words, it performs a depth-first traversal.
  """
  alias Automaton.{Behavior, Composite, Action}
  alias Automaton.Composite.{Sequence, Selector}

  # a composite is just an array of behaviors
  @callback add_child() :: {:ok, list} | {:error, String.t()}
  @callback remove_child() :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, term} | {:error, String.t()}

  @types [:sequence, :selector]
  def types, do: @types

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behavior Composite
      # TODO: probably handle state somewhere else? GenServer linked to Node?
      defmodule State do
        # bh_fresh is for when status has not been initialized
        # yet or has been reset
        defstruct m_status: :bh_fresh,
                  # control is the parent, nil when fresh
                  control: nil,
                  m_children: opts[:children],
                  m_current: nil
      end

      case opts[:node_type] do
        :sequence ->
          use Sequence

        :selector ->
          use Selector
      end

      # TODO: best practice for DFS on supervision tree? One way to do it (sans tail-recursion):
      def update_tree do
        # tick forever (or at configured tick_freq)
        # For each tick
        #   For each node in tree
        #     node.tick # updates node(subtree)
      end

      #
      # @spec supervision_tree_each(
      #         node(),
      #         (node() -> any())
      #       )

      # def supervision_tree_each({_, pid, :supervisor, _} = node, fun) when is_pid(pid) do
      #   fun.(node)
      #
      #   pid
      #   |> Supervisor.which_children()
      #   |> Enum.each(&supervision_tree_each(&1, fun))
      # end
      #
      # def supervision_tree_each(node, fun) do
      #   fun.(node)
      # end

      # notifies listeners if this task status is not fresh
      @impl Composite
      def add_child() do
        {:ok, []}
      end

      @impl Composite
      def remove_child() do
        {:ok, nil}
      end

      @impl Composite
      def clear_children() do
        {:ok, nil}
      end
    end
  end
end
