Require Import Coq.Sorting.Mergesort Coq.Structures.Orders
        Coq.Arith.Arith
        Coq.Structures.OrderedType Coq.Structures.OrderedTypeEx
        Coq.Strings.String Coq.FSets.FMapAVL
        ADTSynthesis.Common.String_as_OT
        ADTSynthesis.QueryStructure.Specification.Representation.QueryStructureNotations
        ADTSynthesis.QueryStructure.Implementation.Operations
        ADTSynthesis.QueryStructure.Implementation.DataStructures.BagADT.QueryStructureImplementation
        ADTSynthesis.QueryStructure.Implementation.DataStructures.BagADT.IndexSearchTerms
        ADTSynthesis.QueryStructure.Automation.Common.

Module AttrCountOrder <: TotalLeBool.
  Definition t := (prod (string * (string * string)) nat).

  (* Largest element first *)
  Definition leb (x y : t) :=
    leb (snd y) (snd x).

  Theorem leb_total : forall a1 a2 : t, leb a1 a2 = true \/ leb a2 a1 = true.
  Proof.
    unfold t; intros; intuition; unfold leb; simpl.
    case_eq (Compare_dec.leb b b0); intuition.
    case_eq (Compare_dec.leb b0 b); intuition.
    apply leb_iff_conv in H; apply leb_iff_conv in H0.
    omega.
  Qed.

End AttrCountOrder.

Module PairOfString_As_OT := (PairOrderedType String_as_OT String_as_OT).
Module TripleOfString_As_OT := (PairOrderedType String_as_OT PairOfString_As_OT).

Module RelationAttributeCounter := FMapAVL.Make TripleOfString_As_OT.
Module Import AttrCountSort := Sort AttrCountOrder.

Record KindName
  := { KindNameKind : string;
       KindNameName : string }.

Definition IncrementAttrCount
           (idx : string * (string * string))
           (cnt : RelationAttributeCounter.t nat)
: RelationAttributeCounter.t nat :=
  match RelationAttributeCounter.find idx cnt with
    | Some n => RelationAttributeCounter.add idx (S n) cnt
    | _ => RelationAttributeCounter.add idx 1 cnt
  end.

Definition CountAttributes (l : list (string * (string * string)))
: list ((string * (string * string)) * nat)  :=
  sort (RelationAttributeCounter.elements
          (fold_right IncrementAttrCount
                      (RelationAttributeCounter.empty nat)
                      l)).

Definition GetIndexes
           (qs_schema : QueryStructureSchema)
           (indices : list ((string * (string * string)) * nat))
: list (list (string * string)) :=
  map (fun ns : NamedSchema =>
         map (fun index => (fst (fst index), snd (snd (fst index))))
             (filter (fun index => if (string_dec (fst (snd (fst index)))) (relName ns)
                                   then true
                                   else false)
                     indices))
      (qschemaSchemas qs_schema).

  Ltac TermAttributes Term :=
    match Term with
      | fun tups => @GetAttribute _ (@?f tups) ?BAidx =>
        let Aidx := eval simpl in (bindex BAidx) in
            match type of f with
              | _ -> @Tuple (GetHeading _ ?Ridx) =>
                constr:([(Ridx, Aidx)])
            end
    end.

  Ltac ClauseAttributes WhereClause kTerm k :=
  match WhereClause with
    | fun tups => @?C1 tups /\ @?C2 tups =>
      ClauseAttributes C1 kTerm
                       ltac:(fun attrs1 =>
                               ClauseAttributes C2 kTerm
                                                ltac:(fun attrs2 =>
                                                        k (app attrs2 attrs1)))
    | fun tups => @?C1 tups = @?C2 tups =>
      let attrs1 := TermAttributes C1 in
      let attrs2 := TermAttributes C2 in
      k (map (fun a12 => (EqualityIndex, (fst a12, snd a12)))
             (app attrs1 attrs2))
    | fun tups => @?C1 tups = _ =>
      let attrs1 := TermAttributes C1 in
      k (map (fun a12 => (EqualityIndex, (fst a12, snd a12)))
             (attrs1))
    | fun tups => _ = @?C1 tups =>
      let attrs1 := TermAttributes C1 in
      k (map (fun a12 => (EqualityIndex, (fst a12, snd a12)))
             (attrs1))
    | _ => kTerm WhereClause k
    | _ => k (@nil (string * (string * string)))
  end.

Ltac QueryAttributes QueryBody kTerm k :=
  match QueryBody with
    | @UnConstrQuery_In _ ?qsSchema _ ?Ridx ?QueryBody' => (* Initial "Naked" Case *)
      let Ridx' := eval simpl in (bindex Ridx) in
          let QueryBody'' := eval cbv beta in (fun tup : @Tuple (GetHeading qsSchema Ridx') => QueryBody' tup) in
              QueryAttributes QueryBody'' kTerm k  (* Simply recurse under binder *)

    | fun tups : ?A =>
        @UnConstrQuery_In _ ?qsSchema _ ?Ridx
                          (@?f tups) => (* Already Under binder *)
      let Ridx' := eval simpl in (bindex Ridx) in
      let join := eval cbv beta in
      (fun joinedtups : prod A (@Tuple (GetHeading qsSchema Ridx')) =>
         f (fst joinedtups) (snd joinedtups)) in
          QueryAttributes join kTerm k
    | fun tups => Where (@?P tups) (@?QueryBody' tups) =>
      ClauseAttributes P kTerm
                       ltac:(fun attrs =>
                               QueryAttributes QueryBody' kTerm ltac:(fun attrs' => k (app attrs attrs')))
    | _ => k (@nil (string * (string * string)))
  end.

Ltac MethodAttributes meth kTerm l :=
  hone method meth;
  [ match goal with
        |- context[For ?Q] =>
        QueryAttributes
                 Q kTerm ltac:(fun attrs => let attrs' := eval simpl in attrs in
                                          unify l attrs')
      | _ => unify l (@nil (string * (string * string)))
    end; finish honing | ].

Ltac MethodsAttributes' meths kTerm l :=
  match meths with
    | cons ?meth ?meths' =>
      makeEvar (list (string * (string * string)))
               ltac:(fun l1 =>
                       makeEvar (list (string * (string * string)))
                                ltac:(fun l2 =>
                                        unify l (app l1 l2);
                                      MethodAttributes meth kTerm l1;
                                      MethodsAttributes' meths' kTerm l2))
    | nil => unify l (@nil (string * (string * string)))
  end.

Ltac GenerateIndexesFor meths kTerm k :=
  match goal with
      |- Sharpened
           (@BuildADT (UnConstrQueryStructure ?qs_schema) _ _ _ _) =>
      makeEvar (list (string * (string * string)))
               ltac:(fun l =>
                       MethodsAttributes' meths kTerm l;
                     let l' := eval compute in
                     (GetIndexes qs_schema (CountAttributes l)) in
                         k l')
  end.

Ltac GenerateIndexesForAll kTerm k :=
  match goal with
      |- Sharpened
           (@BuildADT (UnConstrQueryStructure ?qs_schema) _ ?methSigs _ _) =>
      let meths := eval compute in (map methID methSigs) in
          GenerateIndexesFor meths kTerm k
  end.

Tactic Notation "make" "simple" "indexes" "using" constr(attrlist) :=
  match goal with
    | [ |- Sharpened (@BuildADT (UnConstrQueryStructure ?sch) _ _ _ _ )] =>
      let sch' := eval simpl in (qschemaSchemas sch) in
          makeIndex' sch' attrlist
                     ltac:(fun l =>
                             pose_string_hyps; pose_heading_hyps;
                           let index := fresh "Index" in
                           pose l as index;
                           simpl in index;
                           pose_string_hyps_in index; pose_heading_hyps_in index;
                           pose_search_term_in index;
                           pose_SearchUpdateTerms_in index;
                           hone representation using (@DelegateToBag_AbsR sch index))
  end.

Tactic Notation "make" "indexes" "using" tactic(ClauseMatchers) :=
  GenerateIndexesForAll
    ClauseMatchers
    ltac:(fun attrlist => make simple indexes using attrlist).

(* Recurse over [fds] to find an attribute matching s *)
Ltac findMatchingTerm fds kind s k :=
  match fds with
    | ({| KindNameKind := ?IndexType;
          KindNameName := ?fd |}, ?X) =>
      (* Check if this field name is equal to s; process [X] with [k] if so. *)
      let H := fresh in
      assert (H : s = fd) by reflexivity; clear H;
      assert (H : kind = IndexType) by reflexivity; clear H;
      k X
    | (?fds1, ?fds2) => findMatchingTerm fds1 kind s k || findMatchingTerm fds2 kind s k
  end.