---------------------------- MODULE BFTSMaRtMerged ----------------------------
(***************************************************************************)
(* Canonical, MERGED invariant set for the BFT-SMaRt VP-Consensus model.  *)
(*                                                                         *)
(* Reuses the specification body of BFTSMaRt.tla unchanged (via EXTENDS)   *)
(* and gathers the complementary invariants from both the independent set  *)
(* and the original set, plus the Byzantine-soundness fix surfaced by      *)
(* model checking (see INVARIANT_COMPARISON.md).                           *)
(*                                                                         *)
(* The original BFTSMaRt.tla / .cfg are left intact; this module is the    *)
(* single place that lists every property we want checked together.        *)
(***************************************************************************)
EXTENDS BFTSMaRt

(*-------------------------------------------------------------------------*)
(* Inherited from BFTSMaRt.tla (in scope via EXTENDS, listed here for      *)
(* readability):                                                           *)
(*   TypeOK                  structural well-typedness                     *)
(*   Agreement               no two correct replicas decide differently    *)
(*   Validity                decide ==> leader proposed the value           *)
(*   Integrity               decide ==> value equals replica's own ACCEPT  *)
(*   CertificateUniqueness   at most one value gets a 2f+1 ACCEPT cert      *)
(*   Termination             (liveness) every correct replica decides       *)
(*-------------------------------------------------------------------------*)

(*-------------------------------------------------------------------------*)
(* Added from the independent invariant set.                               *)
(*-------------------------------------------------------------------------*)

\* INTEGRITY (certificate-backed facet): a correct replica decides only after
\* an ACCEPT quorum has been observed for that value.  Complements `Integrity`
\* (which ties the decision to the replica's own ACCEPT).
DecisionIsCertified ==
    \A r \in Correct : decided[r] # NoVal => AcceptCertified(decided[r])

\* PHASE ORDERING (AcceptImpliesWrite): a *correct* replica sends ACCEPT for a
\* value only after a WRITE quorum for that value exists.  The `sender \in
\* Correct` guard is REQUIRED: without it a Byzantine replica injecting a bare
\* ACCEPT falsifies the property (TLC counterexample in INVARIANT_COMPARISON).
AcceptImpliesWrite ==
    \A m \in sent :
        (m.type = "ACCEPT" /\ m.sender \in Correct) => WriteCertified(m.val)

\* WRITE provenance: a *correct* replica only WRITEs a value the leader actually
\* proposed (mirrors proposeReceived's leader/value check).  Extra conformance
\* check on the first protocol phase.
WriteImpliesPropose ==
    \A m \in sent :
        (m.type = "WRITE" /\ m.sender \in Correct) => LeaderProposed(m.val)

=============================================================================
