Require Import String Ensembles.
Require Import Common.
Require Import Computation.Core.

(* [Comp] obeys the monad laws, using [computes_to] as the
   notion of equivalence. .*)

Section monad.
  Context `{ctx : LookupContext}.

  Local Ltac t :=
    split;
    intro;
    repeat match goal with
             | [ H : _ |- _ ]
               => inversion H; clear H; subst; [];
                  repeat match goal with
                           | [ H : _ |- _ ] => apply inj_pair2 in H; subst
                         end
           end;
      repeat first [ eassumption
                   | solve [ constructor ]
                   | eapply BindComputes; (eassumption || (try eassumption; [])) ].

  Lemma bind_bind X Y Z (f : X -> Comp Y) (g : Y -> Comp Z) x v
  : Bind (Bind x f) g ↝ v
    <-> Bind x (fun u => Bind (f u) g) ↝ v.
  Proof.
    t.
  Qed.

  Lemma bind_unit X Y (f : X -> Comp Y) x v
  : Bind (Return x) f ↝ v
    <-> f x ↝ v.
  Proof.
    t.
  Qed.

  Lemma unit_bind X (x : Comp X) v
  : (Bind x (@Return _ X)) ↝ v
    <-> x ↝ v.
  Proof.
    t.
  Qed.

  Lemma computes_under_bind X Y (f g : X -> Comp Y) x
  : (forall x v, f x ↝ v <-> g x ↝ v) ->
    (forall v, Bind x f ↝ v <-> Bind x g ↝ v).
  Proof.
    t; split_iff; eauto.
  Qed.

End monad.


(* [Comp] also obeys the monad laws using both [refineEquiv] and
   [refineBundledEquiv] as our notions of equivalence. *)

Section monad_refine.
  Context `{ctx : LookupContext}.

  Lemma refineEquiv_bind_bind X Y Z (f : X -> Comp Y) (g : Y -> Comp Z) x
  : refineEquiv (Bind (Bind x f) g)
                (Bind x (fun u => Bind (f u) g)).
  Proof.
    split; intro; apply bind_bind.
  Qed.

  Definition refineBundledEquiv_bind_bind
  : forall X Y Z f g x, refineBundledEquiv `[ _ ]` `[ _ ]`
    := refineEquiv_bind_bind.

  Lemma refineEquiv_bind_unit X Y (f : X -> Comp Y) x
  : refineEquiv (Bind (Return x) f)
                (f x).
  Proof.
    split; intro; simpl; apply bind_unit.
  Qed.

  Definition refineBundledEquiv_bind_unit
  : forall X Y f x, refineBundledEquiv `[ _ ]` `[ _ ]`
    := refineEquiv_bind_unit.

  Lemma refineEquiv_unit_bind X (x : Comp X)
  : refineEquiv (Bind x (@Return _ X))
                x.
  Proof.
    split; intro; apply unit_bind.
  Qed.

  Definition refineBundledEquiv_unit_bind
  : forall X x, refineBundledEquiv `[ _ ]` `[ _ ]`
    := refineEquiv_unit_bind.

  Lemma refineEquiv_under_bind X Y (f g : X -> Comp Y) x
        (eqv_f_g : forall x, refineEquiv (f x) (g x))
  : refineEquiv (Bind x f)
                (Bind x g).
  Proof.
    split; unfold refine; simpl in *; intros; eapply computes_under_bind;
    intros; eauto; split; eapply eqv_f_g.
  Qed.

  Definition refineBundledEquiv_under_bind
  : forall X Y f g x
           (equv_f_g : forall x, refineBundledEquiv `[ _ ]` `[ _ ]`),
      refineBundledEquiv `[ _ ]` `[ _ ]`
    := refineEquiv_under_bind.

End monad_refine.

Create HintDb refine_monad discriminated.

(*Hint Rewrite refine_bind_bind refine_bind_unit refine_unit_bind : refine_monad.
Hint Rewrite <- refine_bind_bind' refine_bind_unit' refine_unit_bind' : refine_monad.*)
Hint Rewrite @refineEquiv_bind_bind @refineEquiv_bind_unit @refineEquiv_unit_bind : refine_monad.
(* Ideally we would throw refineEquiv_under_bind in here as well, but it gets stuck *)

Ltac interleave_autorewrite_refine_monad_with tac :=
  repeat first [ reflexivity
               | progress tac
               | progress autorewrite with refine_monad
               (*| rewrite refine_bind_bind'; progress tac
               | rewrite refine_bind_unit'; progress tac
               | rewrite refine_unit_bind'; progress tac
               | rewrite <- refine_bind_bind; progress tac
               | rewrite <- refine_bind_unit; progress tac
               | rewrite <- refine_unit_bind; progress tac ]*)
               | rewrite <- !refineEquiv_bind_bind; progress tac
               | rewrite <- !refineEquiv_bind_unit; progress tac
               | rewrite <- !refineEquiv_unit_bind; progress tac
               (*| rewrite <- !refineEquiv_under_bind; progress tac *)].