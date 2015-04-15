(** First step of a splitter refinement; indexed representation, and handle all rules with at most one nonterminal *)
Require Import Coq.Strings.String Coq.Arith.Lt.
Require Import Coq.Numbers.Natural.Peano.NPeano.
Require Import Fiat.Parsers.StringLike.Core.
Require Import Fiat.Parsers.ParserInterface.
Require Import Fiat.Parsers.ParserADTSpecification.
Require Import Fiat.Parsers.StringLike.Properties.
Require Import Fiat.Parsers.StringLike.String.
Require Import ADTNotation.BuildADT ADTNotation.BuildADTSig.
Require Import ADT.ComputationalADT.
Require Import Fiat.Common Fiat.Common.Equality.
Require Import Fiat.ADTRefinement.
Require Import Fiat.Common.StringBound Fiat.Common.ilist.
Require Import ADTRefinement.BuildADTRefinements.HoneRepresentation.
Require Import Fiat.Common.IterateBoundedIndex.

Set Implicit Arguments.

Local Open Scope list_scope.
Local Open Scope ADTSig_scope.
Local Open Scope ADT_scope.
Local Open Scope string_scope.

Section helpers.
  Section generic.
    Context {Char : Type}.

    Fixpoint has_only_terminals (its : production Char)
    : bool
      := match its with
           | nil => true
           | (Terminal _)::xs => has_only_terminals xs
           | (NonTerminal _)::_ => false
         end.
  End generic.

  Section generic_string.
    Context {Char} {HSL : StringLike Char} {HLSP : StringLikeProperties Char} (G : grammar Char).

    Lemma has_only_terminals_length {its str}
          (H0 : @has_only_terminals _ its)
          (H1 : parse_of_production G str its)
    : length str = List.length its.
    Proof.
      induction H1 as [ | ? ? ? ? pit pits IH ]; simpl in *; trivial.
      rewrite drop_length in IH.
      dependent destruction pit.
      { match goal with
          | [ H : context[(_ ~= [ _ ])%string_like] |- _ ]
            => apply length_singleton in H
        end.
        rewrite <- IH by assumption; clear IH.
        repeat match goal with
                 | _ => intro
                 | [ H : context[length (take _ _)] |- _ ] => rewrite take_length in H
                 | [ H : context[length (drop _ _)] |- _ ] => rewrite drop_length in H
                 | [ H : min ?x ?y = 1 |- _ ] => is_var x; destruct x
                 | [ H : min (S ?x) ?y = 1 |- _ ] => is_var x; destruct x
                 | [ H : min (S (S ?x)) ?y = 1 |- _ ] => revert H; apply (Min.min_case_strong (S (S x)) y)
                 | [ H : context[min _ 0] |- _ ] => rewrite Min.min_0_r in H
                 | [ H : context[min 0 _] |- _ ] => rewrite Min.min_0_l in H
                 | [ H : 0 = 1 |- _ ] => exfalso; clear -H; discriminate
                 | [ H : S (S _) = 1 |- _ ] => exfalso; clear -H; discriminate
                 | [ H : ?x = 1, H' : context[?x] |- _ ] => rewrite H in H'
                 | [ H : ?x = 1 |- context[?x] ] => rewrite H
                 | [ H : min ?x ?y = 1 |- _ ] => revert H; apply (Min.min_case_strong x y)
                 | _ => omega
               end. }
      { exfalso.
        unfold is_true in *.
        discriminate. }
    Qed.
  End generic_string.
End helpers.

Section IndexedImpl.
  Context (G : grammar Ascii.ascii).

  Local Notation T := (String.string * (nat * nat))%type (only parsing).

  Local Notation string_of_indexed s :=
    (substring (fst (snd s)) (snd (snd s)) (fst s))
      (only parsing).
  Local Notation ilength s :=
    (min (String.length (fst s) - fst (snd s)) (snd (snd s)))
      (only parsing).

  (** Reference implementation of a [String] that can be split; has a [string], and a start index, and a length *)
  (** TODO: should we replace

       [string_dec (string_of_indexed s) (String.String ch "") : bool]

      with something fancier and maybe more efficient, like

        [((Nat.eq_dec (min (String.length base - fst s) (snd s)) 1) &&
  (option_dec Ascii.ascii_dec (String.get (fst s) base) (Some
  ch)))%bool] *)

  Definition indexed_spec : ADT (string_rep Ascii.ascii) := ADTRep T {
    Def Constructor "new"(s : String.string) : rep :=
      ret (s, (0, String.length s)),

    Def Method "to_string"(s : rep, x : unit) : String.string :=
      ret (s, string_of_indexed s),

    Def Method "is_char"(s : rep, ch : Ascii.ascii) : bool  :=
      ret (s, string_beq (string_of_indexed s) (String.String ch "")),

    Def Method "length"(s : rep, x : unit) : nat :=
      ret (s, ilength s),

    Def Method "take"(s : rep, n : nat) : unit :=
      ret ((fst s, (fst (snd s), min (snd (snd s)) n)), tt),

    Def Method "drop"(s : rep, n : nat) : unit :=
      ret ((fst s, (fst (snd s) + n, snd (snd s) - n)), tt),

    Def Method "splits"(s : rep, p : item Ascii.ascii * production Ascii.ascii) : list nat :=
      fallback_ls <- { ls : list nat
                     | match fst p with
                         | Terminal _
                           => True
                         | NonTerminal _
                           => if has_only_terminals (snd p)
                              then True
                              else split_list_is_complete G (string_of_indexed s) (fst p) (snd p) ls
                       end };
      let ls := (match snd p, fst p with
                   | nil, _
                     => [ilength s]
                   | _::_, Terminal _
                     => [1]
                   | _::_, NonTerminal _
                     => if has_only_terminals (snd p)
                        then [ilength s - List.length (snd p)]
                        else fallback_ls
                 end) in
      ret (s, ls)
  }.

  Lemma FirstStep
  : refineADT (string_spec G) indexed_spec.
  Proof.
    econstructor 1 with (AbsR := (fun r_o r_n =>
                                    substring (fst (snd r_n)) (snd (snd r_n)) (fst r_n) = r_o));
    abstract (
        eapply Iterate_Ensemble_BoundedIndex_equiv;
        simpl; intuition; intros; try simplify with monad laws;
        repeat intro; computes_to_inv; subst; simpl;
        repeat match goal with
                 | _ => progress simpl in *
                 | _ => progress computes_to_inv
                 | _ => progress subst
                 | [ H : context[match ?x with _ => _ end] |- _ ] => (is_var x; destruct x)
                 | [ |- context[match ?x with _ => _ end] ] => (is_var x; destruct x)
                 | [ H : context[match ?x with _ => _ end] |- _ ] => destruct x eqn:?
                 | [ |- computes_to (Bind _ _) _ ]
                   => refine ((fun H0 H1 => BindComputes _ _ _ _ H1 H0) _ _)
                 | [ |- computes_to (Return ?x) ?y ]
                   => cut (x = y);
                 [ let H := fresh in intro H; try rewrite H; eapply ReturnComputes | ]
                 | [ |- computes_to (Pick _) _ ]
                   => eapply PickComputes
                 | _ => reflexivity
                 | _ => assumption
               end;
        try solve [ rewrite substring_correct3'; reflexivity
                  | repeat match goal with
                             | _ => intro
                             | _ => reflexivity
                             | _ => rewrite substring_substring
                             | _ => rewrite Nat.sub_0_r
                             | _ => rewrite substring_length
                             | _ => rewrite Nat.add_sub
                             | _ => rewrite <- Nat.sub_min_distr_r
                             | _ => progress simpl
                             | [ |- context[min ?x ?y] ]
                               => match goal with
                                    | [ |- context[min y x] ]
                                      => rewrite (Min.min_comm x y)
                                  end
                             | [ |- context[min (min _ ?x) (?x - ?y)] ]
                               => rewrite <- (Min.min_assoc _ x (x - y)), (Min.min_r x (x - y)) by omega
                             | [ |- substring (?x + ?y) _ _ = substring (?y + ?x) _ _ ]
                               => rewrite (Plus.plus_comm x y)
                             | [ |- substring ?x ?y ?z = substring ?x (min ?w ?y) ?z ]
                               => apply (@Min.min_case_strong w y)
                             | [ H : _ |- _ ] => rewrite Min.min_assoc in H
                             | _ => apply substring_correct4; omega
                           end
                  | repeat match goal with
                             | _ => intro
                             | _ => progress subst
                             | [ |- List.In ?x [?y] ] => left
                             | _ => reflexivity
                             | [ H : parse_of_production _ _ nil |- _ ] => let H' := fresh in rename H into H'; dependent destruction H'
                             | [ H : parse_of_production _ _ (_::_) |- _ ] => let H' := fresh in rename H into H'; dependent destruction H'
                             | [ H : parse_of_item _ _ (Terminal _) |- _ ] => let H' := fresh in rename H into H'; dependent destruction H'
                             | [ H : parse_of_item _ _ (NonTerminal _ _) |- _ ] => let H' := fresh in rename H into H'; dependent destruction H'
                             | _ => erewrite <- has_only_terminals_length by eassumption
                             | [ H : _ |- _ ] => progress rewrite ?(@drop_length _ string_stringlike string_stringlike_properties), ?(@take_length _ string_stringlike string_stringlike_properties), ?substring_length, ?Nat.add_sub, ?Minus.minus_diag, ?Nat.sub_0_r, ?sub_plus in H by omega
                             | _ => progress rewrite ?drop_length, ?take_length, ?substring_length, ?Nat.add_sub, ?Minus.minus_diag, ?Nat.sub_0_r, ?sub_plus by omega
                             | [ H : context[(_ ~= [ _ ])%string_like] |- _ ]
                               => apply length_singleton in H
                             | [ |- context[min ?x (?y + ?z) - ?z] ]
                               => rewrite <- (Nat.sub_min_distr_r x (y + z) z)
                             | [ H : context[min ?x (?y + ?z) - ?z] |- _ ]
                               => rewrite <- (Nat.sub_min_distr_r x (y + z) z) in H
                             | [ H : min ?x ?y = 1 |- _ ] => is_var x; revert H; apply (Min.min_case_strong x y)
                             | [ |- context[0 + ?x] ] => change (0 + x) with x
                             | [ |- context[?x - S ?y] ]
                               => not constr_eq y 0; rewrite !(Nat.sub_succ_r x y), !Minus.pred_of_minus
                             | [ H : ?x = 1 |- context[?x] ] => rewrite H
                             | [ H : ?x = 1, H' : context[?x] |- _ ] => rewrite H in H'
                             | [ H : ?x <= ?y |- context[?x - ?y] ] => replace (x - y) with 0 by (clear -H; omega)
                             | _ => omega
                             | [ H : appcontext[ContextFreeGrammarProperties.Forall_parse_of_production] |- _ ] => clear H
                             | [ H : appcontext[ContextFreeGrammarProperties.Forall_parse_of_item] |- _ ] => clear H
                           end ]
      ).
  Defined.

  (*Lemma AllTheSteps
  : Sharpened (string_spec G).
    eapply SharpenStep.
    apply FirstStep.

    (*hone representation using
         (fun r_o r_n =>
                    substring (fst (snd r_n)) (snd (snd r_n)) (fst r_n) = r_o).
    hone constructor "new".
    {
      simplify with monad laws.
      refine pick val (d, (0, String.length d)).
      subst H; higher_order_reflexivity.
      simpl.
      finish honing. *)

  Admitted.
*)
End IndexedImpl.
