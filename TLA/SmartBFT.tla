---------------------- MODULE SmartBFT ----------------------

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Replicas, F

ASSUME 3 * F < Cardinality(Replicas)

VARIABLES leader,
          proposalMsgs,
          writeMsg,
          acceptMsgs,
          decided

Quorum == 2* F + 1

Init ==
    /\ leader = 1
    /\ proposalMsgs = {}
    /\ writeMsg = {}
    /\ acceptMsgs = {}
    /\ decided = {}

SendProposal ==
    /\ proposalMsgs = {}
    /\ proposalMsgs' =
        {[type |-> "PROPOSAL",
          sender |-> leader]}
    /\ UNCHANGED <<leader,
                   writeMsg,
                   acceptMsgs,
                   decided>>

SendWrite ==
    /\ proposalMsgs # {}
    /\ Cardinality(writeMsg) < Quorum
    /\ writeMsg' =
        writeMsg \cup
        {[sender |-> Cardinality(writeMsg) + 1]}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   acceptMsgs,
                   decided>>

SendAccept ==
    /\ Cardinality(writeMsg) >= Quorum
    /\ Cardinality(acceptMsgs) < Quorum
    /\ acceptMsgs' =
        acceptMsgs \cup
        {[sender |-> Cardinality(acceptMsgs) + 1]}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   writeMsg,
                   decided>>

Decide ==
    /\ Cardinality(acceptMsgs) >= Quorum
    /\ decided = {}
    /\ decided' = {"value"}
    /\ UNCHANGED <<leader,
                   proposalMsgs,
                   writeMsg,
                   acceptMsgs>>

Stutter ==
    UNCHANGED <<leader,
               proposalMsgs,
               writeMsg,
               acceptMsgs,
               decided>>

Next ==
    \/ SendProposal
    \/ SendWrite
    \/ SendAccept
    \/ Decide
    \/ Stutter

Agreement ==
    Cardinality(decided) <= 1

Validity ==
    decided # {} => proposalMsgs # {}

Integrity ==
    decided # {} => Cardinality(acceptMsgs) >= Quorum

CommitImpliesPrepare ==
    Cardinality(acceptMsgs) > 0 =>
    Cardinality(writeMsg) >= Quorum

=============================================================