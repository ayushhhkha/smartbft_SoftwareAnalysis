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
CONSTANTS Replicas,    \* Set of all replicas, e.g. {1,2,3,4}
         Values,    \* Possible proposed batches/values, e.g. {v1, v2}
         F,    \* Maximum number of Byzantine faulty replicas
         Faulty,    \* Set of replicas that may behave Byzantine
         Leader,    \* The current leader for this consensus instance
         NoValue, \* Special value meaning "this replica has not decided yet"
         MaxConsensus

Consensus == 1..MaxConsensus
(*
    Basic BFT assumptions.

    For Byzantine fault tolerance, we need:

        n >= 3f + 1

    Written equivalently as:

        3f < n

    We also assume the configured Faulty set contains at most F replicas.
*)
ASSUME /\ 3 * F < Cardinality(Replicas) \* Ensures the BFT requirement n >= 3F + 1.
       /\ Faulty \subseteq Replicas \* Ensures every faulty replica is part of the replica set.
       /\ Cardinality(Faulty) <= F \* Ensures the number of faulty replicas does not exceed F.
       /\ Leader \in Replicas \* Ensures the leader is a valid replica.
       /\ NoValue \notin Values  \* Ensures NoValue is only used as the "not decided yet" marker.
       /\ Consensus # {}

Correct == Replicas \ Faulty  \* Get all correct replicas by taking the set difference between the set of all replicas and the set of faulty replicas.

(*
    In BFT protocols, the usual quorum size is:

        2f + 1

    For example, with f = 1 and n = 4, quorum = 3.
*)

Quorum == 2 * F + 1

VARIABLES
\*   proposalMsgs, \* PROPOSE messages sent by the leader
\*   writeMsgs, \* WRITE messages sent by replicas
\*   acceptMsgs, \* ACCEPT messages sent by replicas
\*   decided \* decided[r] = value decided by replica r, or NoValue
    instances, \* instances[c] = state of consensus instance c, including proposalMsgs, writeMsgs, acceptMsgs, and decided
    delivered, \* delivered[r] = set of consensus instances that replica r has delivered/decided
    currentConsensus \* currentConsensus = the consensus instance that is currently being processed by the protocol


vars == << instances, delivered, currentConsensus >>  \* Tuple of all model state variables, used for stuttering and the temporal spec.


(*
    Message representation:

    A proposal message is a record:
        [sender |-> Leader, value |-> v]

    A write/accept message is a record:
        [sender |-> r, value |-> v]

    We do not include message type in the record because messages are
    already separated into proposalMsgs, writeMsgs, and acceptMsgs.
*)

ProposalMsg ==
    [sender : {Leader},
     value : Values]

VoteMsg ==
    [sender : Replicas,
     value : Values]

InstanceState ==
[
    proposalMsgs : SUBSET ProposalMsg,
    writeMsgs :
        SUBSET
            VoteMsg,

    acceptMsgs :
        SUBSET
            VoteMsg,

    decided :
        [Replicas ->
            Values \cup {NoValue}]
]

\* TYPEOK is an invariant that checks whether the model state has the correct “shape/type.”

TypeOK ==
\*   /\ proposalMsgs \subseteq [sender:{ Leader }, value:Values ] \* Every proposal message must be a record where sender is the leader and value is one of the valid values.
\*   /\ writeMsgs \subseteq [sender:Replicas, value:Values ] \* Every write message must be a record where sender is a replica and value is one of the valid values.
\*   /\ acceptMsgs \subseteq [sender:Replicas, value:Values ] \* Every accept message must be a record where sender is a replica and value is one of the valid values.
\*   /\ decided \in [Replicas -> Values \cup { NoValue }] \* Every replica's decision must be either a valid value or the "not decided yet" marker.

    /\ instances
        \in
            [Consensus ->
                InstanceState]

    /\ delivered
        \in
            [Replicas -> SUBSET Consensus]
    /\ currentConsensus \in Consensus
(*
Example of decided:

decided = [
  1 |-> v1,
  2 |-> v1,
  3 |-> NoValue,
  4 |-> NoValue
]
*)

Init ==

    /\ instances =

        [c \in Consensus |->

            [

                proposalMsgs |-> {},

                writeMsgs |-> {},

                acceptMsgs |-> {},

                decided |->

                    [r \in Replicas |->
                        NoValue]

            ]
        ]

    /\ delivered =

        [r \in Replicas |-> {}]

    /\ currentConsensus = 1

(***************************************************************************)
(* Helper predicates                                                        *)
(***************************************************************************)
HasProposal(c,v) ==

    [sender |-> Leader,
     value |-> v]

        \in
        instances[c].proposalMsgs

HasWriteFrom(c,r) ==

    \E v \in Values :

        [sender |-> r,
         value |-> v]

        \in
        instances[c].writeMsgs
        
HasAcceptFrom(c,r) ==

    \E v \in Values :

        [sender |-> r,
         value |-> v]

        \in
        instances[c].acceptMsgs

WriteSenders(c,v) ==

{
    r \in Replicas :

        [sender |-> r,
         value |-> v]

            \in
            instances[c].writeMsgs
}

AcceptSenders(c,v) ==

{
    r \in Replicas :

        [sender |-> r,
         value |-> v]

            \in
            instances[c].acceptMsgs
}

WriteQuorum(c,v) ==

Cardinality(WriteSenders(c,v))
    >=
Quorum

AcceptQuorum(c,v) ==

Cardinality(AcceptSenders(c,v))
    >=
Quorum

PreviousDelivered(r,c) ==

    c = 1

    \/

    (c - 1) \in delivered[r]

(***************************************************************************)
(* Protocol actions                                                         *)
(***************************************************************************)
(*
    Correct leader behavior:

    If the leader is correct, it proposes exactly one value.
    This abstracts the leader collecting pending client requests into
    a batch and proposing that batch for this consensus instance.

    1. Only runs if the leader is correct.
    2. Only runs if no proposal has been sent yet.
    3. Chooses one value v from Values.
    4. Adds a PROPOSE message from the leader for v to proposalMsgs.
    5. Leaves writeMsgs, acceptMsgs, and decided unchanged.
*)
CorrectLeaderPropose ==
  /\ Leader \in Correct
  /\ LET c == currentConsensus IN
      /\ instances[c].proposalMsgs = {}
      /\ \E v \in Values:
          /\ instances' =
              [instances EXCEPT
                  ![c].proposalMsgs =
                      @ \cup {
                          [ sender |-> Leader,
                            value |-> v ]
                      }]
          /\ UNCHANGED << delivered, currentConsensus >>
(*
    Byzantine leader behavior:

    If the leader is faulty, it may propose any value.
    Since proposalMsgs is a set, it can eventually contain multiple
    different proposals from the faulty leader.

    This models the idea that a Byzantine leader may equivocate:
    it can send conflicting proposals to different replicas.

    1. Only runs if the leader is faulty.
    2. Chooses one value v from Values.
    3. Checks that this proposal has not already been sent.
    4. Adds a PROPOSE message for v to proposalMsgs.
    5. Leaves writeMsgs, acceptMsgs, and decided unchanged.
*)
FaultyLeaderPropose ==
  /\ Leader \in Faulty
  /\ LET c == currentConsensus IN
      /\ \E v \in Values:
          /\ [ sender |-> Leader,
               value |-> v ]
               \notin instances[c].proposalMsgs
          /\ instances' =
              [instances EXCEPT
                  ![c].proposalMsgs =
                      @ \cup {
                          [ sender |-> Leader,
                            value |-> v ]
                      }]
          /\ UNCHANGED << delivered, currentConsensus >>
(*
    Correct replica WRITE behavior:

    A correct replica sends a WRITE for value v only if:
      1. the leader proposed v
      2. the replica has not already sent a WRITE for another value

    This "write only once" rule is important for safety.

    1. Chooses one correct replica r.
    2. Chooses one value v from Values.
    3. Only continues if the leader already proposed v.
    4. Only continues if replica r has not already sent a WRITE.
    5. Adds a WRITE message from replica r for value v.
    6. Leaves proposalMsgs, acceptMsgs, and decided unchanged.

    A correct replica can send a WRITE vote for a value only if the leader 
    proposed that value and the replica has not already written/voted for something else.
*)

CorrectWrite ==
  LET c == currentConsensus IN
    \E r \in Correct:
      \E v \in Values:
        /\ HasProposal(c,v)
        /\ ~HasWriteFrom(c,r)
        /\ instances' =
            [instances EXCEPT
                ![c].writeMsgs =
                    @ \cup {
                        [ sender |-> r,
                          value |-> v ]
                    }]
          /\ UNCHANGED << delivered, currentConsensus >>
(*
    Byzantine replica WRITE behavior:

    A faulty replica may send a WRITE for any value even if it was not proposed by the leader.
    It may even write for multiple values over time.

    1. Chooses one faulty replica r.
    2. Chooses one value v from Values.
    3. Only continues if this exact WRITE message has not already been sent.
    4. Adds a WRITE message from faulty replica r for value v.
    5. Leaves proposalMsgs, acceptMsgs, and decided unchanged.
*)

FaultyWrite ==
  LET c == currentConsensus IN
    \E r \in Faulty:
      \E v \in Values:
        /\ [ sender |-> r,
             value |-> v ]
             \notin instances[c].writeMsgs
        /\ instances' =
            [instances EXCEPT
                ![c].writeMsgs =
                    @ \cup {
                        [ sender |-> r,
                          value |-> v ]
                    }]
        /\ UNCHANGED << delivered, currentConsensus >>
(*
    Correct replica ACCEPT behavior:

    A correct replica sends ACCEPT for value v only if:
      1. it has seen a quorum of WRITE messages for v
      2. it has not already sent ACCEPT for another value

    This corresponds to:
        after enough WRITE votes, broadcast ACCEPT.

    1. Chooses one correct replica r.
    2. Chooses one value v from Values.
    3. Only continues if there is a WRITE quorum for v. (Received enough writes for v)
    4. Only continues if replica r has not already sent an ACCEPT for this value.
    5. Adds an ACCEPT message from replica r for value v to acceptMsgs.
    6. Leaves proposalMsgs, acceptMsgs, and decided unchanged.
*)
CorrectAccept ==
  LET c == currentConsensus IN
    \E r \in Correct:
      \E v \in Values:
        /\ WriteQuorum(c,v)
        /\ ~HasAcceptFrom(c,r)
        /\ instances' =
            [instances EXCEPT
                ![c].acceptMsgs =
                    @ \cup {
                        [ sender |-> r,
                          value |-> v ]
                    }]
        /\ UNCHANGED << delivered, currentConsensus >>
(*
    Byzantine replica ACCEPT behavior:

    A faulty replica may send ACCEPT for any value.

    1. Chooses one faulty replica r.
    2. Chooses one value v from Values.
    3. Only continues if this exact ACCEPT message has not already been sent.
    4. Adds an ACCEPT message from faulty replica r for value v to acceptMsgs.
    5. Leaves proposalMsgs, acceptMsgs, and decided unchanged.
*)
FaultyAccept ==
  LET c == currentConsensus IN
    \E r \in Faulty:
      \E v \in Values:
        /\ [ sender |-> r,
             value |-> v ]
             \notin instances[c].acceptMsgs
        /\ instances' =
            [instances EXCEPT
                ![c].acceptMsgs =
                    @ \cup {
                        [ sender |-> r,
                          value |-> v ]
                    }]
        /\ UNCHANGED << delivered, currentConsensus >>

(*
    Decide behavior:

    A correct replica decides value v if it has seen a quorum of ACCEPT
    messages for v.

    This means the value is now chosen for this consensus instance.

    1. Chooses one correct replica r.
    2. Chooses one value v from Values.
    3. Only continues if replica r has not decided yet.
    4. Only continues if there is an ACCEPT quorum for v.
    5. Updates decided[r] so replica r decides v.
    6. Leaves proposalMsgs, writeMsgs, and acceptMsgs unchanged.
*)

Decide ==
  LET c == currentConsensus IN
    \E r \in Correct:
      \E v \in Values:
        /\ instances[c].decided[r] = NoValue
        /\ AcceptQuorum(c,v)
        /\ instances' =
            [instances EXCEPT
                ![c].decided[r] = v]
        /\ UNCHANGED << delivered, currentConsensus >>

Deliver ==

    LET c == currentConsensus IN
    \E r \in Correct:

        /\ instances[c].decided[r] # NoValue

        /\ c \notin delivered[r]

        /\ PreviousDelivered(r,c)

        /\ delivered' =

            [delivered EXCEPT
                ![r] =
                    @ \cup {c}]

        /\ UNCHANGED << instances, currentConsensus >>
        
AdvanceConsensus ==

    /\ currentConsensus < MaxConsensus

    /\ \A r \in Correct :
        currentConsensus \in delivered[r]

    /\ currentConsensus' = currentConsensus + 1

    /\ UNCHANGED << instances, delivered >>

(*
    Stuttering allows the model to stop changing without TLC reporting
    deadlock. This is useful for a simple finite model.
*)

Stutter == UNCHANGED vars

(*
  Lists every action that is allowed to happen in one model step.
  \/ means OR, so TLC may choose any enabled action from this list.
*)

Next ==
  \/ CorrectLeaderPropose
  \/ FaultyLeaderPropose
  \/ CorrectWrite 
  \/ FaultyWrite
  \/ CorrectAccept
  \/ FaultyAccept
  \/ Decide
  \/ Deliver
  \/ Stutter


(***************************************************************************)
(* Correctness properties                                                   *)
(***************************************************************************)
(*
    Agreement:

    No two correct replicas decide different values.

    This is the most important safety property.

    "#" means does not equal, so this says if r1 and r2 are correct 
    and both have decided something (not NoValue), then they must have decided the same value.
    
*)
Agreement ==
  \A c \in Consensus:
    \A r1,r2 \in Correct:
      /\ instances[c].decided[r1] # NoValue
      /\ instances[c].decided[r2] # NoValue
      => instances[c].decided[r1]
         =
         instances[c].decided[r2]
(*
    Validity:

    If a correct replica decides value v, then v must have been proposed
    by the leader.

    This prevents deciding completely invented values.
*)
Validity ==
  \A c \in Consensus:
    \A r \in Correct:
      instances[c].decided[r] # NoValue
        =>
      HasProposal(c,
                  instances[c].decided[r])
(*
    Integrity:

    A correct replica only decides a value if there is an ACCEPT quorum
    for that value.
*)
Integrity ==
  \A c \in Consensus:
    \A r \in Correct:
      instances[c].decided[r] # NoValue
        =>
      AcceptQuorum(c,
                   instances[c].decided[r])
(*
    AcceptImpliesWrite:

    If a correct replica sends ACCEPT for value v, then there must have
    been a WRITE quorum for v.
*)
AcceptImpliesWrite ==
  \A c \in Consensus:
    \A m \in instances[c].acceptMsgs:
      m.sender \in Correct
        =>
      WriteQuorum(c,m.value)
(*
    Optional full behavior specification.
    You can use this from the cfg with:

        SPECIFICATION Spec

    Or keep using:

        INIT Init
        NEXT Next
*)
\* Spec == Init /\ [][Next]_vars

OrderedDelivery ==

    \A r \in Correct:
        \A c \in delivered[r]:
            \A d \in Consensus:
                d < c => d \in delivered[r]
                
=============================================================================