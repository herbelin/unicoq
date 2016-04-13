(***********************************************************)
(* Unicoq plugin.                                          *)
(* Copyright (c) 2015 Beta Ziliani <beta@mpi-sws.org>      *)
(*                    Matthieu Sozeau <mattam@mattam.org>. *)
(***********************************************************)

(** Unicoq - An improved unification algorithm for Coq

    This defines a tactic [munify x y] that unifies two typable terms.
*)

(* These are necessary for grammar extensions like the one at the end 
   of the module *)

(*i camlp4deps: "parsing/grammar.cma" i*)
(*i camlp4use: "pa_extend.cmo" i*)

DECLARE PLUGIN "unicoq"

open Pp
open Proofview
open Notations
open Munify

module P = Pretyping

let understand env sigma {Glob_term.closure=closure;term=term} =
  let flags = P.all_no_fail_flags in
  let lvar = { P.empty_lvar with
               P.ltac_constrs = closure.Glob_term.typed;
               P.ltac_uconstrs = closure.Glob_term.untyped;
               P.ltac_idents = closure.Glob_term.idents;
             } in
  P.understand_ltac flags env sigma lvar P.WithoutTypeConstraint term

let munify_tac gl sigma ismatch x y =
  let env = Goal.env gl in
  let evars evm = V82.tactic (Refiner.tclEVARS evm) in
  let (sigma, x) = understand env sigma x in
  let (sigma, y) = understand env sigma y in
  let res = 
    let ts = Conv_oracle.get_transp_state (Environ.oracle env) in
    unify_evar_conv ~ismatch:ismatch ts env sigma Reduction.CUMUL x y in
    match res with
    | Evarsolve.Success evm -> evars evm
    | Evarsolve.UnifFailure _ -> Tacticals.New.tclFAIL 0 (str"Unification failed")

(* This adds an entry to the grammar of tactics, similar to what
   Tactic Notation does. *)

TACTIC EXTEND munify_tac
| ["munify" uconstr(c) uconstr(c') ] ->
  [ Proofview.Goal.enter begin fun gl ->
        let gl = Proofview.Goal.assume gl in
        let sigma = Goal.sigma gl in
        munify_tac gl sigma false c c'
      end
  ]
END


TACTIC EXTEND mmatch_tac
| ["mmatch" uconstr(c) uconstr(c') ] ->
  [ Proofview.Goal.enter begin fun gl ->
        let gl = Proofview.Goal.assume gl in
        let env = Proofview.Goal.env gl in
        let sigma = Proofview.Goal.sigma gl in
        munify_tac gl sigma true c c'
      end
  ]
END

VERNAC COMMAND EXTEND PrintMunifyStats CLASSIFIED AS SIDEFF
  | [ "Print" "Unicoq" "Stats" ] -> [
      let s = Munify.get_stats () in
      Printf.printf "STATS:\t%s\t\t%s\n" 
        (Big_int.string_of_big_int s.unif_problems) 
        (Big_int.string_of_big_int s.instantiations)
  ]
END