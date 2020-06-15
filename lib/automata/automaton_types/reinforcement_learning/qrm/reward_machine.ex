
# import Automaton.Types.QRM.RewardFunctions
# import Automaton.Types.QRM.RewardMachineUtils

defmodule RewardMachine do
  use GenServer
  
    def init(self, file, use_rs, gamma):
        # <U,u0,delta_u,delta_r>
        self.U = []       # list of machine states
        self.u0 = None    # initial state
        self.delta_u = {} # state-transition function
        self.delta_r = {} # reward-transition function
        self.T = set()    # set of terminal states (they are automatically detected)
        self._load_reward_machine(file)
        self.use_rs = use_rs # flag indicating whether (or not) to use reward shaping
        if self.use_rs:
            self.gamma    = gamma # this is the gamme from the environment
            self.rs_gamma = gamma # gamma that is used in the value iteration that compute the shaping potentials
            self.potentials = value_iteration(self.U, self.delta_u, self.delta_r, self.rs_gamma)
            for u in self.potentials:
                self.potentials[u] = -self.potentials[u]

        # NOTE(about self.use_rm_matching):
        # In the experiments for the ICML paper, we included a simple graph matching approach
        # to share policies between subsets of RMs that were equivalent. We deactivated this
        # feature for the IJCAI experiments because it was too expensive and has marginal effects
        # on the performance of QRM and QRM-RS.
        self.use_rm_matching = False

    # Public methods -----------------------------------

    def get_initial_state(self):
        return self.u0

    def get_next_state(self, u1, true_props):
        if u1 < self.u_broken:
            for u2 in self.delta_u[u1]:
                if evaluate_dnf(self.delta_u[u1][u2], true_props):
                    return u2
        return self.u_broken # no transition is defined for true_props

    def get_reward(self,u1,u2,s1,a,s2,is_training):
        """
        Returns the reward associated to this transition.
        The extra reward given by RS is included only during training!
        """
        # Getting reward from the RM
        reward = 0 # NOTE: if the agent falls from the reward machine it receives reward of zero
        if u1 in self.delta_r and u2 in self.delta_r[u1]:
            reward += self.delta_r[u1][u2].get_reward(s1,a,s2)
        # Adding the reward shaping (if needed)
        rs = 0.0
        if self.use_rs and is_training:
            rs = self.gamma * self.potentials[u2] - self.potentials[u1]
        # Returning final reward
        return reward + rs

    def get_rewards_and_next_states(self, s1, a, s2, true_props, is_training):
        rewards = []
        next_states = []
        for u1 in self.U:
            u2 = self.get_next_state(u1, true_props)
            rewards.append(self.get_reward(u1,u2,s1,a,s2,is_training))
            next_states.append(u2)
        return rewards, next_states

    def get_states(self):
        return self.U

    def is_terminal_state(self, u1):
        return u1 in self.T

    def is_this_machine_equivalent(self, u1, rm2, u2):
        """
        return True iff
            this reward machine initialized at u1 is equivalent
            to the reward machine rm2 initialized at u2
        """
        if not self.use_rm_matching:
            return False
        return are_these_machines_equivalent(self, u1, rm2, u2)

    def get_useful_transitions(self, u1):
        # This is an auxiliary method used by the HRL baseline to prune "useless" options
        return [self.delta_u[u1][u2].split("&") for u2 in self.delta_u[u1] if u1 != u2]


    # Private methods -----------------------------------

    def _load_reward_machine(self, file):
        """
        Example:
            0                  # initial state
            (0,0,'!e&!n',ConstantRewardFunction(0))
            (0,1,'e&!g&!n',ConstantRewardFunction(0))
            (0,2,'e&g&!n',ConstantRewardFunction(1))
            (1,1,'!g&!n',ConstantRewardFunction(0))
            (1,2,'g&!n',ConstantRewardFunction(1))
            (2,2,'True',ConstantRewardFunction(0))
        """
        # Reading the file
        f = open(file)
        lines = [l.rstrip() for l in f]
        f.close()
        # setting the DFA
        self.u0 = eval(lines[0])
        # adding transitions
        for e in lines[1:]:
            self._add_transition(*eval(e))
        # adding terminal states
        for u1 in self.delta_u:
            if self._is_terminal(u1):
                self.T.add(u1)
        # I'm adding a dummy terminal state for cases where there is no defined transition
        self.u_broken = len(self.U)
        self._add_transition(self.u_broken, self.u_broken, 'True', ConstantRewardFunction(0))
        self.T.add(self.u_broken)
        # Sorting self.U... just because...
        self.U = sorted(self.U)

    def _is_terminal(self, u1):
        # A node is labelled as terminal if any policy is optimal for that node
        # Here, we consider 2 simple cases:
        #     - No transition is defined for u1
        #     - There is only one 'True' self-loop and the reward from "u1" to "u1" is constant
        if len(self.delta_u[u1]) == 0:
            return True
        u2 = list(self.delta_u[u1].keys())[0]
        if len(self.delta_u[u1]) == 1 and self.delta_u[u1][u2] == 'True' and self.delta_r[u1][u2].get_type() == "constant":
            return True
        return False

    def _add_state(self, u_list):
        for u in u_list:
            if u not in self.U:
                self.U.append(u)

    def _add_transition(self, u1, u2, dnf_formula, reward_function):
        # Adding machine state
        self._add_state([u1,u2])
        # Adding state-transition to delta_u
        if u1 not in self.delta_u:
            self.delta_u[u1] = {}
        self.delta_u[u1][u2] = dnf_formula
        # Adding reward-transition to delta_r
        if u1 not in self.delta_r:
            self.delta_r[u1] = {}
        self.delta_r[u1][u2] = reward_function
end
