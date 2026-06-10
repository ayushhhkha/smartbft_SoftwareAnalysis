---------------------- MODULE SmartBFT ----------------------
EXTENDS Naturals, Sequences

CONSTANT Replicas

VARIABLES proposalMsgs,
          prepareMsgs,
          commitMsgs,
          decided

Init ==
    /\ proposalMsgs = {}
    /\ prepareMsgs = {}
    /\ commitMsgs = {}
    /\ decided = {}

SendProposal ==
    /\ proposalMsgs = {}
    /\ proposalMsgs' = {"proposal"}
    /\ UNCHANGED <<prepareMsgs,
                   commitMsgs,
                   decided>>

SendPrepare ==
    /\ proposalMsgs # {}
    /\ prepareMsgs = {}
    /\ prepareMsgs' = {"prepare"}
    /\ UNCHANGED <<proposalMsgs,
                   commitMsgs,
                   decided>>

SendCommit ==
    /\ prepareMsgs # {}
    /\ commitMsgs = {}
    /\ commitMsgs' = {"commit"}
    /\ UNCHANGED <<proposalMsgs,
                   prepareMsgs,
                   decided>>

Decide ==
    /\ commitMsgs # {}
    /\ decided = {}
    /\ decided' = {"value"}
    /\ UNCHANGED <<proposalMsgs,
                   prepareMsgs,
                   commitMsgs>>

Stutter ==
    UNCHANGED <<proposalMsgs,
               prepareMsgs,
               commitMsgs,
               decided>>

Next ==
    \/ SendProposal
    \/ SendPrepare
    \/ SendCommit
    \/ Decide
    \/ Stutter


Agreement ==
    decided = {} \/ decided = {"value"}

Validity ==
    decided # {} => proposalMsgs # {}

Integrity ==
    decided # {} => commitMsgs # {}

=============================================================