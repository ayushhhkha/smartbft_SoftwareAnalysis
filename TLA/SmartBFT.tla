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

=============================================================