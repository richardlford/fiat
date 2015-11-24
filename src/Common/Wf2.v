(** * Miscellaneous Well-Foundedness Facts *)
Require Export Fiat.Common.Coq__8_4__8_5__Compat.
Require Import Coq.Setoids.Setoid Coq.Program.Program Coq.Program.Wf Coq.Arith.Wf_nat Coq.Classes.Morphisms Coq.Init.Wf.
Require Import Fiat.Common.Telescope.Core.
Require Import Fiat.Common.
Require Import Fiat.Common.Equality.
Require Import Fiat.Common.Wf.

Set Implicit Arguments.

Local Ltac tuplify a b :=
  change a with (fst (a, b)) in *;
  change (fst (a, b), b) with (a, b) in *;
  change b with (snd (a, b)) in *;
  change (a, snd (a, b)) with (a, b) in *.

Local Ltac tuplify' a b :=
  tuplify a b;
  let tac := (fun T => match T with
                         | appcontext[?P (a, b)]
                           => change (P (a, b)) with (P (fst (a, b), snd (a, b)))
                       end) in
  match goal with
    | [ |- appcontext[@eq ?T] ] => tac T
    | [ |- appcontext[@flatten_forall_eq ?B ?T] ] => tac B; tac T
    | [ |- appcontext[@flatten_append_forall ?B ?T] ] => tac B; tac T
  end.

Local Ltac tuple_generalize a b :=
  first [ tuplify a b;
          generalize dependent (a, b)
        | tuplify' a b;
          generalize dependent (a, b) ];
  clear a b.

Local Ltac destruct_prods :=
  repeat match goal with
           | [ H : forall x : _ * _, _ |- _ ] => specialize (fun a' b' => H (a', b')); simpl in H
           | [ H : (_ * _)%type |- _ ] => destruct H
         end.

Section wf.
  Context A B (R : A * B -> A * B -> Prop)
          (Rwf : well_founded R)
          (P : A * B -> Type)
          (F : forall x x', (forall y y', R (y, y') (x, x') -> P (y, y')) -> P (x, x')).

  Fixpoint Fix2_F x x' (a : Acc R (x, x')) : P (x, x')
    := F (fun y y' (h : R (y, y') (x, x')) => Fix2_F (Acc_inv a h)).

  Lemma Fix2_F_eq'
  : forall xx' (r : Acc R xx'),
      F (fun y y' (p : R (y, y') (fst xx', snd xx')) => Fix2_F (x:=y) (x':=y') (Acc_inv r (match xx' return R _ (fst xx', snd xx') -> R _ xx' with
                                                                                             | (x, x') => fun p => p
                                                                                           end p)))
      = Fix2_F (x:=fst xx') (x':=snd xx') (match xx' return Acc R xx' -> Acc R (fst xx', snd xx') with
                                             | (x, x') => fun p => p
                                           end r).
  Proof.
    destruct r using Acc_inv_dep.
    match goal with
      | [ x : (A * B)%type |- _ ] => destruct x; auto
    end.
  Defined.

  Lemma Fix2_F_eq
  : forall x x' (r : Acc R (x, x')),
      F (fun y y' (p : R (y, y') (x, x')) => Fix2_F (x:=y) (x':=y') (Acc_inv r p))
      = Fix2_F (x:=x) (x':=x') r.
  Proof.
    intros x x'.
    exact (@Fix2_F_eq' (x, x')).
  Defined.

  Definition Fix2 (x:A) (x':B) := Fix2_F (Rwf (x, x')).

  Section eq.
    Context (F_ext
             : forall x x'
                      (f g:forall (y:A) (y':B), R (y, y') (x, x') -> P (y, y')),
                 (forall y y' (p:R (y, y') (x, x')), f y y' p = g y y' p)
                 -> F f = F g).

    Lemma Fix2_F_inv' : forall xx' (r s:Acc R xx'),
                          Fix2_F (match xx' return Acc R xx' -> Acc R (fst xx', snd xx') with
                                    | (x, x') => fun p => p
                                  end r)
                          = Fix2_F (match xx' return Acc R xx' -> Acc R (fst xx', snd xx') with
                                      | (x, x') => fun p => p
                                    end s).
    Proof.
      intro xx'; induction (Rwf xx'); intros.
      rewrite <- (Fix2_F_eq' r); rewrite <- (Fix2_F_eq' s); intros.
      destruct_prods.
      apply F_ext; auto.
    Qed.

    Lemma Fix2_F_inv : forall (x:A) (x':B) (r s:Acc R (x, x')), Fix2_F r = Fix2_F s.
    Proof.
      intros x x'.
      exact (@Fix2_F_inv' (x, x')).
    Qed.

    Lemma Fix2_0_eq : forall (x:A) (x':B), Fix2 x x' = F (fun (y:A) (y':B) (p:R (y, y') (x, x')) => Fix2 y y').
    Proof.
      intros x x'; unfold Fix2.
      rewrite <- Fix2_F_eq.
      apply F_ext; intros.
      apply Fix2_F_inv.
    Qed.
  End eq.

  Section rect.
    Context (Q : forall x x', P (x, x') -> Type)
            (H : forall x x', (forall y y', R (y, y') (x, x') -> Q y y' (@Fix2 y y')) -> Q x x' (@F x x' (fun (y : A) (y' : B) (_ : R (y, y') (x, x')) => @Fix2 y y')))
            (F_ext : forall (x : A) (x' : B) (f g : forall (y : A) (y' : B), R (y, y') (x, x') -> P (y, y')),
                       (forall (y : A) (y' : B) (p : R (y, y') (x, x')), f y y' p = g y y' p) -> @F _ _ f = @F _ _ g).

  Definition Fix2_0_rect' xx'
  : @Q (fst xx') (snd xx') (@Fix2 (fst xx') (snd xx')).
  Proof.
    induction (Rwf xx').
    destruct_prods.
    rewrite Fix2_0_eq; auto.
  Defined.

  Definition Fix2_0_rect x x'
  : @Q x x' (@Fix2 x x')
    := @Fix2_0_rect' (x, x').
  End rect.
End wf.

Local Ltac Fix2_Proper_t Fix2_eq wf :=
  change (@flatten_forall_eq_relation) with (@flatten_forall_eq);
  let H := fresh "H" in
  let a := fresh "a" in
  let b := fresh "b" in
  let ab := fresh "ab" in
  unfold forall_relation, pointwise_relation, respectful;
  intros ?? H a b; repeat intro;
  tuple_generalize a b;
  intros ab; intros;
  induction (wf ab);
  rewrite !Fix2_eq;
  destruct_prods;
  [ erewrite H; [ reflexivity | .. ] | .. ]; eauto; intros;
  [ etransitivity; [ symmetry; apply H; reflexivity | apply H; eassumption ]; reflexivity
  | etransitivity; [ apply H; eassumption | symmetry; apply H; reflexivity ]; reflexivity ].

Global Instance Fix2_0_Proper_eq {A B R wf P}
: Proper
    ((forall_relation
        (fun a =>
           forall_relation
             (fun b =>
                forall_relation
                  (fun a' =>
                     forall_relation
                       (fun b' =>
                          pointwise_relation _ eq))
                  ==> eq)))
       ==> (forall_relation (fun a => forall_relation (fun b => eq))))
    (@Fix2 A B R wf P).
Proof. Fix2_Proper_t @Fix2_0_eq wf. Qed.

Local Ltac Fix2_eq_t F_ext Rwf :=
  intros;
  unfold Fix2;
  rewrite <- Fix2_F_eq;
  apply F_ext; intros;
  repeat match goal with
           | [ |- appcontext[Fix2_F _ _ (?f ?x)] ] => generalize (f x)
         end;
  clear -F_ext Rwf;
  let y := match goal with |- forall x : Acc _ (?y, ?y'), _ => constr:y end in
  let y' := match goal with |- forall x : Acc _ (?y, ?y'), _ => constr:y' end in
  tuplify' y y';
    let r := fresh "r" in
    let s := fresh "s" in
    intros r s;
      change r with (match (y, y') as yy' return Acc _ yy' -> Acc _ (fst yy', snd yy') with
                       | (_, _) => fun p => p
                     end r);
      change s with (match (y, y') as yy' return Acc _ yy' -> Acc _ (fst yy', snd yy') with
                       | (_, _) => fun p => p
                     end s);
      generalize dependent (y, y'); clear y y';
      let yy' := fresh "yy'" in
      intro yy'; induction (Rwf yy');
      intros; rewrite <- !Fix2_F_eq;
      apply F_ext;
      destruct_prods;
      eauto.

Section Fix2V.
  Context A A' (B : A * A' -> Telescope)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall aa', flattenT (B aa') Type).

  Local Notation Fix2V := (@Fix2 A A' R Rwf (fun aa' => flatten_forall (P aa'))).

  Section F.
    Context (F : forall x x', (forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y'))) -> flatten_forall (P (x, x'))).

    Definition Fix2V_eq
               (F_ext : forall x x' (f g : forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y'))),
                          (forall y y' (p : R (y, y') (x, x')), flatten_forall_eq (f y y' p) (g y y' p))
                          -> flatten_forall_eq (@F x x' f) (@F x x' g))
    : forall a a', flatten_forall_eq (@Fix2V F a a') (@F a a' (fun y y' (_ : R (y, y') (a, a')) => @Fix2V F y y')).
    Proof. Fix2_eq_t F_ext Rwf. Defined.

    Definition Fix2V_rect
               (Q : forall a a', flattenT (Telescope_append (B (a, a')) (P (a, a'))) Type)
               (H0 : forall x x', (forall y y', R (y, y') (x, x') -> flatten_append_forall (@Q y y') (@Fix2V F y y'))
                                  -> flatten_append_forall (@Q x x') (@F x x' (fun y y' (_ : R (y, y') (x, x')) => @Fix2V F y y')))
               (F_ext : forall x x' (f g : forall y y', R (y, y') (x, x') -> flatten_forall (@P (y, y'))),
                          (forall y y' (p : R (y, y') (x, x')), flatten_forall_eq (f y y' p) (g y y' p))
                          -> flatten_forall_eq (@F x x' f) (@F x x' g))
               a a'
    : flatten_append_forall (@Q a a') (@Fix2V F a a').
    Proof.
      tuple_generalize a a'.
      intro aa'; induction (Rwf aa').
      destruct_prods.
      eapply flatten_append_forall_Proper; auto with nocore.
      symmetry; eapply Fix2V_eq; auto with nocore.
    Defined.
  End F.

  Global Instance Fix2V_Proper_eq
  : Proper
      ((forall_relation
          (fun a =>
             forall_relation
               (fun a' =>
                  (forall_relation
                     (fun b =>
                        forall_relation
                          (fun b' =>
                             pointwise_relation
                               _
                               (flatten_forall_eq_relation))))
                    ==> flatten_forall_eq_relation)))
         ==> (forall_relation (fun a => forall_relation (fun a' => flatten_forall_eq_relation))))
      Fix2V.
  Proof. Fix2_Proper_t @Fix2V_eq Rwf. Qed.
End Fix2V.

Arguments Fix2V_Proper_eq {A A' B R Rwf P} _ _ _ _ _.

Lemma FixV_2V_eq
      A A'
      (B : A * A' -> Telescope)
      (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
      (P : forall aa', flattenT (B aa') Type)
      (F : forall xx', (forall yy', R yy' xx' -> flatten_forall (P yy')) -> flatten_forall (P xx'))
      (F' : forall x x', (forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y'))) -> flatten_forall (P (x, x'))
       := fun x x' (f : forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y')))
          => F (x, x') (fun yy' => match yy' return R yy' _ -> flatten_forall (P yy') with
                                     | (y, y') => f y y'
                                   end))
      (F_ext : forall xx' (f g : forall yy', R yy' xx' -> flatten_forall (P yy')),
                 (forall yy' (p : R yy' xx'), flatten_forall_eq (f yy' p) (g yy' p))
                 -> flatten_forall_eq (@F xx' f) (@F xx' g))
: forall aa', flatten_forall_eq (@Fix (A * A') R Rwf (fun aa' => flatten_forall (P aa')) F aa')
                                (match aa' with
                                   | (a, a') => @Fix2 A A' R Rwf (fun aa' => flatten_forall (P aa')) F' a a'
                                 end).
Proof.
  intro aa'; induction (Rwf aa').
  destruct_prods.
  etransitivity;
    [ solve [ apply FixV_eq; intros; destruct_prods;
              apply F_ext; intros; destruct_prods; auto ]
    | ].
  etransitivity;
    [
    | solve [ symmetry;
              apply (@Fix2V_eq A A' B R Rwf P F'); intros; destruct_prods;
              apply F_ext; intros; destruct_prods; eauto ] ].
  apply F_ext; intros; destruct_prods; eauto.
Qed.

Local Arguments flatten_forall / .
Local Arguments flattenT / .
Local Arguments flatten_forall_eq / .
Local Arguments flatten_forall_eq_relation / .
Local Arguments flatten_append_forall / .

Local Notation type_of x := ((fun T (y : T) => T) _ x).

Section Fix2VTransfer.
  Context A A' (B B' : A * A' -> Telescope)
          (f0 : forall a, flattenT_sig (B a) -> flattenT_sig (B' a))
          (g0 : forall a, flattenT_sig (B' a) -> flattenT_sig (B a))
          (sect : forall a x, g0 a (f0 a x) = x)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall a, flattenT (B a) Type).

  Let P' : forall a, flattenT (B' a) Type
    := fun a => flattenT_unapply (fun x => flattenT_apply (P a) (g0 _ x)).

  Local Notation Fix2V := (@Fix2 A A' R Rwf (fun a => flatten_forall (P a))).
  Local Notation Fix2V' := (@Fix2 A A' R Rwf (fun a => flatten_forall (P' a))).

  Section F.
    Context (F : forall x x', (forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y'))) -> flatten_forall (P (x, x'))).

    Let transfer
    : forall y y',
        flatten_forall
          (flattenT_unapply
             (fun x : flattenT_sig (B (y, y')) => flattenT_apply (P' (y, y')) (f0 (y, y') x)))
        -> flatten_forall (P (y, y')).
    Proof.
      intros y y'.
      refine (flatten_forall_eq_rect
                (transitivity
                   ((_ : Proper (pointwise_relation _ _ ==> _) flattenT_unapply)
                      _ _
                      (fun x' => transitivity
                                   (symmetry (flattenT_apply_unapply _ _))
                                   (f_equal (flattenT_apply _) (sect _ _))))
                   (symmetry (flattenT_unapply_apply _)))).
    Defined.

    Let transfer'
    : forall a a',
        flatten_forall (P (a, a'))
        -> flatten_forall (P' (a, a')).
    Proof.
      intros a a'.
      refine (fun f' => flatten_forall_unapply (fun x' => flatten_forall_apply f' (g0 _ x'))).
    Defined.

    Let untransfer'
    : forall a a',
        flatten_forall (P' (a, a'))
        -> flatten_forall (P (a, a')).
    Proof.
      intros a a'.
      refine (fun f' => _).
      refine (transfer
                _ _
                (flatten_forall_unapply (fun x => flatten_forall_apply f' (f0 _ x)))).
    Defined.

    Let F' : forall x x', (forall y y', R (y, y') (x, x') -> flatten_forall (P' (y, y'))) -> flatten_forall (P' (x, x'))
      := fun a a' F' => transfer' _ _ (@F a a' (fun y y' pf => transfer _ _ (flatten_forall_unapply (fun x => flatten_forall_apply (F' y y' pf) (f0 _ x))))).


    Context (F_ext : forall x x' (f g : forall y y', R (y, y') (x, x') -> flatten_forall (P (y, y'))),
                       (forall y y' (p : R (y, y') (x, x')), flatten_forall_eq (f y y' p) (g y y' p))
                       -> flatten_forall_eq (@F x x' f) (@F x x' g)).

    Lemma F'_ext
    : forall x x' (f g : forall y y', R (y, y') (x, x') -> flatten_forall (P' (y, y'))),
        (forall y y' (p : R (y, y') (x, x')), flatten_forall_eq (f y y' p) (g y y' p))
        -> flatten_forall_eq (@F' x x' f) (@F' x x' g).
    Proof.
      intros x x' f' g' IH.
      subst F' transfer transfer'; cbv beta.
      apply (_ : Proper (forall_relation _ ==> _) flatten_forall_unapply); intro.
      refine ((_ : Proper (_ ==> forall_relation _) flatten_forall_apply) _ _ _ _).
      apply F_ext; intros.
      refine ((_ : Proper (flatten_forall_eq ==> _) (@flatten_forall_eq_rect _ _ _ _)) _ _ _).
      apply (_ : Proper (forall_relation _ ==> _) flatten_forall_unapply); intro.
      refine ((_ : Proper (_ ==> forall_relation _) flatten_forall_apply) _ _ _ _).
      apply IH.
    Qed.

    Definition FixV_transfer_eq
               a a'
    : flatten_forall_eq (@Fix2V F a a') (untransfer' _ _ (@Fix2V' F' a a')).
    Proof.
      tuple_generalize a a'.
      intro a; induction (Rwf a).
      rewrite Fix2V_eq by eauto with nocore.
      etransitivity_rev _.
      { subst transfer untransfer'; cbv beta.
        apply flatten_forall_eq_rect_Proper, flatten_forall_unapply_Proper; intro.
        apply flatten_forall_apply_Proper.
        rewrite Fix2V_eq by auto using F'_ext with nocore.
        reflexivity. }
      etransitivity.
      { apply F_ext; intros.
        lazymatch goal with
          | [ H : forall y r, flatten_forall_eq _ _ |- _ ]
            => specialize (fun y0 y1 => H (y0, y1));
              simpl @fst in H; simpl @snd in H;
              rewrite H by (destruct_head prod; assumption)
        end.
        match goal with
          | [ |- ?R ?a (?e ?x ?y) ]
            => revert x y
        end.
        match goal with
          | [ |- forall x y, ?R (@?LHS x y) (?RHS x y) ]
            => unify LHS RHS; cbv beta
        end.
        reflexivity. }
      lazymatch goal with
        | [ |- appcontext[Fix2V' ?F] ]
          => generalize (Fix2V' F)
      end.
      subst F'; cbv beta.
      subst untransfer' transfer transfer'; cbv beta.
      intro.
      rewrite flatten_forall_eq_rect_trans.
      match goal with
        | [ |- appcontext[flatten_forall_eq_rect
                            (flattenT_unapply_Proper ?P ?Q ?H)
                            (flatten_forall_unapply ?f)] ]
          => rewrite (@flatten_forall_eq_rect_flattenT_unapply_Proper _ P Q H f)
      end.
      etransitivity_rev _.
      { apply flatten_forall_eq_rect_Proper.
        apply flatten_forall_unapply_Proper; intro.
        change (@transitivity _ (@eq ?A) _) with (@eq_trans A).
        change (@symmetry _ (@eq ?A) _) with (@eq_sym A).
        set_evars.
        rewrite @transport_pp.
        match goal with
          | [ |- appcontext G[eq_rect _ (fun T => T) (flatten_forall_apply (flatten_forall_unapply ?k) ?x0) _ (eq_sym (flattenT_apply_unapply ?f1 ?x0))] ]
            => let H := fresh in
               pose proof (@eq_rect_symmetry_flattenT_apply_unapply _ f1 x0 k) as H;
                 cbv beta in H |- *;
                 let RHS := match type of H with _ = ?RHS => constr:RHS end in
                 let LHS := match type of H with ?LHS = _ => constr:LHS end in
                 let G' := context G[LHS] in
                 change G';
                   rewrite H;
                   clear H
        end.
        match goal with
          | [ |- context[f_equal _ ?p] ]
            => destruct p; unfold f_equal; simpl @eq_rect
        end.
        subst_body.
        reflexivity. }
      rewrite flatten_forall_eq_rect_symmetry_flattenT_unapply_apply.
      apply F_ext; intros.
      reflexivity.
    Qed.
  End F.
End Fix2VTransfer.

Section Fix2_0.
  Context A A'
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : A * A' -> Type).

  Local Notation T := (fun _ => bottom).

  Let Fix0_2_0_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix0_2_0_eq'T := Eval simpl in type_of Fix0_2_0_eq'.

  Definition Fix0_2_0_eq : Fix0_2_0_eq'T := Fix0_2_0_eq'.
End Fix2_0.

(** A variant of [Fix] that has a nice [Fix_eq] for functions which
    doesn't require [functional_extensionality]. *)
Section Fix2_1.
  Context A A' (B : A * A' -> Type)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall aa', B aa' -> Type).

  Local Notation T := (fun aa' => tele (B aa') (fun _ => bottom)).

  Let Fix2_1_eq' := @Fix2V_eq A A' T R Rwf P.
  Let Fix2_1_eq'T := Eval simpl in type_of Fix2_1_eq'.

  Let Fix2_1_rect' := @Fix2V_rect A A' T R Rwf P.
  Let Fix2_1_rect'T := Eval simpl in type_of Fix2_1_rect'.

  Let Fix2_1_Proper_eq' := @Fix2V_Proper_eq A A' T R Rwf P.
  Let Fix2_1_Proper_eq'T := Eval simpl in type_of Fix2_1_Proper_eq'.

  Let Fix1_2_1_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix1_2_1_eq'T := Eval simpl in type_of Fix1_2_1_eq'.

  Definition Fix2_1_eq : Fix2_1_eq'T := Fix2_1_eq'.
  Definition Fix2_1_rect : Fix2_1_rect'T := Fix2_1_rect'.
  Definition Fix2_1_Proper_eq : Fix2_1_Proper_eq'T := Fix2_1_Proper_eq'.
  Definition Fix1_2_1_eq : Fix1_2_1_eq'T := Fix1_2_1_eq'.
End Fix2_1.

Arguments Fix2_1_Proper_eq {A A' B R Rwf P} _ _ _ _ _ _.
Global Existing Instance Fix2_1_Proper_eq.

(** A variant of [Fix] that has a nice [Fix_eq] for functions which
    doesn't require [functional_extensionality]. *)
Section Fix2_2.
  Context A A' (B : A * A' -> Type) (C : forall a, B a -> Type)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall a b, C a b -> Type).

  Local Notation T := (fun a => tele (B a) (fun b => tele (@C a b) (fun _ => bottom))).

  Let Fix2_2_eq' := @Fix2V_eq A A' T R Rwf P.
  Let Fix2_2_eq'T := Eval simpl in type_of Fix2_2_eq'.

  Let Fix2_2_rect' := @Fix2V_rect A A' T R Rwf P.
  Let Fix2_2_rect'T := Eval simpl in type_of Fix2_2_rect'.

  Let Fix2_2_Proper_eq' := @Fix2V_Proper_eq A A' T R Rwf P.
  Let Fix2_2_Proper_eq'T := Eval simpl in type_of Fix2_2_Proper_eq'.

  Let Fix2_2_2_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix2_2_2_eq'T := Eval simpl in type_of Fix2_2_2_eq'.

  Definition Fix2_2_eq : Fix2_2_eq'T := Fix2_2_eq'.
  Definition Fix2_2_rect : Fix2_2_rect'T := Fix2_2_rect'.
  Definition Fix2_2_Proper_eq : Fix2_2_Proper_eq'T := Fix2_2_Proper_eq'.
  Definition Fix2_2_2_eq : Fix2_2_2_eq'T := Fix2_2_2_eq'.
End Fix2_2.

Arguments Fix2_2_Proper_eq {A A' B C R Rwf P} _ _ _ _ _ _ _.
Global Existing Instance Fix2_2_Proper_eq.

(** A variant of [Fix] that has a nice [Fix_eq] for functions which
    doesn't require [functional_extensionality]. *)
Section Fix2_3.
  Context A A' (B : A * A' -> Type) (C : forall a, B a -> Type) (D : forall a b, C a b -> Type)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall a b c, D a b c -> Type).

  Local Notation T := (fun a => tele _ (fun b => tele _ (fun c => tele (@D a b c) (fun _ => bottom)))).

  Let Fix2_3_eq' := @Fix2V_eq A A' T R Rwf P.
  Let Fix2_3_eq'T := Eval simpl in type_of Fix2_3_eq'.

  Let Fix2_3_rect' := @Fix2V_rect A A' T R Rwf P.
  Let Fix2_3_rect'T := Eval simpl in type_of Fix2_3_rect'.

  Let Fix2_3_Proper_eq' := @Fix2V_Proper_eq A A' T R Rwf P.
  Let Fix2_3_Proper_eq'T := Eval simpl in type_of Fix2_3_Proper_eq'.

  Let Fix3_2_3_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix3_2_3_eq'T := Eval simpl in type_of Fix3_2_3_eq'.

  Definition Fix2_3_eq : Fix2_3_eq'T := Fix2_3_eq'.
  Definition Fix2_3_rect : Fix2_3_rect'T := Fix2_3_rect'.
  Definition Fix2_3_Proper_eq : Fix2_3_Proper_eq'T := Fix2_3_Proper_eq'.
  Definition Fix3_2_3_eq : Fix3_2_3_eq'T := Fix3_2_3_eq'.
End Fix2_3.

Arguments Fix2_3_Proper_eq {A A' B C D R Rwf P} _ _ _ _ _ _ _ _.
Global Existing Instance Fix2_3_Proper_eq.

Section Fix2_4.
  Context A A' (B : A * A' -> Type) (C : forall a, B a -> Type) (D : forall a b, C a b -> Type) (E : forall a b c, D a b c -> Type)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall a b c d, E a b c d -> Type).

  Local Notation T := (fun a => tele _ (fun b => tele _ (fun c => tele _ (fun d => tele (@E a b c d) (fun _ => bottom))))).

  Let Fix2_4_eq' := @Fix2V_eq A A' T R Rwf P.
  Let Fix2_4_eq'T := Eval simpl in type_of Fix2_4_eq'.

  Let Fix2_4_rect' := @Fix2V_rect A A' T R Rwf P.
  Let Fix2_4_rect'T := Eval simpl in type_of Fix2_4_rect'.

  Let Fix2_4_Proper_eq' := @Fix2V_Proper_eq A A' T R Rwf P.
  Let Fix2_4_Proper_eq'T := Eval simpl in type_of Fix2_4_Proper_eq'.

  Let Fix4_2_4_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix4_2_4_eq'T := Eval simpl in type_of Fix4_2_4_eq'.

  Definition Fix2_4_eq : Fix2_4_eq'T := Fix2_4_eq'.
  Definition Fix2_4_rect : Fix2_4_rect'T := Fix2_4_rect'.
  Definition Fix2_4_Proper_eq : Fix2_4_Proper_eq'T := Fix2_4_Proper_eq'.
  Definition Fix4_2_4_eq : Fix4_2_4_eq'T := Fix4_2_4_eq'.
End Fix2_4.

Arguments Fix2_4_Proper_eq {A A' B C D E R Rwf P} _ _ _ _ _ _ _ _ _.
Global Existing Instance Fix2_4_Proper_eq.

Section Fix2_5.
  Context A A' (B : A * A' -> Type) (C : forall a, B a -> Type) (D : forall a b, C a b -> Type) (E : forall a b c, D a b c -> Type) (H : forall a b c d, E a b c d -> Type)
          (R : A * A' -> A * A' -> Prop) (Rwf : well_founded R)
          (P : forall a b c d e, H a b c d e -> Type).

  Local Notation T := (fun a => tele _ (fun b => tele _ (fun c => tele _ (fun d => tele _ (fun e => tele (@H a b c d e) (fun _ => bottom)))))).

  Let Fix2_5_eq' := @Fix2V_eq A A' T R Rwf P.
  Let Fix2_5_eq'T := Eval simpl in type_of Fix2_5_eq'.

  Let Fix2_5_rect' := @Fix2V_rect A A' T R Rwf P.
  Let Fix2_5_rect'T := Eval simpl in type_of Fix2_5_rect'.

  Let Fix2_5_Proper_eq' := @Fix2V_Proper_eq A A' T R Rwf P.
  Let Fix2_5_Proper_eq'T := Eval simpl in type_of Fix2_5_Proper_eq'.

  Let Fix5_2_5_eq' := @FixV_2V_eq A A' T R Rwf P.
  Let Fix5_2_5_eq'T := Eval simpl in type_of Fix5_2_5_eq'.

  Definition Fix2_5_eq : Fix2_5_eq'T := Fix2_5_eq'.
  Definition Fix2_5_rect : Fix2_5_rect'T := Fix2_5_rect'.
  Definition Fix2_5_Proper_eq : Fix2_5_Proper_eq'T := Fix2_5_Proper_eq'.
  Definition Fix5_2_5_eq : Fix5_2_5_eq'T := Fix5_2_5_eq'.
End Fix2_5.

Arguments Fix2_5_Proper_eq {A A' B C D E H R Rwf P} _ _ _ _ _ _ _ _ _ _.
Global Existing Instance Fix2_5_Proper_eq.
