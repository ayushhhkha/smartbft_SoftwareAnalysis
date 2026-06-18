--------------------------- MODULE BFTSMaRtTotalOrder ---------------------------
(***************************************************************************)
(* Multi-instance extension of the BFT-SMaRt VP-Consensus model, used to   *)
(* verify TOTAL ORDER (the Mod-SMaRt atomic-multicast guarantee on top of  *)
(* a sequence of consensus instances).                                     *)
(*                                                                         *)
(* Each consensus instance (cid) runs an independent VP-Consensus, exactly *)
(* as in BFTSMaRt.tla, but now every state component and every message is  *)
(* indexed by the consensus id.  Still ONE epoch per instance (no leader   *)
(* change) -- the new dimension is the SEQUENCE of instances, which is     *)
(* what total order is about.                                              *)
(*                                                                         *)
(* In BFT-SMaRt, DeliveryThread delivers decided consensus instances to    *)
(* the application in cid order; the committed log of a replica is thus    *)
(* the contiguous decided prefix 0,1,2,...  Total order = those logs never *)
(* diverge.                                                                *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Replicas,    \* set of replica ids
    Byzantine,   \* faulty replicas (|Byzantine| <= F)
    Leader,      \* leader (same across instances within the single epoch)
    Values,      \* client values (batches) the leader may propose
    F,           \* max faults tolerated
    MaxInstance, \* instances are 0 .. MaxInstance
    NoVal        \* "no value yet" marker

ASSUME Leader \in Replicas
ASSUME Byzantine \subseteq Replicas
ASSUME Cardinality(Byzantine) <= F
ASSUME NoVal \notin Values
ASSUME MaxInstance \in Nat

Correct   == Replicas \ Byzantine
N         == Cardinality(Replicas)
Instances == 0 .. MaxInstance
Quorum    == (N + F) \div 2
Symmetry  == Permutations(Values)

Message == [type : {"PROPOSE", "WRITE", "ACCEPT"},
            cid : Instances,
            sender : Replicas,
            val : Values]

VARIABLES
    sent,      \* set of messages broadcast so far (network), each tagged with cid
    written,   \* [Replicas -> [Instances -> Values \cup {NoVal}]]
    accepted,  \* [Replicas -> [Instances -> Values \cup {NoVal}]]
    decided    \* [Replicas -> [Instances -> Values \cup {NoVal}]]

vars == <<sent, written, accepted, decided>>

\* Distinct senders of message type t for instance c and value v.  Note the
\* cid filter: a certificate for one instance must NOT draw on another
\* instance's messages.
Senders(t, c, v) ==
    {m.sender : m \in {mm \in sent : mm.type = t /\ mm.cid = c /\ mm.val = v}}

WriteCertified(c, v)  == Cardinality(Senders("WRITE", c, v))  > Quorum
AcceptCertified(c, v) == Cardinality(Senders("ACCEPT", c, v)) > Quorum

LeaderProposed(c, v) ==
    \E m \in sent : m.type = "PROPOSE" /\ m.sender = Leader
                    /\ m.cid = c /\ m.val = v

-----------------------------------------------------------------------------
Init ==
    /\ sent = {}
    /\ written  = [r \in Replicas |-> [c \in Instances |-> NoVal]]
    /\ accepted = [r \in Replicas |-> [c \in Instances |-> NoVal]]
    /\ decided  = [r \in Replicas |-> [c \in Instances |-> NoVal]]

\* Correct leader proposes one value for instance c (at most once per instance).
Propose(c, v) ==
    /\ Leader \in Correct
    /\ \A m \in sent : ~(m.type = "PROPOSE" /\ m.cid = c)
    /\ sent' = sent \cup {[type |-> "PROPOSE", cid |-> c, sender |-> Leader, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

SendWrite(r, c, v) ==
    /\ r \in Correct
    /\ written[r][c] = NoVal
    /\ LeaderProposed(c, v)
    /\ sent' = sent \cup {[type |-> "WRITE", cid |-> c, sender |-> r, val |-> v]}
    /\ written' = [written EXCEPT ![r][c] = v]
    /\ UNCHANGED <<accepted, decided>>

SendAccept(r, c, v) ==
    /\ r \in Correct
    /\ accepted[r][c] = NoVal
    /\ written[r][c] = v
    /\ WriteCertified(c, v)
    /\ sent' = sent \cup {[type |-> "ACCEPT", cid |-> c, sender |-> r, val |-> v]}
    /\ accepted' = [accepted EXCEPT ![r][c] = v]
    /\ UNCHANGED <<written, decided>>

Decide(r, c, v) ==
    /\ r \in Correct
    /\ decided[r][c] = NoVal
    /\ accepted[r][c] = v
    /\ AcceptCertified(c, v)
    /\ decided' = [decided EXCEPT ![r][c] = v]
    /\ UNCHANGED <<sent, written, accepted>>

ByzantineSend(r, c, t, v) ==
    /\ r \in Byzantine
    /\ sent' = sent \cup {[type |-> t, cid |-> c, sender |-> r, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

-----------------------------------------------------------------------------
Next ==
    \/ \E c \in Instances, v \in Values : Propose(c, v)
    \/ \E r \in Replicas, c \in Instances, v \in Values : SendWrite(r, c, v)
    \/ \E r \in Replicas, c \in Instances, v \in Values : SendAccept(r, c, v)
    \/ \E r \in Replicas, c \in Instances, v \in Values : Decide(r, c, v)
    \/ \E r \in Replicas, c \in Instances,
          t \in {"PROPOSE","WRITE","ACCEPT"}, v \in Values : ByzantineSend(r, c, t, v)

Spec == Init /\ [][Next]_vars

FairSpec ==
    /\ Spec
    /\ \A c \in Instances, v \in Values : WF_vars(Propose(c, v))
    /\ \A r \in Replicas, c \in Instances, v \in Values : WF_vars(SendWrite(r, c, v))
    /\ \A r \in Replicas, c \in Instances, v \in Values : WF_vars(SendAccept(r, c, v))
    /\ \A r \in Replicas, c \in Instances, v \in Values : WF_vars(Decide(r, c, v))

-----------------------------------------------------------------------------
(***************************************************************************)
(*                       CORRECTNESS PROPERTIES                            *)
(***************************************************************************)

TypeOK ==
    /\ sent \subseteq Message
    /\ written  \in [Replicas -> [Instances -> Values \cup {NoVal}]]
    /\ accepted \in [Replicas -> [Instances -> Values \cup {NoVal}]]
    /\ decided  \in [Replicas -> [Instances -> Values \cup {NoVal}]]

\* AGREEMENT, per instance: no two correct replicas decide different values
\* for the SAME consensus instance.  This is the mechanism underlying total
\* order.
AgreementPerInstance ==
    \A c \in Instances :
        \A r1, r2 \in Correct :
            (decided[r1][c] # NoVal /\ decided[r2][c] # NoVal)
                => decided[r1][c] = decided[r2][c]

\* INTEGRITY / VALIDITY, per instance (as in the single-instance model).
Integrity ==
    \A r \in Correct, c \in Instances :
        decided[r][c] # NoVal => accepted[r][c] = decided[r][c]

Validity ==
    \A r \in Correct, c \in Instances :
        decided[r][c] # NoVal => LeaderProposed(c, decided[r][c])

\* CERTIFICATE UNIQUENESS, per instance: at most one value gets a 2f+1 ACCEPT
\* certificate in any given instance (and -- via the cid filter in Senders --
\* certificates never leak across instances).
CertificateUniqueness ==
    \A c \in Instances :
        \A v1, v2 \in Values :
            (AcceptCertified(c, v1) /\ AcceptCertified(c, v2)) => v1 = v2

(*-------------------------------------------------------------------------*)
(* TOTAL ORDER.                                                            *)
(* The committed log of a replica is its contiguous decided prefix         *)
(* 0,1,...  Total order: for any two correct replicas, the logs agree on    *)
(* every slot in their common committed prefix -- i.e. one log is a prefix *)
(* of the other, never a divergent fork.                                   *)
(*-------------------------------------------------------------------------*)

\* Length of the contiguous decided prefix of replica r (0,1,2,... with no gap).
CommittedLen(r) ==
    Cardinality({ c \in Instances : \A d \in 0 .. c : decided[r][d] # NoVal })

TotalOrder ==
    \A r1, r2 \in Correct :
        \A c \in Instances :
            (c < CommittedLen(r1) /\ c < CommittedLen(r2))
                => decided[r1][c] = decided[r2][c]

\* GAP FREEDOM of the committed prefix is structural (CommittedLen counts a
\* contiguous run), so a replica never "commits" instance c+1 to its log
\* without c.  Stated as an invariant for clarity.
PrefixGapFree ==
    \A r \in Correct, c \in Instances :
        (c < CommittedLen(r)) => decided[r][c] # NoVal

\* TERMINATION (liveness): every correct replica eventually decides every
\* instance (all-correct, synchronous, fair configuration).
Termination ==
    <>(\A r \in Correct, c \in Instances : decided[r][c] # NoVal)

=============================================================================
