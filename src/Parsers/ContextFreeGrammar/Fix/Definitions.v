Require Import Coq.PArith.BinPos Coq.PArith.Pnat.
Require Import Coq.Arith.Arith.
Require Import Coq.Classes.RelationClasses Coq.Classes.Morphisms.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Parsers.ContextFreeGrammar.Carriers.
Require Import Fiat.Common.Notations.

Set Implicit Arguments.

Local Coercion is_true : bool >-> Sortclass.
Delimit Scope grammar_fixedpoint_scope with fixedpoint.
Local Open Scope grammar_fixedpoint_scope.

Inductive lattice_for T := top | constant (_ : T) | bottom.
Bind Scope grammar_fixedpoint_scope with lattice_for.
Scheme Equality for lattice_for.

Definition collapse_lattice_for {T} (l : lattice_for T) : option T
  := match l with
       | constant n => Some n
       | _ => None
     end.

Arguments bottom {_}.
Arguments top {_}.
Notation "'⊥'" := bottom : grammar_fixedpoint_scope.
Notation "'⊤'" := top : grammar_fixedpoint_scope.

Definition lattice_for_lt {T} (lt : T -> T -> bool) (x y : lattice_for T)
  := match x, y with
     | ⊤, ⊤ => false
     | constant x', constant y' => lt x' y'
     | ⊥, ⊥ => false
     | _, ⊤ => true
     | ⊤, _ => false
     | _, constant _ => true
     | constant _, _ => false
     end.

Definition lattice_for_lub {T} (lub : T -> T -> lattice_for T) (x y : lattice_for T)
  := match x, y with
     | ⊤, ⊤ => ⊤
     | constant x', constant y' => lub x' y'
     | ⊥, ⊥ => ⊥
     | ⊤, _
     | _, ⊤
       => ⊤
     | ⊥, v
     | v, ⊥
       => v
     end.

Section lub_correct.
  Context {T} (beq : T -> T -> bool) (lt : T -> T -> bool) (lub : T -> T -> lattice_for T).

  Local Notation "x <= y" := (orb (lattice_for_beq beq x y) (lattice_for_lt lt x y)).

  Context (lub_correct_l : forall x y, constant x <= lub x y)
          (lub_correct_r : forall x y, constant y <= lub x y)
          (beq_refl : forall x y, x = y -> beq x y).

  Lemma lattice_for_lub_correct_l x y
    : x <= lattice_for_lub lub x y.
  Proof.
    clear lub_correct_r.
    destruct x as [|x|], y as [|y|]; try reflexivity.
    { exact (lub_correct_l x y). }
    { simpl.
      rewrite beq_refl by reflexivity; reflexivity. }
  Qed.

  Lemma lattice_for_lub_correct_r x y
    : y <= lattice_for_lub lub x y.
  Proof.
    clear lub_correct_l.
    destruct x as [|x|], y as [|y|]; try reflexivity.
    { exact (lub_correct_r x y). }
    { simpl.
      rewrite beq_refl by reflexivity; reflexivity. }
  Qed.
End lub_correct.

Definition lattice_for_gt_well_founded {T} {lt : T -> T -> bool}
           (gt_wf : well_founded (Basics.flip lt))
  : well_founded (Basics.flip (lattice_for_lt lt)).
Proof.
  do 3 (constructor;
        repeat match goal with
               | [ v : T, H : well_founded _ |- _ ] => specialize (H v); induction H
               | [ x : lattice_for _ |- _ ] => destruct x
               | _ => progress simpl in *
               | _ => progress unfold Basics.flip in *
               | [ H : is_true false |- _ ] => exfalso; clear -H; abstract congruence
               | _ => intro
               | _ => solve [ eauto with nocore ]
               end).
Defined.

Global Instance lattice_for_lt_Transitive {T} {lt : T -> T -> bool} {_ : Transitive lt}
  : Transitive (lattice_for_lt lt).
Proof.
  intros [|?|] [|?|] [|?|]; simpl; trivial; try congruence; [].
  intros.
  etransitivity; eassumption.
Qed.

Class grammar_fixedpoint_lattice_data prestate :=
  { state :> _ := lattice_for prestate;
    prestate_lt : prestate -> prestate -> bool;
    state_lt : state -> state -> bool
    := lattice_for_lt prestate_lt;
    prestate_beq : prestate -> prestate -> bool;
    state_beq : state -> state -> bool
    := lattice_for_beq prestate_beq;
    prestate_le s1 s2 := (prestate_beq s1 s2 || prestate_lt s1 s2)%bool;
    state_le s1 s2 := (state_beq s1 s2 || state_lt s1 s2)%bool;
    prestate_beq_lb : forall s1 s2, s1 = s2 -> prestate_beq s1 s2;
    prestate_beq_bl : forall s1 s2, prestate_beq s1 s2 -> s1 = s2;
    state_beq_lb : forall s1 s2, s1 = s2 -> state_beq s1 s2
    := internal_lattice_for_dec_lb _ prestate_beq_lb;
    state_beq_bl : forall s1 s2, state_beq s1 s2 -> s1 = s2
    := internal_lattice_for_dec_bl _ prestate_beq_bl;
    preleast_upper_bound : prestate -> prestate -> state;
    least_upper_bound : state -> state -> state
    := lattice_for_lub preleast_upper_bound;
    preleast_upper_bound_correct_l
    : forall a b, state_le (constant a) (preleast_upper_bound a b);
    preleast_upper_bound_correct_r
    : forall a b, state_le (constant b) (preleast_upper_bound a b);
    least_upper_bound_correct_l
    : forall a b, state_le a (least_upper_bound a b)
    := lattice_for_lub_correct_l prestate_beq prestate_lt preleast_upper_bound preleast_upper_bound_correct_l prestate_beq_lb;
    least_upper_bound_correct_r
    : forall a b, state_le b (least_upper_bound a b)
    := lattice_for_lub_correct_r prestate_beq prestate_lt preleast_upper_bound preleast_upper_bound_correct_r prestate_beq_lb;
    prestate_gt_wf : well_founded (Basics.flip prestate_lt);
    state_gt_wf : well_founded (Basics.flip state_lt)
    := lattice_for_gt_well_founded prestate_gt_wf;
    prestate_lt_Transitive : Transitive prestate_lt;
    state_lt_Transitive : Transitive state_lt
    := lattice_for_lt_Transitive }.

Record grammar_fixedpoint_data :=
  { prestate : Type;
    lattice_data :> grammar_fixedpoint_lattice_data prestate;
    step_constraints : (default_nonterminal_carrierT -> state) -> (default_nonterminal_carrierT -> state -> state);
    step_constraints_ext : Proper (pointwise_relation _ eq ==> eq ==> eq ==> eq) step_constraints }.

Global Existing Instance lattice_data.
Global Existing Instance step_constraints_ext.
Global Existing Instance state_lt_Transitive.

Global Arguments state_lt_Transitive {_ _} [_ _ _] _ _.
Global Arguments state_le _ _ !_ !_ / .
Global Arguments state {_ _}, {_} _.

Infix "<=" := (@state_le _ _) : grammar_fixedpoint_scope.
Infix "<" := (@state_lt _ _) : grammar_fixedpoint_scope.
Infix "⊔" := (@least_upper_bound _ _) : grammar_fixedpoint_scope.
Infix "=b" := (@state_beq _ _) : grammar_fixedpoint_scope.

Definition nonterminal_to_positive (nt : default_nonterminal_carrierT) : positive
  := Pos.of_nat (S nt).
Definition positive_to_nonterminal (nt : positive) : default_nonterminal_carrierT
  := pred (Pos.to_nat nt).
Lemma positive_to_nonterminal_to_positive nt : nonterminal_to_positive (positive_to_nonterminal nt) = nt.
Proof.
  unfold nonterminal_to_positive, positive_to_nonterminal.
  erewrite <- S_pred by apply Pos2Nat.is_pos.
  rewrite Pos2Nat.id.
  reflexivity.
Qed.
Lemma nonterminal_to_positive_to_nonterminal nt : positive_to_nonterminal (nonterminal_to_positive nt) = nt.
Proof.
  unfold nonterminal_to_positive, positive_to_nonterminal.
  rewrite Nat2Pos.id_max; simpl.
  reflexivity.
Qed.