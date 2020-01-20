defmodule Automata.Composite.Parallel do
  @moduledoc """
    Parallel Node
    When the execution of a parallel node starts, then the node’s children are
    executed in succession from left to right without waiting for a return status
    from any child before ticking the next one. It returns success if a given number
    of children M ∈ N return success, it returns failure when the children that
    return running and success are not enough to reach the given number, even if
    they would all return success. It returns running otherwise. The purpose of
    the parallel node is to model those tasks separable in independent sub-tasks
    performing non-conflicting actions (e.g. a multi object tracking can be
    performed using several cameras).

    We could also configure Parallel to have the policy of the Selector task so it
    returns success when its first child succeeds and failure only when all have
    failed. We could also use hybrid policies, where it returns success or failure
    after some specific number or proportion of its children have succeeded or
    failed.

    Using Parallel blocks to make sure that Conditions hold is an important use-case
    in behavior trees. With it we can get much of the power of a state machine, and
    in particular the state machine’s ability to switch tasks when important events
    occur and new opportunities arise. Rather than events triggering transitions
    between states, we can use sub-trees as states and have them running in parallel
    with a set of conditions.

    class Parallel : public Composite
    {
    public:
        enum Policy
        {
            RequireOne,
            RequireAll,
        };

        Parallel(Policy forSuccess, Policy forFailure)
        :	m_eSuccessPolicy(forSuccess)
        ,	m_eFailurePolicy(forFailure)
        {
        }

        virtual ~Parallel() {}

    protected:
        Policy m_eSuccessPolicy;
        Policy m_eFailurePolicy;

        virtual Status update()
        {
            size_t iSuccessCount = 0, iFailureCount = 0;

            for (Behaviors::iterator it = m_Children.begin(); it != m_Children.end(); ++it)
            {
                Behavior& b = **it;
                if (!b.isTerminated())
                {
                    b.tick();
                }

                if (b.getStatus() == BH_SUCCESS)
                {
                    ++iSuccessCount;
                    if (m_eSuccessPolicy == RequireOne)
                    {
                        return BH_SUCCESS;
                    }
                }

                if (b.getStatus() == BH_FAILURE)
                {
                    ++iFailureCount;
                    if (m_eFailurePolicy == RequireOne)
                    {
                        return BH_FAILURE;
                    }
                }
            }

            if (m_eFailurePolicy == RequireAll  &&  iFailureCount == m_Children.size())
            {
                return BH_FAILURE;
            }

            if (m_eSuccessPolicy == RequireAll  &&  iSuccessCount == m_Children.size())
            {
                return BH_SUCCESS;
            }

            return BH_RUNNING;
        }

        virtual void onTerminate(Status)
        {
            for (Behaviors::iterator it = m_Children.begin(); it != m_Children.end(); ++it)
            {
                Behavior& b = **it;
                if (b.isRunning())
                {
                    b.abort();
                }
            }
        }
    };
  """
end
