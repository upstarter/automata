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

defmodule Automata.Composite do
  @moduledoc """
  When a child behavior is complete and returns its status code the Composite
  decides whether to continue through its children or whether to stop there and
  then and return a value.

  The behavior tree represents all possible Actions that your AI can take.
  The route from the top level to each leaf represents one course of action, and
  the behavior tree algorithm traverses among those courses of action in a
  left-to-right manner. In other words, it performs a depth-first traversal.

  #TODO: best practice for DFS on supervision tree? One way to do it (sans tail-recursion):
  @type node :: {
    term() | :undefined,
    child() | :restarting,
    :worker | :supervisor,
    :supervisor.modules()
  }
  @spec supervision_tree_each(
    node(),
    (node() -> any())
  )

  def supervision_tree_each({_, pid, :supervisor, _} = node, fun) when is_pid(pid) do
    fun.(node)
    pid
    |> Supervisor.which_children()
    |> Enum.each(&supervision_tree_each(&1, fun))
  end

  def supervision_tree_each(node, fun) do
    fun.(node)
  end
  """
  # a composite is just an array of behaviors
  @callback add_child() :: {:ok, list} | {:error, String.t()}
  @callback remove_child() :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, term} | {:error, String.t()}

  @composites [:sequence, :selector]
  def composites, do: @composites
end
