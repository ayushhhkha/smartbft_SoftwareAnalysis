------------------------------ MODULE SmartBFT ------------------------------

EXTENDS Naturals, FiniteSets

(*
    This model captures a simplified version of the BFT-SMaRt normal
    consensus phase for ONE consensus instance.

    The paper's normal phase is:

        PROPOSE -> WRITE -> ACCEPT -> DECIDE

    One consensus instance decides one value.
    In BFT-SMaRt, that value would usually be a batch of client requests.
    Here, we abstract batches as simple values from the set Values.
*)

CONSTANTS
    Replicas,   \* Set of all replicas, e.g. {1,2,3,4}
    Values,     \* Possible proposed batches/values, e.g. {v1, v2}
    F,          \* Maximum number of Byzantine faulty replicas
    Faulty,     \* Set of replicas that may behave Byzantine
    Leader,     \* The current leader for this consensus instance
    NoValue     \* Special value meaning "this replica has not decided yet"

(*
    Basic BFT assumptions.

    For Byzantine fault tolerance, we need:

        n >= 3f + 1

    Written equivalently as:

        3f < n

    We also assume the configured Faulty set contains at most F replicas.
*)
ASSUME /\ 3 * F < Cardinality(Replicas)
       /\ Faulty \subseteq Replicas
       /\ Cardinality(Faulty) <= F
       /\ Leader \in Replicas
       /\ NoValue \notin Values

Correct == Replicas \ Faulty

(*
    In BFT protocols, the usual quorum size is:

        2f + 1

    For example, with f = 1 and n = 4, quorum = 3.
*)
Quorum == 2 * F + 1

VARIABLES
    proposalMsgs,  \* PROPOSE messages sent by the leader
    writeMsgs,     \* WRITE messages sent by replicas
    acceptMsgs,    \* ACCEPT messages sent by replicas
    decided        \* decided[r] = value decided by replica r, or NoValue

vars == <<proposalMsgs, writeMsgs, acceptMsgs, decided>>

(*
    Message representation:

    A proposal message is a record:
        [sender |-> Leader, value |-> v]

    A write/accept message is a record:
        [sender |-> r, value |-> v]

    We do not include message type in the record because messages are
    already separated into proposalMsgs, writeMsgs, and acceptMsgs.
*)

TypeOK ==
    /\ proposalMsgs \subseteq [sender: {Leader}, value: Values]
    /\ writeMsgs \subseteq [sender: Replicas, value: Values]
    /\ acceptMsgs \subseteq [sender: Replicas, value: Values]
    /\ decided \in [Replicas -> Values \cup {NoValue}]

Init ==
    /\ proposalMsgs = {}
    /\ writeMsgs = {}
    /\ acceptMsgs = {}
    /\ decided = [r \in Replicas |-> NoValue]

(***************************************************************************)
(* Helper predicates                                                        *)
(***************************************************************************)

HasProposal(v) ==
    \E m \in proposalMsgs:
        /\ m.sender = Leader
        /\ m.value = v

HasWriteFrom(r) ==
    \E m \in writeMsgs:
        m.sender = r

HasAcceptFrom(r) ==
    \E m \in acceptMsgs:
        m.sender = r

WriteSenders(v) ==
    {m.sender : m \in writeMsgs /\ m.value = v}

AcceptSenders(v) ==
    {m.sender : m \in acceptMsgs /\ m.value = v}

WriteQuorum(v) ==
    Cardinality(WriteSenders(v)) >= Quorum

AcceptQuorum(v) ==
    Cardinality(AcceptSenders(v)) >= Quorum

(***************************************************************************)
(* Protocol actions                                                         *)
(***************************************************************************)

(*
    Correct leader behavior:

    If the leader is correct, it proposes exactly one value.
    This abstracts the leader collecting pending client requests into
    a batch and proposing that batch for this consensus instance.
*)
CorrectLeaderPropose ==
    /\ Leader \in Correct
    /\ proposalMsgs = {}
    /\ \E v \in Values:
        /\ proposalMsgs' = proposalMsgs \cup {[sender |-> Leader, value |-> v]}
        /\ UNCHANGED <<writeMsgs, acceptMsgs, decided>>

(*
    Byzantine leader behavior:

    If the leader is faulty, it may propose any value.
    Since proposalMsgs is a set, it can eventually contain multiple
    different proposals from the faulty leader.

    This models the idea that a Byzantine leader may equivocate:
    it can send conflicting proposals to different replicas.
*)
FaultyLeaderPropose ==
    /\ Leader \in Faulty
    /\ \E v \in Values:
        /\ [sender |-> Leader, value |-> v] \notin proposalMsgs
        /\ proposalMsgs' = proposalMsgs \cup {[sender |-> Leader, value |-> v]}
        /\ UNCHANGED <<writeMsgs, acceptMsgs, decided>>

(*
    Correct replica WRITE behavior:

    A correct replica sends a WRITE for value v only if:
      1. the leader proposed v
      2. the replica has not already sent a WRITE for another value

    This "write only once" rule is important for safety.
*)
CorrectWrite ==
    \E r \in Correct:
    \E v \in Values:
        /\ HasProposal(v)
        /\ ~HasWriteFrom(r)
        /\ writeMsgs' = writeMsgs \cup {[sender |-> r, value |-> v]}
        /\ UNCHANGED <<proposalMsgs, acceptMsgs, decided>>

(*
    Byzantine replica WRITE behavior:

    A faulty replica may send a WRITE for any value.
    It may even write for multiple values over time.
*)
FaultyWrite ==
    \E r \in Faulty:
    \E v \in Values:
        /\ [sender |-> r, value |-> v] \notin writeMsgs
        /\ writeMsgs' = writeMsgs \cup {[sender |-> r, value |-> v]}
        /\ UNCHANGED <<proposalMsgs, acceptMsgs, decided>>

(*
    Correct replica ACCEPT behavior:

    A correct replica sends ACCEPT for value v only if:
      1. it has seen a quorum of WRITE messages for v
      2. it has not already sent ACCEPT for another value

    This corresponds to:
        after enough WRITE votes, broadcast ACCEPT.
*)
CorrectAccept ==
    \E r \in Correct:
    \E v \in Values:
        /\ WriteQuorum(v)
        /\ ~HasAcceptFrom(r)
        /\ acceptMsgs' = acceptMsgs \cup {[sender |-> r, value |-> v]}
        /\ UNCHANGED <<proposalMsgs, writeMsgs, decided>>

(*
    Byzantine replica ACCEPT behavior:

    A faulty replica may send ACCEPT for any value.
*)
FaultyAccept ==
    \E r \in Faulty:
    \E v \in Values:
        /\ [sender |-> r, value |-> v] \notin acceptMsgs
        /\ acceptMsgs' = acceptMsgs \cup {[sender |-> r, value |-> v]}
        /\ UNCHANGED <<proposalMsgs, writeMsgs, decided>>

(*
    Decide behavior:

    A correct replica decides value v if it has seen a quorum of ACCEPT
    messages for v.

    This means the value is now chosen for this consensus instance.
*)
Decide ==
    \E r \in Correct:
    \E v \in Values:
        /\ decided[r] = NoValue
        /\ AcceptQuorum(v)
        /\ decided' = [decided EXCEPT ![r] = v]
        /\ UNCHANGED <<proposalMsgs, writeMsgs, acceptMsgs>>

(*
    Stuttering allows the model to stop changing without TLC reporting
    deadlock. This is useful for a simple finite model.
*)
Stutter ==
    UNCHANGED vars

Next ==
    \/ CorrectLeaderPropose
    \/ FaultyLeaderPropose
    \/ CorrectWrite
    \/ FaultyWrite
    \/ CorrectAccept
    \/ FaultyAccept
    \/ Decide
    \/ Stutter

(***************************************************************************)
(* Correctness properties                                                   *)
(***************************************************************************)

(*
    Agreement:

    No two correct replicas decide different values.

    This is the most important safety property.
*)
Agreement ==
    \A r1, r2 \in Correct:
        /\ decided[r1] # NoValue
        /\ decided[r2] # NoValue
        => decided[r1] = decided[r2]

(*
    Validity:

    If a correct replica decides value v, then v must have been proposed
    by the leader.

    This prevents deciding completely invented values.
*)
Validity ==
    \A r \in Correct:
        decided[r] # NoValue => HasProposal(decided[r])

(*
    Integrity:

    A correct replica only decides a value if there is an ACCEPT quorum
    for that value.
*)
Integrity ==
    \A r \in Correct:
        decided[r] # NoValue => AcceptQuorum(decided[r])

(*
    AcceptImpliesWrite:

    If a correct replica sends ACCEPT for value v, then there must have
    been a WRITE quorum for v.
*)
AcceptImpliesWrite ==
    \A m \in acceptMsgs:
        m.sender \in Correct => WriteQuorum(m.value)

(*
    Optional full behavior specification.
    You can use this from the cfg with:

        SPECIFICATION Spec

    Or keep using:

        INIT Init
        NEXT Next
*)
Spec ==
    Init /\ [][Next]_vars

=============================================================================