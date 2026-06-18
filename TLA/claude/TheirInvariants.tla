---------------------------- MODULE TheirInvariants ----------------------------
(***************************************************************************)
(* The independently-defined invariants, encoded in the vocabulary of     *)
(* BFTSMaRt.tla so TLC can check whether they hold in the Byzantine-       *)
(* faithful model.  Used to compare the two invariant sets empirically.   *)
(***************************************************************************)
EXTENDS BFTSMaRt

\* "TypeOK" and "Agreement" and "Validity" are identical to ours (reuse them).

\* Their INTEGRITY: a correct replica decides only after an ACCEPT quorum is
\* observed for that value.
Their_Integrity ==
    \A r \in Correct : decided[r] # NoVal => AcceptCertified(decided[r])

\* Their ACCEPTIMPLIESWRITE, naive reading: EVERY ACCEPT message on the
\* network is backed by a WRITE quorum.  (Quantifies over all of `sent`.)
AcceptImpliesWrite_Naive ==
    \A m \in sent : m.type = "ACCEPT" => WriteCertified(m.val)

\* Their ACCEPTIMPLIESWRITE, restricted to CORRECT senders.
AcceptImpliesWrite_Correct ==
    \A m \in sent :
        (m.type = "ACCEPT" /\ m.sender \in Correct) => WriteCertified(m.val)

=============================================================================
