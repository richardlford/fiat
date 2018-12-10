Require Import
        Coq.Strings.String
        Coq.Vectors.Vector
        Coq.omega.Omega.

Require Import
        Fiat.Common.SumType
        Fiat.Common.EnumType
        Fiat.Common.BoundedLookup
        Fiat.Common.ilist
        Fiat.Computation
        Fiat.QueryStructure.Specification.Representation.Notations
        Fiat.QueryStructure.Specification.Representation.Heading
        Fiat.QueryStructure.Specification.Representation.Tuple
        Fiat.Narcissus.BinLib.AlignedByteString
        Fiat.Narcissus.BinLib.AlignWord
        Fiat.Narcissus.BinLib.AlignedList
        Fiat.Narcissus.BinLib.AlignedDecoders
        Fiat.Narcissus.BinLib.AlignedDecodeMonad
        Fiat.Narcissus.BinLib.AlignedEncodeMonad
        Fiat.Narcissus.Common.Specs
        Fiat.Narcissus.Common.WordFacts
        Fiat.Narcissus.Common.ComposeCheckSum
        Fiat.Narcissus.Common.ComposeIf
        Fiat.Narcissus.Common.ComposeOpt
        Fiat.Narcissus.Formats
        Fiat.Narcissus.BaseFormats
        Fiat.Narcissus.Stores.EmptyStore.

Require Import Bedrock.Word.

Definition decode_IPChecksum
  : ByteString -> CacheDecode -> option (() * ByteString * CacheDecode) :=
  decode_unused_word (sz := 16).

Definition encode_word {sz} (w : word sz) : ByteString :=
  encode_word' sz w ByteString_id.

Fixpoint Vector_checksum_bound n {sz} (bytes :ByteBuffer.t sz) acc : InternetChecksum.W16 :=
  match n, bytes with
  | 0, _ => acc
  | _, Vector.nil => acc
  | S 0, Vector.cons x _ _ => InternetChecksum.add_bytes_into_checksum x (wzero _) acc
  | _, Vector.cons x _ Vector.nil => InternetChecksum.add_bytes_into_checksum x (wzero _) acc
  | S (S n'), Vector.cons x _ (Vector.cons y _ t) =>
    (Vector_checksum_bound n' t (InternetChecksum.add_bytes_into_checksum x y acc))
  end.

Definition ByteBuffer_checksum_bound' n {sz} (bytes : ByteBuffer.t sz) : InternetChecksum.W16 :=
  InternetChecksum.ByteBuffer_fold_left_pair InternetChecksum.add_bytes_into_checksum n bytes (wzero _) (wzero _).

Lemma ByteBuffer_checksum_bound'_ok' :
  forall n {sz} (bytes :ByteBuffer.t sz) acc,
    Vector_checksum_bound n bytes acc =
    InternetChecksum.ByteBuffer_fold_left_pair InternetChecksum.add_bytes_into_checksum n bytes acc (wzero _).
Proof.
  fix IH 3.
  destruct bytes as [ | hd sz [ | hd' sz' tl ] ]; intros; simpl.
  - destruct n as [ | [ | ] ]; reflexivity.
  - destruct n as [ | [ | ] ]; reflexivity.
  - destruct n as [ | [ | ] ]; simpl; try reflexivity.
    rewrite IH; reflexivity.
Qed.

Lemma ByteBuffer_checksum_bound'_ok :
  forall n {sz} (bytes :ByteBuffer.t sz),
    Vector_checksum_bound n bytes (wzero _) = ByteBuffer_checksum_bound' n bytes.
Proof.
  intros; apply ByteBuffer_checksum_bound'_ok'.
Qed.

Definition IPChecksum_Valid_dec (n : nat) (b : ByteString)
  : {IPChecksum_Valid n b} + {~IPChecksum_Valid n b} := weq _ _.

Definition calculate_IPChecksum {S} {sz}
  : AlignedEncodeM (S := S) sz :=
  (fun v =>
     (let checksum := InternetChecksum.ByteBuffer_checksum_bound 20 v in
      (fun v idx s => SetByteAt (n := sz) 10 v 0 (wnot (split2 8 8 checksum)) ) >>
                                                                                (fun v idx s => SetByteAt (n := sz) 11 v 0 (wnot (split1 8 8 checksum)))) v)%AlignedEncodeM.

Lemma CorrectAlignedEncoderForIPChecksumThenC
        {S}
        (format_A format_B : FormatM S ByteString)
        (encode_A : forall sz, AlignedEncodeM sz)
        (encode_B : forall sz, AlignedEncodeM sz)
        (encoder_B_OK : CorrectAlignedEncoder format_B encode_B)
        (encoder_A_OK : CorrectAlignedEncoder format_A encode_A)
    : CorrectAlignedEncoder
        (format_B ThenChecksum IPChecksum_Valid OfSize 16 ThenCarryOn format_A)
        (fun sz => encode_B sz >>
                   (fun v idx s => SetCurrentByte v idx (wzero 8)) >>
                   (fun v idx s => SetCurrentByte v idx (wzero 8)) >>
                   encode_A sz >>
                   calculate_IPChecksum)% AlignedEncodeM.
  Proof.
Admitted.

(* Lemma CorrectAlignedDecoderForIPChecksumThenC {A} *)
(*       predicate *)
(*       (format_A format_B : FormatM A ByteString) *)
(*       (len_format_A : A -> nat) *)
(*       (len_format_A_OK : forall a' b ctx ctx', *)
(*           computes_to (format_A a' ctx) (b, ctx') *)
(*           -> length_ByteString b = len_format_A a') *)
(*   : CorrectAlignedDecoderFor *)
(*       predicate *)
(*       (format_A ++ format_unused_word 16 ++ format_B)%format *)
(*     -> CorrectAlignedDecoderFor *)
(*          predicate *)
(*          (format_A ThenChecksum IPChecksum_Valid OfSize 16 ThenCarryOn format_B). *)
(* Proof. *)
(*   intros H; destruct H as [ ? [ [? ?] [ ? ?] ] ]; simpl in *. *)
(*   eexists (fun sz v => if weq (InternetChecksum.ByteBuffer_checksum_bound 20 v) (wones 16) then x sz v  else ThrowAlignedDecodeM v). *)
(*   admit. *)
(* Defined. *)

Definition splitLength (len: word 16) : Vector.t (word 8) 2 :=
  Vector.cons _ (split2 8 8 len) _ (Vector.cons _ (split1 8 8 len) _ (Vector.nil _)).

Definition Pseudo_Checksum_Valid (* FIXME payload should be after src, dest *)
           (srcAddr : Vector.t (word 8) 4)
           (destAddr : Vector.t (word 8) 4)
           (udpLength : word 16)
           (protoCode : word 8)
           (n : nat)
           (b : ByteString)
  := onesComplement (wzero 8 :: protoCode ::
                           (ByteString2ListOfChar n b)
                           ++ to_list srcAddr ++ to_list destAddr ++ to_list (splitLength udpLength))%list
     = wones 16.

Import VectorNotations.

Definition pseudoHeader_checksum
           (srcAddr : Vector.t (word 8) 4)
           (destAddr : Vector.t (word 8) 4)
           (udpLength : word 16)
           (protoCode : word 8)
           {sz} (packet: ByteBuffer.t sz) :=
  InternetChecksum.ByteBuffer_checksum_bound (12 + wordToNat udpLength)
                                             (srcAddr ++ destAddr ++ [wzero 8; protoCode] ++ (splitLength udpLength) ++ packet).

Infix "^1+" := (InternetChecksum.OneC_plus) (at level 50, left associativity).

Import InternetChecksum.

Definition pseudoHeader_checksum'
           (srcAddr : Vector.t (word 8) 4)
           (destAddr : Vector.t (word 8) 4)
           (udpLength : word 16)
           (protoCode : word 8)
           {sz} (packet: ByteBuffer.t sz) :=
  ByteBuffer_checksum srcAddr ^1+
                               ByteBuffer_checksum destAddr ^1+
                                                             zext protoCode 8 ^1+
                                                                               udpLength ^1+
                                                                                          InternetChecksum.ByteBuffer_checksum_bound (wordToNat udpLength) packet.

Lemma OneC_plus_wzero_l :
  forall w, OneC_plus (wzero 16) w = w.
Proof. reflexivity. Qed.

Lemma OneC_plus_wzero_r :
  forall w, OneC_plus w (wzero 16) = w.
Proof.
  intros; rewrite OneC_plus_comm; reflexivity.
Qed.

Lemma Buffer_fold_left16_acc_oneC_plus :
  forall {sz} (packet: ByteBuffer.t sz) acc n,
    ByteBuffer_fold_left16 add_w16_into_checksum n packet acc =
    OneC_plus
      (ByteBuffer_fold_left16 add_w16_into_checksum n packet (wzero 16))
      acc.
Proof.
  fix IH 2.
  unfold ByteBuffer_fold_left16 in *.
  destruct packet as [ | hd sz [ | hd' sz' tl ] ]; intros; simpl.
  - destruct n as [ | [ | ] ]; reflexivity.
  - destruct n as [ | [ | ] ]; simpl; unfold add_bytes_into_checksum, add_w16_into_checksum;
      try rewrite OneC_plus_wzero_l, OneC_plus_comm; reflexivity.
  - destruct n as [ | [ | ] ]; simpl; unfold add_bytes_into_checksum, add_w16_into_checksum;
      try rewrite OneC_plus_wzero_l, OneC_plus_comm; try reflexivity.
    rewrite (IH _ tl (hd' +^+ hd ^1+ acc)).
    rewrite (IH _ tl (hd' +^+ hd)).
    rewrite OneC_plus_assoc.
    reflexivity.
Qed.

Lemma Vector_destruct_S :
  forall {A sz} (v: Vector.t A (S sz)),
  exists hd tl, v = hd :: tl.
Proof.
  repeat eexists.
  apply VectorSpec.eta.
Defined.

Lemma Vector_destruct_O :
  forall {A} (v: Vector.t A 0),
    v = [].
Proof.
  intro; apply VectorDef.case0; reflexivity.
Qed.

Ltac explode_vector :=
  lazymatch goal with
  | [ v: Vector.t ?A (S ?n) |- _ ] =>
    let hd := fresh "hd" in
    let tl := fresh "tl" in
    rewrite (Vector.eta v) in *;
    set (Vector.hd v: A) as hd; clearbody hd;
    set (Vector.tl v: Vector.t A n) as tl; clearbody tl;
    clear v
  | [ v: Vector.t _ 0 |- _ ] =>
    rewrite (Vector_destruct_O v) in *; clear v
  end.

Lemma pseudoHeader_checksum'_ok :
  forall (srcAddr : Vector.t (word 8) 4)
         (destAddr : Vector.t (word 8) 4)
         (udpLength : word 16)
         (protoCode : word 8)
         {sz} (packet: ByteBuffer.t sz),
    pseudoHeader_checksum srcAddr destAddr udpLength protoCode packet =
    pseudoHeader_checksum' srcAddr destAddr udpLength protoCode packet.
Proof.
  unfold pseudoHeader_checksum, pseudoHeader_checksum'.
  intros.
  repeat explode_vector.
  Opaque split1.
  Opaque split2.
  simpl in *.
  unfold ByteBuffer_checksum, InternetChecksum.ByteBuffer_checksum_bound, add_w16_into_checksum,
  add_bytes_into_checksum, ByteBuffer_fold_left16, ByteBuffer_fold_left_pair.
  fold @ByteBuffer_fold_left_pair.
  setoid_rewrite Buffer_fold_left16_acc_oneC_plus.
  rewrite combine_split.
  rewrite !OneC_plus_wzero_r, !OneC_plus_wzero_l, OneC_plus_comm.
  repeat (f_equal; [ ]).
  rewrite <- !OneC_plus_assoc.
  reflexivity.
Qed.

Definition calculate_PseudoChecksum {S} {sz}
           (srcAddr : Vector.t (word 8) 4)
           (destAddr : Vector.t (word 8) 4)
           (udpLength : word 16)
           (protoCode : word 8)
           (idx' : nat)
  : AlignedEncodeM (S := S) sz :=
  (fun v idx s =>
     (let checksum := pseudoHeader_checksum' srcAddr destAddr udpLength protoCode v in
      (fun v idx s => SetByteAt (n := sz) idx' v 0 (wnot (split2 8 8 checksum)) ) >>
                                                                                  (fun v idx s => SetByteAt (n := sz) (1 + idx') v 0 (wnot (split1 8 8 checksum)))) v idx s)%AlignedEncodeM.

Lemma CorrectAlignedEncoderForPseudoChecksumThenC
      {S}
      (srcAddr : Vector.t (word 8) 4)
      (destAddr : Vector.t (word 8) 4)
      (udpLength : word 16)
      (protoCode : word 8)
      (idx : nat)
      (format_A format_B : FormatM S ByteString)
      (encode_A : forall sz, AlignedEncodeM sz)
      (encode_B : forall sz, AlignedEncodeM sz)
      (encoder_B_OK : CorrectAlignedEncoder format_B encode_B)
      (encoder_A_OK : CorrectAlignedEncoder format_A encode_A)
      (idxOK : forall (s : S) (b : ByteString) (env env' : CacheFormat),
          format_B s env ∋ (b, env') -> length_ByteString b = idx)
  : CorrectAlignedEncoder
      (format_B ThenChecksum (Pseudo_Checksum_Valid srcAddr destAddr udpLength protoCode) OfSize 16 ThenCarryOn format_A)
      (fun sz => encode_B sz >>
                          (fun v idx s => SetCurrentByte v idx (wzero 8)) >>
                          (fun v idx s => SetCurrentByte v idx (wzero 8)) >>
                          encode_A sz >>
                          calculate_PseudoChecksum srcAddr destAddr udpLength protoCode (NPeano.div idx 8))% AlignedEncodeM.
Proof.
  admit.
Defined.

Lemma ByteBuffer_to_list_append {sz sz'}
  : forall (v : ByteBuffer.t sz)
           (v' : ByteBuffer.t sz'),
    ByteBuffer.to_list (v ++ v')%vector
    = ((ByteBuffer.to_list v) ++ (ByteBuffer.to_list v'))%list.
Proof.
  induction v.
  - reflexivity.
  - simpl; intros.
    unfold ByteBuffer.to_list at 1; unfold to_list.
    f_equal.
    apply IHv.
Qed.

Import VectorNotations.

Lemma compose_PseudoChecksum_format_correct {A}
      (srcAddr : Vector.t (word 8) 4)
      (destAddr : Vector.t (word 8) 4)
      (udpLength : word 16)
      protoCode
      (predicate : A -> Prop)
      (P : CacheDecode -> Prop)
      (P_inv : (CacheDecode -> Prop) -> Prop)
      (format_A format_B : FormatM A ByteString)
      (formated_measure : _ -> nat)
      (len_format_A : A -> nat)
      (len_format_A_OK : forall a' b ctx ctx',
          computes_to (format_A a' ctx) (b, ctx')
          -> length_ByteString b = len_format_A a')
      (len_format_B : A -> nat)
      (len_format_B_OK : forall a' b ctx ctx',
          computes_to (format_B a' ctx) (b, ctx')
          -> length_ByteString b = len_format_B a')
  : cache_inv_Property P P_inv ->
    (forall a, NPeano.modulo (len_format_A a) 8 = 0)
      -> (forall a, NPeano.modulo (len_format_B a) 8 = 0)
      -> (forall (a : A) (ctx ctx' ctx'' : CacheFormat) c (b b'' ext : _),
             format_A a ctx ↝ (b, ctx') ->
             format_B a ctx' ↝ (b'', ctx'') ->
             predicate a ->
             len_format_A a + len_format_B a + 16 =
             formated_measure (mappend (mappend b (mappend (format_checksum _ _ _ 16 c) b'')) ext)) ->
      forall decodeA : _ -> CacheDecode -> option (A * _ * CacheDecode),
        (cache_inv_Property P P_inv ->
         CorrectDecoder monoid predicate (fun _ _ => True) (format_A ++ format_unused_word 16 ++ format_B)%format decodeA P) ->
        CorrectDecoder monoid predicate (fun _ _ => True)
                       (format_A ThenChecksum (Pseudo_Checksum_Valid srcAddr destAddr udpLength protoCode) OfSize 16 ThenCarryOn format_B)
                       (fun (v : ByteString) (env : CacheDecode) =>
                          if weqb (onesComplement (wzero 8 :: protoCode ::
                                                         to_list srcAddr ++ to_list destAddr ++ to_list (splitLength udpLength)
                                                         ++(ByteString2ListOfChar ((formated_measure v)) v))%list) (wones 16)
                          then
                            decodeA v env
                          else None) P.
Proof.
  intros.
  Opaque CorrectDecoder.
  (*eapply composeChecksum_format_correct; eauto.
  - intros; rewrite !mappend_measure.
    simpl; rewrite (H0 _ _ _ _ H6).
    simpl; rewrite (H1 _ _ _ _ H7).
    erewrite <- H4; eauto; try omega.
    unfold format_checksum.
    rewrite length_encode_word'.
    simpl; omega.
  - unfold IPChecksum_Valid in *; intros; simpl.
    rewrite ByteString2ListOfChar_Over.
    * rewrite ByteString2ListOfChar_Over in H9.
      eauto.
      simpl.
      apply H0 in H7.
      pose proof (H2 data).
      rewrite <- H7 in H10.
      rewrite !ByteString_enqueue_ByteString_padding_eq.
      rewrite padding_eq_mod_8, H10.
      pose proof (H3 data).
      unfold format_checksum.
      rewrite encode_word'_padding.
      rewrite <- (H1 _ _ _ _ H8) in H11.
      rewrite padding_eq_mod_8, H11.
      reflexivity.
    * rewrite !ByteString_enqueue_ByteString_padding_eq.
      apply H0 in H7.
      pose proof (H2 data).
      rewrite <- H7 in H10.
      rewrite padding_eq_mod_8, H10.
      pose proof (H3 data).
      unfold format_checksum.
      rewrite encode_word'_padding.
      rewrite <- (H1 _ _ _ _ H8) in H11.
      rewrite padding_eq_mod_8, H11.
      reflexivity.
Qed. *)
Admitted.

Fixpoint aligned_Pseudo_checksum
           (srcAddr : ByteBuffer.t 4)
           (destAddr : ByteBuffer.t 4)
           (pktlength : word 16)
           id
         {sz}
         (v : t Core.char sz) (idx : nat)
  := match idx with
     | 0 =>
       weqb (InternetChecksum.ByteBuffer_checksum_bound (12 + (wordToNat pktlength))
                                                        ([wzero 8; id] ++ srcAddr ++ destAddr ++
                                                                       (splitLength pktlength) ++ v ))%vector
            (wones 16)
     | S idx' =>
       match v with
       | Vector.cons _ _ v' => aligned_Pseudo_checksum srcAddr destAddr pktlength id v' idx'
       | _ => false
       end
     end.

Lemma aligned_Pseudo_checksum_OK_1
      (srcAddr : ByteBuffer.t 4)
      (destAddr : ByteBuffer.t 4)
      (pktlength : word 16)
      id
      measure
      {sz}
    : forall (v : t Core.char sz),
      weqb
        (InternetChecksum.add_bytes_into_checksum (wzero 8) id
       (onesComplement(to_list srcAddr ++ to_list destAddr ++ to_list (splitLength pktlength)
                               ++ (ByteString2ListOfChar (measure sz v) (build_aligned_ByteString v)))))
    WO~1~1~1~1~1~1~1~1~1~1~1~1~1~1~1~1
      = aligned_Pseudo_checksum srcAddr destAddr pktlength id v 0.
  Proof.
  Admitted.

  Lemma aligned_Pseudo_checksum_OK_2
      (srcAddr : ByteBuffer.t 4)
      (destAddr : ByteBuffer.t 4)
      (pktlength : word 16)
      id
      {sz}
    : forall (v : ByteBuffer.t (S sz)) (idx : nat),
      aligned_Pseudo_checksum srcAddr destAddr pktlength id v (S idx) =
      aligned_Pseudo_checksum srcAddr destAddr pktlength id (Vector.tl v) idx.
  Proof.
    intros v; pattern sz, v.
    apply Vector.caseS; reflexivity.
  Qed.

Lemma CorrectAlignedDecoderForUDPChecksumThenC {A}
      (srcAddr : Vector.t (word 8) 4)
      (destAddr : Vector.t (word 8) 4)
      (udpLength : word 16)
      protoCode
      predicate
      (format_A format_B : FormatM A ByteString)
      (len_format_A : A -> nat)
      (len_format_A_OK : forall a' b ctx ctx',
          computes_to (format_A a' ctx) (b, ctx')
          -> length_ByteString b = len_format_A a')
  : CorrectAlignedDecoderFor
      predicate
      (format_A ++ format_unused_word 16 ++ format_B)%format
    -> CorrectAlignedDecoderFor
         predicate
         (format_A ThenChecksum (Pseudo_Checksum_Valid srcAddr destAddr udpLength protoCode) OfSize 16 ThenCarryOn format_B).
Proof.
  intros H; destruct H as [ ? [ [? ?] [ ? ?] ] ]; simpl in *.
  eexists (fun sz v =>
             if weqb (pseudoHeader_checksum' srcAddr destAddr udpLength protoCode v) (wones 16)
             then x sz v
             else ThrowAlignedDecodeM v).
  admit.
Defined.