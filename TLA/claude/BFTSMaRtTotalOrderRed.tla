-------------------------- MODULE BFTSMaRtTotalOrderRed --------------------------
(***************************************************************************)
(* Sound state-space reduction of the multi-instance total-order model for *)
(* the Byzantine configuration.                                            *)
(*                                                                         *)
(* Soundness argument: when no Byzantine replica is the leader (here       *)
(* Leader=0, Byzantine={3}), a Byzantine PROPOSE is INERT -- the only      *)
(* consumer of a PROPOSE is `LeaderProposed`, which requires the sender to *)
(* be the leader, so a PROPOSE from a non-leader is never matched by any   *)
(* correct action.  Dropping Byzantine PROPOSE from the adversary's        *)
(* repertoire therefore removes no reachable behaviour of correct          *)
(* replicas, and all safety verdicts carry over to the full model.         *)
(*                                                                         *)
(* The adversary still injects arbitrary WRITE/ACCEPT (the only Byzantine  *)
(* messages that can actually influence a quorum certificate).             *)
(***************************************************************************)
EXTENDS BFTSMaRtTotalOrder

NextRed ==
    \/ \E c \in Consensus, v \in Values : Propose(c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : SendWrite(r, c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : SendAccept(r, c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : Decide(r, c, v)
    \/ \E r \in Replicas, c \in Consensus,
          t \in {"WRITE","ACCEPT"}, v \in Values : ByzantineSend(r, c, t, v)
    \/ Stutter

SpecRed == Init /\ [][NextRed]_vars

=============================================================================
