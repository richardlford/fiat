Require Import Coq.Strings.String Coq.omega.Omega Coq.Lists.List
        Coq.Logic.FunctionalExtensionality Coq.Sets.Ensembles
        ADTSynthesis.Computation
        ADTSynthesis.ADT
        ADTSynthesis.ADTRefinement
        ADTSynthesis.ADTNotation
        ADTSynthesis.QueryStructure.Specification.Representation.QueryStructureSchema
        ADTSynthesis.ADTRefinement.BuildADTRefinements
        ADTSynthesis.QueryStructure.Specification.Representation.QueryStructure
        ADTSynthesis.Common.Ensembles.IndexedEnsembles
        ADTSynthesis.Common.IterateBoundedIndex
        ADTSynthesis.QueryStructure.Specification.Operations.Query
        ADTSynthesis.QueryStructure.Specification.Operations.Insert
        ADTSynthesis.QueryStructure.Implementation.Constraints.ConstraintChecksRefinements
        ADTSynthesis.QueryStructure.Implementation.Operations.General.InsertRefinements
        ADTSynthesis.QueryStructure.Automation.Common
        ADTSynthesis.QueryStructure.Automation.Constraints.TrivialConstraintAutomation
        ADTSynthesis.QueryStructure.Automation.Constraints.FunctionalDependencyAutomation
        ADTSynthesis.QueryStructure.Automation.Constraints.ForeignKeyAutomation.

(* When we insert a tuple into a relation which has another relation has
     a foreign key into, we need to show that we haven't messed up any
     references (which is, of course, trivial. We should bake this into
     our the [QSInsertSpec_refine'] refinement itself by filtering out the
     irrelevant constraints somehow, but for now we can use the following
     tactic to rewrite them away. *)

Ltac remove_trivial_insertion_constraints :=
      match goal with
        |- context[EnsembleInsert _ (GetUnConstrRelation _ _) ] =>
        match goal with
            AbsR : @DropQSConstraints_AbsR ?schm ?or ?nr
            |- context [
                   Pick
                     (fun b =>
                        decides
                          b
                          (forall tup' : @IndexedTuple ?heading,
                             (@GetUnConstrRelation ?schm ?r ?Ridx) tup' ->
                             ForeignKey_P (relSchema := ?heading') ?attr ?attr' ?tup_map
                                          (indexedElement tup')
                                          (EnsembleInsert ?tup (GetUnConstrRelation ?r ?Ridx'))))] =>
            let neq := fresh in
            assert (Ridx <> Ridx') by (subst_all; discriminate);
              let ForeignKeys_OK := fresh in
              assert (forall tup' : @IndexedTuple heading,
                        (@GetUnConstrRelation schm r Ridx) tup' ->
                        ForeignKey_P (heading := heading) (relSchema := heading') attr attr' tup_map
                                     (indexedElement tup')
                                     (GetUnConstrRelation r Ridx')) as
                  ForeignKeys_OK
                  by (subst_all; intro tup'; rewrite <- AbsR, !GetRelDropConstraints;
                      match goal with
                          |-  (GetRelation ?r ?idx) ?tup' ->
                              ForeignKey_P _ _ _ _ (GetRelation ?r ?idx') =>
                          apply (@crossConstr schm or idx idx' tup') end; discriminate);
                let refine_trivial := fresh in
                pose
                  (@InsertForeignKeysCheck schm nr Ridx Ridx' attr attr' tup_map tup
                                           ForeignKeys_OK neq) as refine_trivial;
                  simpl in refine_trivial;
                  fold_heading_hyps_in refine_trivial; fold_string_hyps_in refine_trivial;
                  fold_heading_hyps; fold_string_hyps; setoid_rewrite refine_trivial;
                  clear refine_trivial; simplify with monad laws
        end end.

Tactic Notation "remove" "trivial" "insertion" "checks" :=
  (* Move all the binds we can outside the exists / computes
   used for abstraction, stopping when we've rewritten
         the bind in [QSInsertSpec]. *)
  repeat rewrite refineEquiv_bind_bind;
  etransitivity;
  [ repeat (apply refine_bind;
            [reflexivity
            | match goal with
                | |- context [Bind (Insert _ into _)%QuerySpec _] =>
                  unfold pointwise_relation; intros
                    end
                 ] );
    (* Pull out the relation we're inserting into and then
     rewrite [QSInsertSpec] *)
    match goal with
        H : DropQSConstraints_AbsR _ ?r_n
        |- context [(QSInsert _ ?R ?n)%QuerySpec] =>
        let H' := fresh in
        (* If we try to eapply [QSInsertSpec_UnConstr_refine] directly
                   after we've drilled under a bind, this tactic will fail because
                   typeclass resolution breaks down. Generalizing and applying gets
                   around this problem for reasons unknown. *)
        let H' := fresh in
        pose (@QSInsertSpec_UnConstr_refine_opt  _ r_n R n _ H) as H';
          cbv beta delta [tupleConstraints attrConstraints map app relName schemaHeading] iota in H';
          simpl in H'; fold_heading_hyps_in H'; fold_string_hyps_in H'; exact H'
    end
  |  pose_string_hyps; pose_heading_hyps;
     cbv beta iota delta [tupleConstraints attrConstraints map app
                                          relName schemaHeading];
      simpl;
    simplify with monad laws;
    try rewrite <- GetRelDropConstraints;
    repeat match goal with
             | H : DropQSConstraints_AbsR ?qs ?uqs |- _ =>
               rewrite H in *
           end
  ].

Tactic Notation "Split" "Constraint" "Checks" :=
  repeat (let b := match goal with
                     | [ |- context[if ?X then _ else _] ] => constr:(X)
                     | [ H : context[if ?X then _ else _] |- _ ]=> constr:(X)
                   end in
          let b_eq := fresh in
          eapply (@refine_if _ _ b); intros b_eq;
          simpl in *; repeat rewrite b_eq; simpl).

Tactic Notation "implement" "failed" "insert" :=
  repeat (rewrite refine_pick_val, refineEquiv_bind_unit; eauto);
  reflexivity.

Ltac drop_symmetric_functional_dependencies :=
  match goal with
         |- context[x <- {b | decides b (forall tup',
                                           @?P tup'
                                           -> FunctionalDependency_P ?attrlist1 ?attrlist2 ?n
                                                                     (indexedElement tup'))};
                     y <- {b | decides b (forall tup',
                                            @?P tup'
                                           -> FunctionalDependency_P ?attrlist1 ?attrlist2
                                                                     (indexedElement tup') ?n)};
                     @?f x y] =>
         setoid_rewrite (@FunctionalDependency_symmetry _ _ f P attrlist1 attrlist2 n) at 1;
           try setoid_rewrite if_duplicate_cond_eq
  end.


Ltac drop_constraints_from_insert :=
  remove trivial insertion checks;
  (* The trivial insertion checks involve the fresh id,
       so we need to drill under the binder before
       attempting to remove them. *)
  rewrite refine_bind;
    [ | reflexivity |
      unfold pointwise_relation; intros;
      repeat remove_trivial_insertion_constraints;
      (* These simplify and implement nontrivial constraint checks *)
      repeat first
             [ drop_symmetric_functional_dependencies
             | fundepToQuery; try simplify with monad laws
             | foreignToQuery; try simplify with monad laws
             | setoid_rewrite refine_trivial_if_then_else; simplify with monad laws
             ];
      pose_string_hyps; pose_heading_hyps;
      higher_order_reflexivity ];
    pose_string_hyps; pose_heading_hyps; finish honing.

Tactic Notation "drop" "constraints" "from" "insert" constr(methname) :=
  drop_constraints_from_insert methname.