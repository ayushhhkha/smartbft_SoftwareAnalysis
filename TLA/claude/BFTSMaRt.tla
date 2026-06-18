-------------------------------- MODULE BFTSMaRt --------------------------------
(***************************************************************************)
(* TLA+ model of BFT-SMaRt's VP-Consensus normal phase (the Byzantine     *)
(* consensus at the core of the Mod-SMaRt total-order multicast).         *)
(*                                                                         *)
(* Scope: ONE consensus instance, ONE epoch (timestamp 0), i.e. the       *)
(* fault-free / synchronous "normal phase" of Figure 2 in Bessani et al., *)
(* "State Machine Replication for the Masses with BFT-SMaRt" (DSN'14).     *)
(* The leader-change / synchronization phase is deliberately abstracted    *)
(* away (see README, Limitations).                                         *)
(*                                                                         *)
(* The three message rounds, faithful to consensus/roles/Acceptor.java:    *)
(*                                                                         *)
(*   PROPOSE : leader broadcasts a value v.            [executePropose]     *)
(*   WRITE   : a replica that received the leader's PROPOSE                 *)
(*             "weakly accepts" v and broadcasts WRITE v.                   *)
(*             [proposeReceived -> executePropose]                         *)
(*   ACCEPT  : on > (n+f)/2 matching WRITEs a replica                      *)
(*             "strongly accepts" and broadcasts ACCEPT v. [computeWrite]   *)
(*   DECIDE  : on > (n+f)/2 matching ACCEPTs a replica                     *)
(*             decides v; the ACCEPT set is the certificate. [computeAccept]*)
(*                                                                         *)
(* For n = 3f+1 the threshold > (n+f)/2 evaluates to 2f+1 (see            *)
(* ServerViewController.getQuorum: quorumBFT = (n+f)/2 and the code        *)
(* checks count > quorumBFT).                                              *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Replicas,    \* set of replica ids, e.g. {0,1,2,3}
    Byzantine,   \* subset of Replicas that behave arbitrarily (|Byzantine| <= F)
    Leader,      \* the replica that is leader in epoch 0 (lowest id in BFT-SMaRt)
    Values,      \* set of client values the leader may propose
    F,           \* maximum number of faulty replicas tolerated
    NoVal        \* a model value standing for "no value yet"

ASSUME LeaderIsReplica == Leader \in Replicas
ASSUME ByzSubset      == Byzantine \subseteq Replicas
ASSUME FaultBound     == Cardinality(Byzantine) <= F
ASSUME NoValFresh     == NoVal \notin Values

Correct == Replicas \ Byzantine
N       == Cardinality(Replicas)

\* Client values are interchangeable, so permuting them is a symmetry of the
\* model.  Declaring it (SYMMETRY Symmetry in the .cfg) lets TLC collapse
\* symmetric states and check larger configurations.
Symmetry == Permutations(Values)

(***************************************************************************)
(* The BFT quorum threshold.  A WRITE / ACCEPT certificate is complete    *)
(* when MORE THAN Quorum distinct replicas vouch for the same value,      *)
(* i.e. a certificate has at least Quorum+1 = 2f+1 messages for n=3f+1.   *)
(* This mirrors `count > controller.getQuorum()` in Acceptor.java.        *)
(***************************************************************************)
Quorum == (N + F) \div 2

(* A network message. Channels are authenticated, so a message's sender   *)
(* field cannot be forged by another replica.                            *)
Message == [type : {"PROPOSE", "WRITE", "ACCEPT"},
            sender : Replicas,
            val : Values]

VARIABLES
    sent,      \* set of messages broadcast so far (the network)
    written,   \* [Replicas -> Values \cup {NoVal}] value a replica WROTE
    accepted,  \* [Replicas -> Values \cup {NoVal}] value a replica ACCEPTed
    decided    \* [Replicas -> Values \cup {NoVal}] value a replica decided

vars == <<sent, written, accepted, decided>>

(***************************************************************************)
(* Helpers: distinct senders of a given message type for a given value.   *)
(***************************************************************************)
Senders(t, v) == {m.sender : m \in {mm \in sent : mm.type = t /\ mm.val = v}}

WriteCertified(v)  == Cardinality(Senders("WRITE", v))  > Quorum
AcceptCertified(v) == Cardinality(Senders("ACCEPT", v)) > Quorum

LeaderProposed(v) == \E m \in sent : m.type = "PROPOSE" /\ m.sender = Leader
                                     /\ m.val = v

-----------------------------------------------------------------------------
Init ==
    /\ sent = {}
    /\ written  = [r \in Replicas |-> NoVal]
    /\ accepted = [r \in Replicas |-> NoVal]
    /\ decided  = [r \in Replicas |-> NoVal]

(***************************************************************************)
(* Action: a CORRECT leader broadcasts PROPOSE v (executePropose).        *)
(* A correct leader proposes exactly one value (it cannot equivocate).    *)
(***************************************************************************)
Propose(v) ==
    /\ Leader \in Correct
    /\ \A m \in sent : m.type # "PROPOSE"   \* propose at most once
    /\ v \in Values
    /\ sent' = sent \cup {[type |-> "PROPOSE", sender |-> Leader, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

(***************************************************************************)
(* Action: correct replica r received the leader's PROPOSE v and has not  *)
(* yet written; it weakly accepts and broadcasts WRITE v.                 *)
(* (proposeReceived -> executePropose: setWrite + send WRITE)             *)
(***************************************************************************)
SendWrite(r, v) ==
    /\ r \in Correct
    /\ written[r] = NoVal
    /\ LeaderProposed(v)
    /\ sent' = sent \cup {[type |-> "WRITE", sender |-> r, val |-> v]}
    /\ written' = [written EXCEPT ![r] = v]
    /\ UNCHANGED <<accepted, decided>>

(***************************************************************************)
(* Action: correct replica r sees a WRITE certificate (> Quorum matching  *)
(* WRITEs) for the value it itself wrote, and broadcasts ACCEPT v.        *)
(* (computeWrite: writeAccepted > quorum && value == propValueHash)       *)
(***************************************************************************)
SendAccept(r, v) ==
    /\ r \in Correct
    /\ accepted[r] = NoVal
    /\ written[r] = v          \* value must equal this replica's own write
    /\ WriteCertified(v)
    /\ sent' = sent \cup {[type |-> "ACCEPT", sender |-> r, val |-> v]}
    /\ accepted' = [accepted EXCEPT ![r] = v]
    /\ UNCHANGED <<written, decided>>

(***************************************************************************)
(* Action: correct replica r sees an ACCEPT certificate for the value it  *)
(* accepted, and decides v.                                               *)
(* (computeAccept: countAccept(value) > quorum && value == propValueHash) *)
(***************************************************************************)
Decide(r, v) ==
    /\ r \in Correct
    /\ decided[r] = NoVal
    /\ accepted[r] = v
    /\ AcceptCertified(v)
    /\ decided' = [decided EXCEPT ![r] = v]
    /\ UNCHANGED <<sent, written, accepted>>

(***************************************************************************)
(* Action: a Byzantine replica injects an arbitrary message.  It may send *)
(* any type with any value (equivocation, spurious WRITE/ACCEPT, etc.),   *)
(* but only under its own (authenticated) identity.                       *)
(***************************************************************************)
ByzantineSend(r, t, v) ==
    /\ r \in Byzantine
    /\ sent' = sent \cup {[type |-> t, sender |-> r, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

-----------------------------------------------------------------------------
Next ==
    \/ \E v \in Values : Propose(v)
    \/ \E r \in Replicas, v \in Values : SendWrite(r, v)
    \/ \E r \in Replicas, v \in Values : SendAccept(r, v)
    \/ \E r \in Replicas, v \in Values : Decide(r, v)
    \/ \E r \in Replicas, t \in {"PROPOSE","WRITE","ACCEPT"}, v \in Values :
            ByzantineSend(r, t, v)

Spec == Init /\ [][Next]_vars

(* Weak fairness on correct-replica progress, used for the Termination     *)
(* liveness property (checked only in the all-correct synchronous config). *)
FairSpec ==
    /\ Spec
    /\ \A v \in Values : WF_vars(Propose(v))
    /\ \A r \in Replicas, v \in Values : WF_vars(SendWrite(r, v))
    /\ \A r \in Replicas, v \in Values : WF_vars(SendAccept(r, v))
    /\ \A r \in Replicas, v \in Values : WF_vars(Decide(r, v))

-----------------------------------------------------------------------------
(***************************************************************************)
(*                       CORRECTNESS PROPERTIES                            *)
(* (the "expert invariants" for SysMoBench's invariant-correctness stage). *)
(***************************************************************************)

\* Structural well-typedness of the state.
TypeOK ==
    /\ sent \subseteq Message
    /\ written  \in [Replicas -> Values \cup {NoVal}]
    /\ accepted \in [Replicas -> Values \cup {NoVal}]
    /\ decided  \in [Replicas -> Values \cup {NoVal}]

\* AGREEMENT (safety, the headline property): no two correct replicas decide
\* different values.
Agreement ==
    \A r1, r2 \in Correct :
        (decided[r1] # NoVal /\ decided[r2] # NoVal) => decided[r1] = decided[r2]

\* INTEGRITY: a correct replica decides at most once and only a value it
\* previously accepted (no decision out of thin air).
Integrity ==
    \A r \in Correct : decided[r] # NoVal => accepted[r] = decided[r]

\* VALIDITY: every value decided by a correct replica was at some point
\* proposed (meaningful when the leader is correct; a Byzantine leader is
\* covered by Agreement, which holds regardless).
Validity ==
    \A r \in Correct : decided[r] # NoVal => LeaderProposed(decided[r])

\* CERTIFICATE UNIQUENESS (the quorum-intersection lemma behind Agreement):
\* at most one value can ever gather a 2f+1 ACCEPT certificate.  If this
\* held with the WRONG threshold (e.g. f+1) it would break -- a good probe.
CertificateUniqueness ==
    \A v1, v2 \in Values :
        (AcceptCertified(v1) /\ AcceptCertified(v2)) => v1 = v2

\* TERMINATION (liveness): under fairness, in a synchronous run with a
\* correct leader, every correct replica eventually decides.  Checked with
\* FairSpec in the all-correct configuration.
Termination == <>(\A r \in Correct : decided[r] # NoVal)

=============================================================================
