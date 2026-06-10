---------------------- MODULE SmartBFT ----------------------

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Replicas, F

ASSUME 3 * F < Cardinality(Replicas)

VARIABLES leader,
          proposalMsgs,
          prepareMsgs,
          commitMsgs,
          decided

Quorum == 2* F + 1

Init ==
    /\ leader = 1
    /\ proposalMsgs = {}
    /\ prepareMsgs = {}
    /\ commitMsgs = {}
    /\ decided = {}

SendProposal ==
    /\ proposalMsgs = {}
    /\ proposalMsgs' =
        {[type |-> "PROPOSAL",
          sender |-> leader]}
    /\ UNCHANGED <<leader,
                   prepareMsgs,
                   commitMsgs,
                   decided>>

SendPrepare ==
    /\ proposalMsgs # {}
    /\ Cardinality(prepareMsgs) < Quorum
    /\ prepareMsgs' =
        prepareMsgs \cup
        {[sender |-> Cardinality(prepareMsgs) + 1]}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   commitMsgs,
                   decided>>

SendCommit ==
    /\ Cardinality(prepareMsgs) >= Quorum
    /\ Cardinality(commitMsgs) < Quorum
    /\ commitMsgs' =
        commitMsgs \cup
        {[sender |-> Cardinality(commitMsgs) + 1]}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   prepareMsgs,
                   decided>>

Decide ==
    /\ Cardinality(commitMsgs) >= Quorum
    /\ decided = {}
    /\ decided' = {"value"}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   prepareMsgs,
                   commitMsgs>>

Stutter ==
    UNCHANGED <<leader,
               proposalMsgs,
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
    Cardinality(decided) <= 1

Validity ==
    decided # {} => proposalMsgs # {}

Integrity ==
    decided # {} => Cardinality(commitMsgs) >= Quorum

CommitImpliesPrepare ==
    Cardinality(commitMsgs) > 0 =>
    Cardinality(prepareMsgs) >= Quorum

=============================================================