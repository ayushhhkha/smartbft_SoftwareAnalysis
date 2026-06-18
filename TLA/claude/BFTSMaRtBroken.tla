----------------------------- MODULE BFTSMaRtBroken -----------------------------
(***************************************************************************)
(* Mutation of the model used to show the correctness properties are NOT  *)
(* vacuous.  We override the BFT quorum threshold to f (so a certificate  *)
(* needs only f+1 votes instead of 2f+1) and let the LEADER be Byzantine  *)
(* so it can equivocate.  With the correct 2f+1 threshold the same        *)
(* scenario keeps Agreement (quorum intersection); with this f+1 mutation *)
(* TLC must find an Agreement / CertificateUniqueness violation.          *)
(***************************************************************************)
EXTENDS BFTSMaRt

WeakQuorum == F   \* certificate completes at count > F, i.e. only f+1 votes

=============================================================================
