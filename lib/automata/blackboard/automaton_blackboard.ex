defmodule Automaton.Blackboard do
  @moduledoc """
    The Node Blackboard
    Blackboard Architectures
      A blackboard system isn’t a decision making tool in its own right. It is a
      mechanism for coordinating the actions of several decision makers. The
      individual decision making systems can be implemented in any way: from a
      decision tree to an expert system or even to learning tools such as neural
      networks. It is this flexibility that makes blackboard architectures
      appealing.
    The Problem
      We would like to be able to coordinate the decision making of several different
      techniques. Each technique may be able to make suggestions as to what to do
      next, but the final decision can only be made if they cooperate.

    The Blackboard Metaphor
      Blackboard-based problem solving is often presented using the following
      metaphor: Imagine a group of human specialists seated next to a large
      blackboard. The specialists are working cooperatively to solve a problem,
      using the blackboard as the workplace for developing the solution. Problem
      solving begins when the problem and initial data are written onto the
      blackboard. The specialists watch the blackboard, looking for an
      opportunity to apply their expertise to the developing solution. When a
      specialist finds sufficient information to make a contribution, she
      records the contribution on the blackboard, hopefully enabling other
      specialists to apply their expertise. This process of adding contributions
      to the blackboard continues until the problem has been solved.

      This simple metaphor captures a number of the important characteristics of
      blackboard systems, each of which is described separately below.

      - Independence of expertise (I think, therefore I am.)

      - Diversity in problem-solving techniques (I don’t think like you do.)

      - Flexible representation of blackboard information (If you can draw it, I can use it.)

      - Common interaction language (What’d you say?)

      - Positioning metrics (You could look it up.)
        If the problem being solved by our human specialists is complex and the number of their
        contributions made on the blackboard begins to grow, quickly locating pertinent information
        becomes a problem. A specialist should not have to scan the entire blackboard to see if a
        particular item has been placed on the blackboard by another specialist.

        One solution is to subdivide the blackboard into regions, each corresponding to a particular
        kind of information. This approach is commonly used in blackboard systems, where different
        levels, planes, or multiple blackboards are used to group related objects.
        Similarly, ordering metrics can be used within each region, to sort information numerically,
        alphabetically, or by relevance. Advanced blackboard-system frameworks provide sophisticated
        multidimensional metrics for efficiently locating blackboard objects of interest.

      - Event-based activation (Is anybody there?)

      - Need for control (It’s my turn.)

      - Incremental solution generation (Step by step, inch by inch. . .)
  """

  defmacro __using__(user_opts) do
  end
end
