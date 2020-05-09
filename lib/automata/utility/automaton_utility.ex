defmodule Automaton.Utility do
  @moduledoc """
  Node utility decisioning
  First pass should prioritize composite 'selector' actions based on utility (a
  priority composite node)

  Dual Utility Reasoner?
  There are two common approaches to utility-based selection. The first,
  absolute utility, is to evaluate every option and take the one with the
  highest utility. The second, relative utility, is to select an option at
  random, using the utility of each option to define the probability that it
  will be selected. The probability (P) for selecting an option (O) is
  determined by dividing the utility (U) of that option by the total utility of
  all options. This approach is commonly referred to as weight-based random or
  weighted random.

  A Dual Utility Reasoner combines both of these approaches. It assigns two
  utility values to each option: a rank (absolute utility) and a weight
  (relative utility). Conceptually, rank is used to divide the options into
  categories, where we only select options that are in the best category. Weight
  is used to evaluate options within the context of their category. Thus the
  weight of an option is only meaningful relative to the weights of other
  options within the same rank category – and only the weights of the options in
  the best category truly matter
  """

  defmacro __using__(_user_opts) do
  end
end
