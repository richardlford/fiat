Require Import Coq.Lists.List Coq.Strings.String Coq.Logic.FunctionalExtensionality Coq.Sets.Ensembles
        ADTSynthesis.Common.ilist ADTSynthesis.Common.StringBound Coq.Program.Program
        ADTSynthesis.QueryStructure.Specification.Representation.Notations.

(* A heading describes a tuple as a set of Attributes
   and types. *)
Record Heading :=
  { Attributes : Set;
    Domain : Attributes -> Type
  }.

(* Notations for attributes. *)

Record Attribute :=
  { attrName : string;
    attrType : Type }.

Infix "::" := Build_Attribute : Attribute_scope.

Bind Scope Attribute_scope with Attribute.

Definition attrName_eq (cs : Attribute) (idx : string) :=
  if (string_dec (attrName cs) idx) then true else false .

(* Notations for schemas. *)

Definition BuildHeading
           (attrs : list Attribute)
: Heading :=
  {| Attributes := @BoundedString (map attrName attrs);
     Domain idx := attrType (nth_Bounded _ attrs idx) |}.

(* Notation for schemas built from [BuildHeading]. *)

Notation "< col1 , .. , coln >" :=
  (BuildHeading ( col1%Attribute :: .. (coln%Attribute :: []) ..))
  : Heading_scope.