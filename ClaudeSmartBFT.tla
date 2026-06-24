----------------------------- MODULE ClaudeSmartBFT -----------------------------
(***************************************************************************)
(* Multi-instance extension of the BFT-SMaRt VP-Consensus model, used to   *)
(* verify TOTAL ORDER (the Mod-SMaRt atomic-multicast guarantee on top of  *)
(* a sequence of consensus instances).                                     *)
(*                                                                         *)
(* Each consensus instance (cid) runs an independent VP-Consensus, exactly *)
(* as in BFTSMaRt.tla, but now every state component and every message is  *)
(* indexed by the consensus id.  Still ONE epoch per instance (no leader   *)
(* change) -- the new dimension is the SEQUENCE of instances, which is     *)
(* what total order is about.  Instances are NOT serialized: any instance  *)
(* may make progress at any time, so total order is genuinely exercised    *)
(* (rather than enforced by construction).                                 *)
(*                                                                         *)
(* DELIVERY is not modelled with a separate action/variable.  The committed*)
(* log of a replica is its contiguous decided prefix; `Delivered(r)` is the*)
(* equivalent "would-deliver" set (deliverability test) and CommittedLen   *)
(* its length.  Total order = those prefixes never diverge.                *)
(*                                                                         *)
(* INPUT INTERFACE: shares the constant names and 1..MaxConsensus indexing *)
(* of SmartBFT.tla so the SAME configs/ files run on both models.          *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Replicas,      \* set of replica ids
    Values,        \* client values (batches) the leader may propose
    F,             \* max faults tolerated
    Faulty,        \* faulty replicas (|Faulty| <= F)   [SmartBFT name]
    Leader,        \* leader (same across instances within the single epoch)
    NoValue,       \* "no value yet" marker              [SmartBFT name]
    MaxConsensus   \* instances are 1 .. MaxConsensus    [SmartBFT name]

ASSUME LeaderIsReplica == Leader \in Replicas
ASSUME FaultySubset    == Faulty \subseteq Replicas
ASSUME FaultBound      == Cardinality(Faulty) <= F
ASSUME NoValueFresh    == NoValue \notin Values
ASSUME BFTBound        == 3 * F < Cardinality(Replicas)
ASSUME ConsensusNonEmpty == MaxConsensus \in Nat /\ MaxConsensus >= 1

Correct   == Replicas \ Faulty
N         == Cardinality(Replicas)
Consensus == 1 .. MaxConsensus
Symmetry  == Permutations(Values)

(***************************************************************************)
(* The BFT quorum threshold.  A WRITE / ACCEPT certificate is complete    *)
(* when MORE THAN Quorum distinct replicas vouch for the same value.      *)
(* This is BFT-SMaRt's `count > getQuorum()` with getQuorum() = (n+f)/2;  *)
(* for n = 3f+1 it equals the textbook >= 2f+1.                           *)
(***************************************************************************)
Quorum == (N + F) \div 2

Message == [type : {"PROPOSE", "WRITE", "ACCEPT"},
            cid : Consensus,
            sender : Replicas,
            val : Values]

VARIABLES
    sent,      \* set of messages broadcast so far (network), each tagged with cid
    written,   \* [Replicas -> [Consensus -> Values \cup {NoValue}]]
    accepted,  \* [Replicas -> [Consensus -> Values \cup {NoValue}]]
    decided    \* [Replicas -> [Consensus -> Values \cup {NoValue}]]

vars == <<sent, written, accepted, decided>>

\* Distinct senders of message type t for instance c and value v.  The cid
\* filter keeps each instance's certificate independent of the others'.
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
    /\ written  = [r \in Replicas |-> [c \in Consensus |-> NoValue]]
    /\ accepted = [r \in Replicas |-> [c \in Consensus |-> NoValue]]
    /\ decided  = [r \in Replicas |-> [c \in Consensus |-> NoValue]]

\* Correct leader proposes one value for instance c (at most once per instance).
\* The "at most once" guard keys on the LEADER's own proposal, not any PROPOSE:
\* a Byzantine replica can forge a PROPOSE (sender # Leader), and that must not
\* disable the honest leader's proposal (which would break liveness under WF).
Propose(c, v) ==
    /\ Leader \in Correct
    /\ \A m \in sent : ~(m.type = "PROPOSE" /\ m.sender = Leader /\ m.cid = c)
    /\ sent' = sent \cup {[type |-> "PROPOSE", cid |-> c, sender |-> Leader, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

SendWrite(r, c, v) ==
    /\ r \in Correct
    /\ written[r][c] = NoValue
    /\ LeaderProposed(c, v)
    /\ sent' = sent \cup {[type |-> "WRITE", cid |-> c, sender |-> r, val |-> v]}
    /\ written' = [written EXCEPT ![r][c] = v]
    /\ UNCHANGED <<accepted, decided>>

SendAccept(r, c, v) ==
    /\ r \in Correct
    /\ accepted[r][c] = NoValue
    /\ written[r][c] = v
    /\ WriteCertified(c, v)
    /\ sent' = sent \cup {[type |-> "ACCEPT", cid |-> c, sender |-> r, val |-> v]}
    /\ accepted' = [accepted EXCEPT ![r][c] = v]
    /\ UNCHANGED <<written, decided>>

Decide(r, c, v) ==
    /\ r \in Correct
    /\ decided[r][c] = NoValue
    /\ accepted[r][c] = v
    /\ AcceptCertified(c, v)
    /\ decided' = [decided EXCEPT ![r][c] = v]
    /\ UNCHANGED <<sent, written, accepted>>

ByzantineSend(r, c, t, v) ==
    /\ r \in Faulty
    /\ sent' = sent \cup {[type |-> t, cid |-> c, sender |-> r, val |-> v]}
    /\ UNCHANGED <<written, accepted, decided>>

-----------------------------------------------------------------------------
\* Explicit stuttering: a no-op for the temporal spec ([][Next]_vars already
\* permits stuttering), present only so TLC does not report a "deadlock" when
\* every instance has decided.  Matches SmartBFT.tla's Stutter for parity.
Stutter == UNCHANGED vars

Next ==
    \/ \E c \in Consensus, v \in Values : Propose(c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : SendWrite(r, c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : SendAccept(r, c, v)
    \/ \E r \in Replicas, c \in Consensus, v \in Values : Decide(r, c, v)
    \/ \E r \in Replicas, c \in Consensus,
          t \in {"PROPOSE","WRITE","ACCEPT"}, v \in Values : ByzantineSend(r, c, t, v)
    \/ Stutter

Spec == Init /\ [][Next]_vars

FairSpec ==
    /\ Spec
    /\ \A c \in Consensus, v \in Values : WF_vars(Propose(c, v))
    /\ \A r \in Replicas, c \in Consensus, v \in Values : WF_vars(SendWrite(r, c, v))
    /\ \A r \in Replicas, c \in Consensus, v \in Values : WF_vars(SendAccept(r, c, v))
    /\ \A r \in Replicas, c \in Consensus, v \in Values : WF_vars(Decide(r, c, v))

-----------------------------------------------------------------------------
(***************************************************************************)
(* DELIVERABILITY.  No explicit delivery action; a replica "would deliver" *)
(* exactly its contiguous decided prefix.                                  *)
(***************************************************************************)

\* The would-deliver set: instances c whose whole prefix 1..c has decided.
Delivered(r) == { c \in Consensus : \A d \in 1 .. c : decided[r][d] # NoValue }

\* Length of the contiguous decided prefix (0,1,2,... with no gap).
CommittedLen(r) == Cardinality(Delivered(r))

-----------------------------------------------------------------------------
(***************************************************************************)
(*                       CORRECTNESS PROPERTIES                            *)
(*                                                                         *)
(* The first block uses the SAME names/semantics as SmartBFT.tla so the    *)
(* shared configs resolve identically on both models.  The second block    *)
(* adds the stronger multi-instance properties.                            *)
(***************************************************************************)

TypeOK ==
    /\ sent \subseteq Message
    /\ written  \in [Replicas -> [Consensus -> Values \cup {NoValue}]]
    /\ accepted \in [Replicas -> [Consensus -> Values \cup {NoValue}]]
    /\ decided  \in [Replicas -> [Consensus -> Values \cup {NoValue}]]

\* AGREEMENT (per instance): no two correct replicas decide different values
\* for the SAME consensus instance.  (SmartBFT.tla: Agreement.)
Agreement ==
    \A c \in Consensus :
        \A r1, r2 \in Correct :
            (decided[r1][c] # NoValue /\ decided[r2][c] # NoValue)
                => decided[r1][c] = decided[r2][c]

\* VALIDITY: a correct replica decides only a value the leader proposed.
Validity ==
    \A r \in Correct, c \in Consensus :
        decided[r][c] # NoValue => LeaderProposed(c, decided[r][c])

\* INTEGRITY (SmartBFT semantics): a correct replica decides only when an
\* ACCEPT quorum exists for the decided value (certificate-backed).
Integrity ==
    \A r \in Correct, c \in Consensus :
        decided[r][c] # NoValue => AcceptCertified(c, decided[r][c])

\* ACCEPT-IMPLIES-WRITE: a correct replica sends ACCEPT for a value only
\* after a WRITE quorum for it exists.  (SmartBFT.tla: AcceptImpliesWrite.)
AcceptImpliesWrite ==
    \A m \in sent :
        (m.type = "ACCEPT" /\ m.sender \in Correct) => WriteCertified(m.cid, m.val)

\* ORDERED DELIVERY: the would-deliver set of each correct replica is a
\* downward-closed prefix.  (SmartBFT.tla: OrderedDelivery, here read off the
\* deliverability set instead of an explicit delivered[] variable.)
OrderedDelivery ==
    \A r \in Correct :
        \A c \in Delivered(r) :
            \A d \in Consensus : d < c => d \in Delivered(r)

-----------------------------------------------------------------------------
\* DECISION MATCHES ACCEPT (own-accept facet of integrity): a correct replica
\* decides the very value it itself accepted.
DecisionMatchesAccept ==
    \A r \in Correct, c \in Consensus :
        decided[r][c] # NoValue => accepted[r][c] = decided[r][c]

\* CERTIFICATE UNIQUENESS, per instance: at most one value gets a 2f+1 ACCEPT
\* certificate in any given instance.
CertificateUniqueness ==
    \A c \in Consensus :
        \A v1, v2 \in Values :
            (AcceptCertified(c, v1) /\ AcceptCertified(c, v2)) => v1 = v2

(*-------------------------------------------------------------------------*)
(* TOTAL ORDER.  For any two correct replicas, the committed (contiguous   *)
(* decided) prefixes agree on every common slot -- one log is a prefix of  *)
(* the other, never a divergent fork.                                      *)
(*-------------------------------------------------------------------------*)
TotalOrder ==
    \A r1, r2 \in Correct :
        \A c \in Consensus :
            (c <= CommittedLen(r1) /\ c <= CommittedLen(r2))
                => decided[r1][c] = decided[r2][c]

\* GAP FREEDOM of the committed prefix (structural; stated for clarity).
PrefixGapFree ==
    \A r \in Correct, c \in Consensus :
        (c <= CommittedLen(r)) => decided[r][c] # NoValue

\* TERMINATION (liveness): every correct replica eventually decides every
\* instance (all-correct, synchronous, fair configuration).
Termination ==
    <>(\A r \in Correct, c \in Consensus : decided[r][c] # NoValue)

=============================================================================
