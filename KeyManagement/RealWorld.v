From Coq Require Import String Sumbool Morphisms.

Require Import MyPrelude Common Maps.

Set Implicit Arguments.

Definition key_identifier := nat.

Inductive key_usage :=
| Encryption
| Signing.

Lemma key_usage_eq_dec :
  forall u1 u2 : key_usage, { u1 = u2 } + { u1 <> u2 }.
  decide equality.
Defined.

Inductive key_type :=
| SymKey
| AsymKey.

Lemma key_type_eq_dec :
  forall kt1 kt2 : key_type, { kt1 = kt2 } + { kt1 <> kt2 }.
  decide equality.
Defined.

Record key :=
  MkCryptoKey { keyId    : key_identifier
              ; keyUsage : key_usage
              ; keyType  : key_type
              }.

Lemma key_eq_dec :
  forall k1 k2 : key, { k1 = k2 } + { k1 <> k2 }.
  decide equality; auto using Nat.eq_dec, key_usage_eq_dec, key_type_eq_dec.
Defined.

Definition key_permission : Set := key_identifier * bool.

Lemma key_permission_eq_dec :
  forall kp1 kp2 : key_permission, { kp1 = kp2 } + { kp1 <> kp2 }.
  decide equality; auto using Nat.eq_dec, Bool.bool_dec.
Defined.

Notation "x ==kk y" := (key_eq_dec x y) (right associativity, at level 75).
Notation "x ==ku y" := (key_usage_eq_dec x y) (right associativity, at level 75).
Notation "x ==kt y" := (key_type_eq_dec x y) (right associativity, at level 75).
Notation "x ==kp y" := (key_permission_eq_dec x y) (right associativity, at level 75).

Definition cipher_id := nat.

Inductive type : Set :=
| Nat
(* | Text *)
| Key
| CipherId
| Pair (t1 t2 : type)
.

Fixpoint typeDenote (t : type) : Set :=
  match t with
  | Nat => nat
  | Key => key_permission
  | CipherId => cipher_id
  | Pair t1 t2 => typeDenote t1 * typeDenote t2
  end.

Inductive message : type -> Type :=
(* This will eventually be a message Text, using nat for now *)
| Plaintext (txt : nat) : message Nat
| KeyMessage  (k : key_permission) : message Key

| MsgPair {t1 t2 : type} (msg1 : message t1) (msg2 : message t2) : message (Pair t1 t2)

| SignedCiphertext (k__sign k__enc : key_identifier) (msg_id : cipher_id) : message CipherId
| Signature {t} (msg : message t) (k : key_identifier) (sig : cipher_id) : message t
.

(* We need to handle non-deterministic message  -- external choice on ordering *)
Inductive msg_pat :=
| Accept
| Paired (pat1 pat2 : msg_pat)
| Signed (k : key_identifier)
| SignedEncrypted (k__sign k__enc : key_identifier)
.

Inductive cipher : Type :=
| SigCipher {t} (k_id : key_identifier) (msg : message t) : cipher
| SigEncCipher {t} (k__sign k__enc : key_identifier) (msg : message t) : cipher
.

Definition cipher_signing_key (c : cipher) :=
  match c with
  | SigCipher k _      => k
  | SigEncCipher k _ _ => k
  end.

Definition queued_messages := list (sigT message).
Definition keys            := NatMap.t key.
Definition key_perms       := NatMap.t bool.
Definition ciphers         := NatMap.t cipher.
Definition my_ciphers      := list cipher_id.

Inductive msg_accepted_by_pattern : forall {t : type}, msg_pat -> message t -> Prop :=
| MsgAccept : forall {t} (m : message t),
    msg_accepted_by_pattern Accept m
| BothPairsAccepted : forall {t1 t2} p1 p2 (m1 : message t1) (m2 : message t2),
      msg_accepted_by_pattern p1 m1
    -> msg_accepted_by_pattern p2 m2
    -> msg_accepted_by_pattern (Paired p1 p2) (MsgPair m1 m2)
| ProperlySigned : forall {t} c_id k (m : message t),
    msg_accepted_by_pattern (Signed k) (Signature m k c_id)
| ProperlyEncrypted : forall {t} c_id k__sign k__enc (m : message t),
    msg_accepted_by_pattern (SignedEncrypted k__sign k__enc) (SignedCiphertext k__sign k__enc c_id).

Ltac context_map_rewrites :=
  repeat
    match goal with
    | [ H : ?m $? ?k = _ |- context[?m $? ?k] ] => rewrite H
    | [ H : match ?matchee with _ => _ end $? _ = _
     ,  H1 : ?matchee = _ |- _] => rewrite H1 in H
    | [ H : match ?matchee with _ => _ end = _
     ,  H1 : ?matchee = _ |- _] => rewrite H1 in H
    end.

Hint Extern 1 (~ In _ _) => rewrite not_find_in_iff.

Section SafeMessages.
  Variable all_keys : keys.
  Variable honestk advk : key_perms.

  Inductive honest_key (k_id : key_identifier) : Prop :=
  | HonestKey :
        honestk $? k_id = Some true
      -> honest_key k_id.

  Definition honest_keyb (k_id : key_identifier) : bool :=
    match honestk $? k_id with
    | Some true => true
    | _ => false
    end.

  Hint Constructors honest_key.

  Lemma honest_key_honest_keyb :
    forall k,
      honest_key k <-> honest_keyb k = true.
  Proof.
    split; unfold honest_keyb; intros.
    - destruct H; context_map_rewrites; trivial.
    - cases (honestk $? k); subst; try discriminate.
      cases b; try discriminate; eauto.
  Qed.

  Lemma not_honest_key_honest_keyb :
    forall k,
      not (honest_key k) <-> honest_keyb k = false.
  Proof.
    split; unfold honest_keyb; intros.
    - cases (honestk $? k); trivial.
      cases b; trivial.
      assert (honest_key k) by eauto; contradiction.
    - unfold not; intro HK; destruct HK; context_map_rewrites; discriminate.
  Qed.

  Inductive msg_contains_only_honest_public_keys :  forall {t}, message t -> Prop :=
  | PlaintextHPK : forall txt,
      msg_contains_only_honest_public_keys (Plaintext txt)
  | KeyMessageHPK : forall kp,
        honestk $? fst kp = Some true
      -> snd kp = false
      -> msg_contains_only_honest_public_keys (KeyMessage kp)
  | MsgPairHPK : forall {t1 t2} (msg1 : message t1) (msg2 : message t2),
        msg_contains_only_honest_public_keys msg1
      -> msg_contains_only_honest_public_keys msg2
      -> msg_contains_only_honest_public_keys (MsgPair msg1 msg2)
  | HonestlyEncryptedHPK :
      forall c_id k__signid k__encid,
        honest_key k__encid
      -> msg_contains_only_honest_public_keys (SignedCiphertext k__signid k__encid c_id)
  | SignedPayloadHPK : forall {t} (msg : message t) k c_id,
        msg_contains_only_honest_public_keys msg
      -> msg_contains_only_honest_public_keys (Signature msg k c_id).

  Hint Constructors msg_contains_only_honest_public_keys.

  Definition msg_honestly_signed {t} (msg : message t) : bool :=
    match msg with
    (* | MsgPair msg1 msg2 => msg_honestly_signed msg1 && msg_honestly_signed msg2 *)
    | SignedCiphertext k__signid _ _ => honest_keyb k__signid
    | Signature _ k _ => honest_keyb k
    | _ => false
    end.

  Definition keys_mine (my_perms key_perms: key_perms) : Prop :=
    forall k_id kp,
      key_perms $? k_id = Some kp
    ->  my_perms $? k_id = Some kp
    \/ (my_perms $? k_id = Some true /\ kp = false).

  Definition cipher_honestly_signed (c : cipher) : bool :=
    match c with
    | SigCipher k_id _              => honest_keyb k_id
    | SigEncCipher k__signid k__encid _ => honest_keyb k__signid
    end.

  Definition ciphers_honestly_signed :=
    Forall_natmap (fun c => cipher_honestly_signed c = true).

  (* Definition message_queue_safe : queued_messages -> Prop := *)
  (*   Forall (fun m => match m with | existT _ _ msg => msg_honestly_signed msg = true end). *)

  Inductive msg_pattern_safe : msg_pat -> Prop :=
  (* | PairedPatternSafe : forall p1 p2, *)
  (*       msg_pattern_safe p1 *)
  (*     -> msg_pattern_safe p2 *)
  (*     -> msg_pattern_safe (Paired p1 p2) *)
  | HonestlySignedSafe : forall k,
        honest_key k
      -> msg_pattern_safe (Signed k)
  | HonestlySignedEncryptedSafe : forall k__sign k__enc,
        honest_key k__sign
      -> msg_pattern_safe (SignedEncrypted k__sign k__enc).

End SafeMessages.

Hint Constructors honest_key
     msg_pattern_safe.

Lemma cipher_honestly_signed_proper :
  Proper (eq ==> eq ==> eq) (fun _ : NatMap.key => cipher_honestly_signed).
Proof.
  unfold Proper, respectful; intros; subst; eauto.
Qed.

Hint Resolve cipher_honestly_signed_proper.

Inductive user_cmd : Type -> Type :=
(* Plumbing *)
| Return {A : Type} (res : A) : user_cmd A
| Bind {A A' : Type} (cmd1 : user_cmd A') (cmd2 : A' -> user_cmd A) : user_cmd A

| Gen : user_cmd nat

(* Messaging *)
| Send {t} (uid : user_id) (msg : message t) : user_cmd unit
| Recv {t} (pat : msg_pat) : user_cmd (message t)

(* Crypto!! *)
| SignEncrypt {t} (k__sign k__enc : key_identifier) (msg : message t) : user_cmd (message CipherId)
| Decrypt {t} (msg : message CipherId) : user_cmd (message t)

| Sign    {t} (k : key_identifier) (msg : message t) : user_cmd (message t)
| Verify  {t} (k : key_identifier) (msg : message t) : user_cmd bool

| GenerateSymKey  (usage : key_usage) : user_cmd key_permission
| GenerateAsymKey (usage : key_usage) : user_cmd key_permission

(* Allow administrator to make some global change to the universe -- revoke keys, etc. *)
(* This may be a universe level step -- Administrator forces all users to stop *)
(* | Barrier {result : Set} : user_cmd result *)
.

Module RealWorldNotations.
  Notation "x <- c1 ; c2" := (Bind c1 (fun x => c2)) (right associativity, at level 75) : realworld_scope.
  Delimit Scope realworld_scope with realworld.
End RealWorldNotations.
Import  RealWorldNotations.
Open Scope realworld_scope.

Record user_data (A : Type) :=
  mkUserData {
      key_heap : key_perms
    ; protocol : user_cmd A
    ; msg_heap : queued_messages
    ; c_heap   : my_ciphers
    }.

Definition honest_users A := user_list (user_data A).

Record universe (A B : Type) :=
  mkUniverse {
      users       : honest_users A
    ; adversary   : user_data B
    ; all_ciphers : ciphers
    ; all_keys    : keys
    }.

Definition greatest_permission (kp1 kp2 : bool) : bool :=
  kp1 || kp2.

Definition add_key_perm (k : key_identifier)(kp : bool) (perms : key_perms) : key_perms :=
    match perms $? k with
    | None     => perms $+ (k, kp)
    | Some kp' => perms $+ (k, greatest_permission kp kp')
    end.

Lemma greatest_permission_refl :
  forall k,
    greatest_permission k k = k.
Proof.
  unfold greatest_permission; auto using orb_diag.
Qed.

Lemma greatest_permission_symm :
  forall kp1 kp2,
    greatest_permission kp1 kp2 = greatest_permission kp2 kp1.
Proof.
  unfold greatest_permission; auto using orb_comm.
Qed.

Definition merge_perms (ks ks' : key_perms) : key_perms :=
  fold add_key_perm ks ks'.

Notation "m1 $k++ m2" := (merge_perms m2 m1) (at level 50, left associativity).

Lemma add_key_perm_proper :
  Proper (eq  ==>  eq  ==>  eq  ==>  eq ) add_key_perm.
Proof.
  unfold Proper, respectful; intros; subst; trivial.
Qed.

Lemma add_key_perm_proper_Equal :
  Proper (eq  ==>  eq  ==>  Equal  ==>  Equal ) add_key_perm.
Proof.
  unfold Proper, respectful; intros; Equal_eq;
    unfold Equal; intros; trivial.
Qed.

Lemma add_key_perm_transpose :
  transpose_neqkey eq add_key_perm.
Proof.
  unfold transpose_neqkey, add_key_perm; intros.
  apply map_eq_Equal; unfold Equal; intros;
    cases (a $? k); cases (a $? k');
      repeat (context_map_rewrites; clean_map_lookups);
      cases (y ==n k); cases (y ==n k'); subst; clean_map_lookups; trivial; contradiction.
Qed.

Lemma add_key_perm_transpose_Equal :
  transpose_neqkey Equal add_key_perm.
Proof.
  unfold transpose_neqkey, add_key_perm; intros.
  unfold Equal; intros;
    cases (a $? k); cases (a $? k');
      repeat (context_map_rewrites; clean_map_lookups);
      cases (y ==n k); cases (y ==n k'); subst; clean_map_lookups; trivial; contradiction.
Qed.

Hint Resolve
     add_key_perm_proper       add_key_perm_transpose
     add_key_perm_proper_Equal add_key_perm_transpose_Equal.


Definition findUserKeys {A} (us : user_list (user_data A)) : key_perms :=
  fold (fun u_id u ks => ks $k++ u.(key_heap)) us $0.

Definition addUserKeys {A} (ks : key_perms) (u : user_data A) : user_data A :=
  {| key_heap := u.(key_heap) $k++ ks
   ; protocol := u.(protocol)
   ; msg_heap := u.(msg_heap)
   ; c_heap   := u.(c_heap) |}.

Definition addUsersKeys {A} (us : user_list (user_data A)) (ks : key_perms) : user_list (user_data A) :=
  map (addUserKeys ks) us.


Lemma Forall_app_sym :
  forall {A} (P : A -> Prop) (l1 l2 : list A),
    Forall P (l1 ++ l2) <-> Forall P (l2 ++ l1).
Proof.
  split; intros;
    rewrite Forall_forall in *; intros;
      eapply H;
      apply in_or_app; apply in_app_or in H0; intuition idtac.
Qed.

Lemma Forall_app :
  forall {A} (P : A -> Prop) (l : list A) a,
    Forall P (l ++ [a]) <-> Forall P (a :: l).
Proof.
  intros.
  rewrite Forall_app_sym; simpl; split; trivial.
Qed.

Lemma Forall_dup :
  forall {A} (P : A -> Prop) (l : list A) a,
    Forall P (a :: a :: l) <-> Forall P (a :: l).
Proof.
  split; intros;
    rewrite Forall_forall in *; intros;
      eapply H;
      apply in_inv in H0; split_ors; subst; simpl; eauto.
Qed.

(* Definition message_queue_ok (msgs : queued_messages) (honestk : key_perms) := *)
(*   Forall (fun sigm => match sigm with *)
(*                    | (existT _ _ m) => *)
(*                      msg_honestly_signed honestk m = true -> msg_contains_only_honest_public_keys honestk m *)
(*                    end) msgs. *)

Fixpoint findKeys {t} (msg : message t) : key_perms :=
  match msg with
  | Plaintext _            => $0
  | KeyMessage k           => $0 $+ (fst k, snd k)
  | MsgPair msg1 msg2      => findKeys msg1 $k++ findKeys msg2
  | SignedCiphertext _ _ _ => $0
  | Signature m _ _        => findKeys m
  end.

Fixpoint findCiphers {t} (msg : message t) : my_ciphers :=
  match msg with
  | Plaintext _            => []
  | KeyMessage _           => []
  | MsgPair msg1 msg2      => [] (* findCiphers msg1 ++ findCiphers msg2 *)
  | SignedCiphertext _ _ c => [c]
  | Signature m _ c        => c :: findCiphers m
  end.

Fixpoint findMsgCiphers {t} (msg : message t) : queued_messages :=
  match msg with
  | Plaintext _            => []
  | KeyMessage _           => []
  | MsgPair msg1 msg2      => [] (* findFullCiphers msg1 ++ findFullCiphers msg2 *)
  | SignedCiphertext _ _ _ => [existT _ _ msg]
  | Signature m k c        => (existT _ _ msg) :: findMsgCiphers m
  end.

Definition user_keys {A} (usrs : honest_users A) (u_id : user_id) : option key_perms :=
  match usrs $? u_id with
  | Some u_d => Some u_d.(key_heap)
  | None     => None
  end.

Definition user_queue {A} (usrs : honest_users A) (u_id : user_id) : option queued_messages :=
  match usrs $? u_id with
  | Some u_d => Some u_d.(msg_heap)
  | None     => None
  end.

Definition user_cipher_queue {A} (usrs : honest_users A) (u_id : user_id) : option my_ciphers :=
  match usrs $? u_id with
  | Some u_d => Some u_d.(c_heap)
  | None     => None
  end.

Section KeyMergeTheorems.
  Variable all_keys : keys.
  Variable honestk advk : key_perms.

  Hint Resolve empty_Empty.

  Ltac progress_fold_add1 :=
    match goal with
    | [ H : fold add_key_perm (_ $+ (_,_)) _ $? _ = _ |- _ ] => rewrite fold_add in H
    | [ H : _ $k++ (_ $+ (_,_)) $? _ = _ |- _ ] => unfold merge_perms in H; rewrite fold_add in H
    | [ |- context[ fold add_key_perm (_ $+ (_,_)) _ ] ] => rewrite fold_add
    | [ |- context[ _ $k++ (_ $+ (_,_))] ] => unfold merge_perms; rewrite fold_add
    end.

  Lemma merge_perms_notation :
    forall ks1 ks2,
      fold add_key_perm ks2 ks1 = ks1 $k++ ks2.
    unfold merge_perms; trivial.
  Qed.

  Lemma merge_perms_left_identity :
    forall ks,
      $0 $k++ ks = ks.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; auto.

    progress_fold_add1; auto.
    rewrite merge_perms_notation.
    unfold add_key_perm; auto.
    rewrite IHks; auto.
    case_eq (ks $? x); intros; subst; clean_map_lookups; trivial.
  Qed.

  Lemma merge_keys_right_identity :
    forall ks,
      ks $k++ $0 = ks.
  Proof.
    unfold merge_perms; intros; rewrite fold_Empty; eauto.
  Qed.

  Hint Rewrite merge_keys_right_identity merge_perms_left_identity.

  Lemma merge_perms_adds_no_new_perms :
    forall ks2 k ks1,
        ks1 $? k = None
      -> ks2 $? k = None
      -> (ks1 $k++ ks2) $? k = None.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; auto.
    progress_fold_add1; auto.
    rewrite merge_perms_notation.
    unfold add_key_perm.
    case (x ==n k); intros; subst; clean_map_lookups.
    cases (ks1 $k++ ks2 $? x); clean_map_lookups; auto.
  Qed.

  Hint Resolve merge_perms_adds_no_new_perms.

  Lemma merge_perms_came_from_somewhere1 :
    forall ks2 ks1 k v,
        ks1 $k++ ks2 $? k = Some v
      -> ks2 $? k = None
      -> ks1 $? k = Some v.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; auto.
    case (x ==n k); intros; subst; clean_map_lookups.
    progress_fold_add1; auto.
    rewrite merge_perms_notation in *.
    unfold add_key_perm in *.
    cases (ks1 $k++ ks2 $? x); clean_map_lookups; auto.
  Qed.

  Lemma merge_perms_came_from_somewhere2 :
    forall ks2 ks1 k v,
        ks1 $k++ ks2 $? k = Some v
      -> ks1 $? k = None
      -> ks2 $? k = Some v.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; eauto.
    - rewrite merge_keys_right_identity in H; clean_map_lookups.
    - case (k ==n x); intros; subst; clean_map_lookups;
        progress_fold_add1; auto;
          rewrite merge_perms_notation in *;
          unfold add_key_perm in *.
      + assert (ks1 $k++ ks2 $? x = None) by eauto.
      context_map_rewrites; clean_map_lookups; auto.
      + cases (ks1 $k++ ks2 $? x); clean_map_lookups; eauto.
  Qed.

  Hint Resolve merge_perms_came_from_somewhere1 merge_perms_came_from_somewhere2.

  Lemma merge_perms_adds_ks1 :
    forall ks2 ks1 k v ks,
        ks1 $? k = Some v
      -> ks2 $? k = None
      -> ks = ks1 $k++ ks2
      -> ks $? k = Some v.
  Proof.
    unfold merge_perms.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; eauto.
    - subst; rewrite fold_Empty; eauto.
    - case (x ==n k); intros; subst; clean_map_lookups; eauto.
      progress_fold_add1; auto.
      rewrite merge_perms_notation.
      unfold add_key_perm.
      cases ( ks1 $k++ ks2 $? x ); clean_map_lookups; eauto.
  Qed.

  Lemma merge_perms_adds_ks2 :
    forall ks2 ks1 k v ks,
        ks1 $? k = None
      -> ks2 $? k = Some v
      -> ks = ks1 $k++ ks2
      -> ks $? k = Some v.
  Proof.
    unfold merge_perms.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; eauto.
    subst; progress_fold_add1; auto.
    rewrite merge_perms_notation.
    unfold add_key_perm.
    cases (k ==n x); subst; clean_map_lookups.
    + assert (ks1 $k++ ks2 $? x = None) by eauto.
      context_map_rewrites; clean_map_lookups; auto.
    + cases ( ks1 $k++ ks2 $? x); clean_map_lookups; eauto.
  Qed.

  Hint Resolve merge_perms_adds_ks1 merge_perms_adds_ks2.

  Lemma merge_perms_chooses_greatest :
    forall ks2 ks1 k k' kp kp',
        ks1 $? k = Some kp
      -> ks2 $? k' = Some kp'
      -> k = k'
      -> (ks1 $k++ ks2) $? k = Some (greatest_permission kp kp').
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; eauto.
    progress_fold_add1; auto.
    rewrite merge_perms_notation.
    unfold add_key_perm.
    subst.
    cases (x ==n k'); subst; clean_map_lookups.
    + assert (ks1 $k++ ks2 $? k' = Some kp) by eauto.
      context_map_rewrites; clean_map_lookups; auto.
      rewrite greatest_permission_symm; trivial.
    + cases (ks1 $k++ ks2 $? x); subst; clean_map_lookups; eauto.
  Qed.

  Hint Resolve merge_perms_chooses_greatest.

  Lemma merge_perms_split :
    forall ks2 ks1 k kp,
      ks1 $k++ ks2 $? k = Some kp
      -> ks1 $? k = Some kp
      \/ ks2 $? k = Some kp.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; auto.
    cases (x ==n k); subst; clean_map_lookups; auto;
      progress_fold_add1; auto;
        rewrite merge_perms_notation in *;
        unfold add_key_perm in *.

    + subst. clean_map_lookups.
      cases (ks1 $k++ ks2 $? k); clean_map_lookups; auto.
      apply merge_perms_came_from_somewhere1 in Heq; auto.
      unfold greatest_permission; cases e; cases b; simpl; auto.

    + cases (ks1 $k++ ks2 $? x); clean_map_lookups; auto.
  Qed.

  Lemma merge_perms_no_disappear_perms :
    forall ks2 k ks1,
      ks1 $k++ ks2 $? k = None
    -> ks1 $? k = None
    /\ ks2 $? k = None.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; auto.
    progress_fold_add1; auto.
    rewrite merge_perms_notation in *; clean_map_lookups.
    unfold add_key_perm in *.
    cases (ks1 $k++ ks2 $? x);
      cases (x ==n k); subst; clean_map_lookups; auto.
  Qed.

  Lemma merge_keys_neq_add_ok :
    forall ks2 ks1 k k' kp,
      k <> k'
      -> ks1 $+ (k,kp) $k++ ks2 $? k' = ks1 $k++ ks2 $? k'.
  Proof.
    intros.
    cases (ks1 $? k'); cases (ks2 $? k').
    - erewrite !merge_perms_chooses_greatest; clean_map_lookups; eauto.
    - erewrite !merge_perms_adds_ks1; auto; clean_map_lookups; eauto.
    - erewrite !merge_perms_adds_ks2; auto; clean_map_lookups; eauto.
    - erewrite !merge_perms_adds_no_new_perms; clean_map_lookups; auto.
  Qed.

  Hint Resolve merge_keys_neq_add_ok.

  Lemma merge_keys_pull1 :
    forall ks2 ks1 k kp kp' gkp,
        ks2 $? k = Some kp'
      -> gkp = greatest_permission kp kp'
      -> (ks1 $+ (k, kp)) $k++ ks2 = ks1 $k++ ks2 $+ (k, gkp).
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; eauto.
    apply map_eq_Equal; unfold Equal; intros.
    cases (k ==n x); cases (k ==n y); cases (x ==n y); subst; clean_map_lookups; try contradiction.
    - eapply merge_perms_chooses_greatest; auto; clean_map_lookups; trivial.
    - unfold merge_perms at 1; rewrite fold_add; auto; rewrite merge_perms_notation; unfold add_key_perm.
      assert (ks1 $+ (x, kp) $k++ ks2 $? x = Some kp) by (eapply merge_perms_adds_ks1; eauto; clean_map_lookups; trivial).
      context_map_rewrites; clean_map_lookups.
      unfold merge_perms at 2; rewrite fold_add; auto; rewrite merge_perms_notation with (ks1:=ks1); unfold add_key_perm.
      cases (ks1 $k++ ks2 $? x); subst; clean_map_lookups; eauto.
    - progress_fold_add1; auto.
      rewrite merge_perms_notation; unfold add_key_perm.
      cases (ks1 $+ (y, kp) $k++ ks2 $? x); clean_map_lookups; auto;
        erewrite merge_perms_chooses_greatest; auto; clean_map_lookups; eauto.
    - unfold merge_perms; rewrite !fold_add; auto.
      rewrite merge_perms_notation. rewrite merge_perms_notation with (ks1:=ks1).
      unfold add_key_perm.
      cases (ks1 $k++ ks2 $? y); eauto.
      + assert (ks1 $? y = Some b) by eauto.
        assert (ks1 $+ (k, kp) $k++ ks2 $? y = Some b). eapply merge_perms_adds_ks1; auto. clean_map_lookups; auto. auto.
        context_map_rewrites; clean_map_lookups; trivial.
      + eapply merge_perms_no_disappear_perms in Heq; auto; split_ands.
        assert (ks1 $+ (k, kp) $k++ ks2 $? y = None) by (apply merge_perms_adds_no_new_perms; clean_map_lookups; auto).
        context_map_rewrites; clean_map_lookups; auto.
    - unfold merge_perms; rewrite !fold_add; auto.
      rewrite merge_perms_notation. rewrite merge_perms_notation with (ks1:=ks1).
      unfold add_key_perm.
      cases (ks1 $k++ ks2 $? x); clean_map_lookups.
      + apply merge_perms_came_from_somewhere1 in Heq; eauto.
        assert (ks1 $+ (k, kp) $k++ ks2 $? x = Some b). eapply merge_perms_adds_ks1; auto. clean_map_lookups; auto. auto.
        context_map_rewrites; clean_map_lookups; auto.
      + eapply merge_perms_no_disappear_perms in Heq; auto; split_ands.
        assert (ks1 $+ (k, kp) $k++ ks2 $? x = None) by (apply merge_perms_adds_no_new_perms; clean_map_lookups; auto).
        context_map_rewrites; clean_map_lookups; auto.
  Qed.

  Lemma merge_keys_pull2 :
    forall ks2 ks1 k kp gkp,
        ks2 $? k = None
      -> gkp = kp
      -> (ks1 $+ (k, kp)) $k++ ks2 = ks1 $k++ ks2 $+ (k, gkp).
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; autorewrite with core; subst; auto.
    cases (x ==n k); subst; clean_map_lookups.
    unfold merge_perms; rewrite !fold_add; auto.
    rewrite merge_perms_notation. rewrite merge_perms_notation with (ks1:=ks1).
    unfold add_key_perm.
    cases (ks1 $k++ ks2 $? x).
    - apply merge_perms_came_from_somewhere1 in Heq; auto.
      assert (ks1 $+ (k, kp) $k++ ks2 $? x = Some b) by (eapply merge_perms_adds_ks1; trivial; clean_map_lookups; auto).
      context_map_rewrites; clean_map_lookups; auto.
      erewrite IHks2; auto.
      apply map_eq_Equal; unfold Equal; intros.
      cases (y ==n x); cases (y ==n k); subst; clean_map_lookups; auto; contradiction.
    - apply merge_perms_no_disappear_perms in Heq; auto; split_ands.
      assert (ks1 $+ (k, kp) $k++ ks2 $? x = None) by (apply merge_perms_adds_no_new_perms; clean_map_lookups; auto).
      context_map_rewrites.
      apply map_eq_Equal; unfold Equal; intros.
      erewrite IHks2; auto.
      cases (y ==n x); cases (y ==n k); subst; clean_map_lookups; auto; contradiction.
  Qed.

  Lemma merge_perms_sym :
    forall ks2 ks1,
      ks1 $k++ ks2 = ks2 $k++ ks1.
  Proof.
    induction ks2 using P.map_induction_bis; intros; Equal_eq; eauto.
    - rewrite merge_keys_right_identity, merge_perms_left_identity; trivial.
    - unfold merge_perms at 1; rewrite fold_add; auto.
      rewrite merge_perms_notation.
      unfold add_key_perm; simpl.

      cases (ks1 $k++ ks2 $? x); subst; clean_map_lookups.
      + apply merge_perms_came_from_somewhere1 in Heq; auto.
        erewrite merge_keys_pull1; eauto; rewrite IHks2; auto.
      + apply merge_perms_no_disappear_perms in Heq; auto; split_ands.
        erewrite merge_keys_pull2; eauto; rewrite IHks2; auto.
  Qed.

  Lemma merge_perms_refl :
    forall ks,
      ks $k++ ks = ks.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; auto.
    progress_fold_add1; auto.
    rewrite merge_perms_notation.
    unfold add_key_perm.
    erewrite merge_keys_pull2; clean_map_lookups; auto.
    rewrite map_add_eq, IHks; rewrite greatest_permission_refl; trivial.
  Qed.

  Lemma merge_perms_assoc :
    forall ks3 ks1 ks2,
      ks1 $k++ ks2 $k++ ks3 = ks1 $k++ (ks2 $k++ ks3).
  Proof.
    induction ks3 using P.map_induction_bis; intros; Equal_eq; auto.
    unfold merge_perms at 1.
    unfold merge_perms at 3.
    rewrite !fold_add; auto.
    rewrite merge_perms_notation.
    rewrite merge_perms_notation with (ks1:=ks2).
    unfold add_key_perm.

    cases (ks2 $k++ ks3 $? x).
    - cases (ks1 $k++ ks2 $k++ ks3 $? x);
        subst; rewrite IHks3 in Heq0; clean_map_lookups; eauto.
      + cases (ks1 $? x).
        * assert (ks1 $k++ (ks2 $k++ ks3) $? x = Some (greatest_permission b1 b)) by eauto.
          clean_map_lookups.
          apply map_eq_Equal; unfold Equal; intros.
          cases (y ==n x); subst; clean_map_lookups.
          ** assert (ks1 $k++ (ks2 $k++ ks3 $+ (x, greatest_permission e b)) $? x = Some (greatest_permission b1 (greatest_permission e b)))
              by (eapply merge_perms_chooses_greatest; auto; clean_map_lookups; auto).
             context_map_rewrites; unfold greatest_permission.
             rewrite !orb_assoc, orb_comm with (b1:=e); trivial.
          ** symmetry; rewrite merge_perms_sym.
             rewrite merge_keys_neq_add_ok, merge_perms_sym, <- IHks3; auto; trivial.
        * assert (ks1 $k++ (ks2 $k++ ks3) $? x = Some b) by eauto; clean_map_lookups.
          apply map_eq_Equal; unfold Equal; intros.
          cases (y ==n x); subst; clean_map_lookups.
          ** assert (ks1 $k++ (ks2 $k++ ks3 $+ (x, greatest_permission e b)) $? x = Some (greatest_permission e b))
              by (eapply merge_perms_adds_ks2; auto; clean_map_lookups; auto).
             context_map_rewrites; eauto.
          ** symmetry; rewrite merge_perms_sym.
             rewrite merge_keys_neq_add_ok, merge_perms_sym, <- IHks3; auto; trivial.

      + apply merge_perms_no_disappear_perms in Heq0; auto; split_ands; contra_map_lookup.

    - unfold merge_perms at 7.
      rewrite fold_add; auto.
      unfold add_key_perm at 1. rewrite merge_perms_notation with (ks2:=ks2 $k++ ks3).
      rewrite IHks3; trivial.
  Qed.

  Lemma findUserKeys_foldfn_proper :
    forall {A},
      Proper (eq ==> eq ==> eq ==> eq) (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold Proper, respectful; intros; subst; trivial.
  Qed.

  Lemma findUserKeys_foldfn_proper_Equal :
    forall {A},
      Proper (eq ==> eq ==> Equal ==> Equal) (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.

    unfold Proper, respectful; intros; subst; Equal_eq; unfold Equal; intros; trivial.
  Qed.

  Lemma findUserKeys_foldfn_transpose :
    forall {A},
      transpose_neqkey eq (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold transpose_neqkey; intros.
    rewrite !merge_perms_assoc,merge_perms_sym with (ks1:=key_heap e'); trivial.
  Qed.

  Lemma findUserKeys_foldfn_transpose_Equal :
    forall {A},
      transpose_neqkey Equal (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold transpose_neqkey; intros; unfold Equal; intros.
    rewrite !merge_perms_assoc,merge_perms_sym with (ks1:=key_heap e'); trivial.
  Qed.

  Hint Resolve findUserKeys_foldfn_proper findUserKeys_foldfn_transpose
       findUserKeys_foldfn_proper_Equal findUserKeys_foldfn_transpose_Equal.

  Lemma findUserKeys_notation :
    forall {A} (usrs : honest_users A),
      fold (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u) usrs $0 = findUserKeys usrs.
    unfold findUserKeys; trivial.
  Qed.

  Lemma findUserKeys_readd_user_same_keys_idempotent :
    forall {A} (usrs : honest_users A) u_id u_d proto msgs mycs,
      usrs $? u_id = Some u_d
      -> findUserKeys usrs = findUserKeys (usrs $+ (u_id, {| key_heap := key_heap u_d
                                                          ; protocol := proto
                                                          ; msg_heap := msgs
                                                          ; c_heap   := mycs |} )).
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto.

    cases (x ==n u_id); subst; clean_map_lookups.
    - rewrite map_add_eq.
      unfold findUserKeys.
      rewrite !fold_add; auto.
    - rewrite map_ne_swap; auto.
      unfold findUserKeys.
      rewrite fold_add; auto.
      rewrite fold_add; auto; clean_map_lookups.
      rewrite !findUserKeys_notation.
      rewrite IHusrs at 1; auto.
      rewrite not_find_in_iff; clean_map_lookups; trivial.
  Qed.

  Lemma findUserKeys_readd_user_same_keys_idempotent' :
    forall {A} (usrs : honest_users A) u_id u_d proto msgs ks mycs,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> findUserKeys (usrs $+ (u_id, {| key_heap := ks
                                      ; protocol := proto
                                      ; msg_heap := msgs
                                      ; c_heap   := mycs |})) = findUserKeys usrs.
  Proof.
    intros; subst; symmetry; eapply findUserKeys_readd_user_same_keys_idempotent; auto.
  Qed.

  Lemma findUserKeys_readd_user_addnl_keys :
    forall {A} (usrs : honest_users A) u_id u_d proto msgs ks ks' mycs,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> findUserKeys (usrs $+ (u_id, {| key_heap := ks $k++ ks'
                                      ; protocol := proto
                                      ; msg_heap := msgs
                                      ; c_heap   := mycs |})) = findUserKeys usrs $k++ ks'.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups; try rewrite map_add_eq.
    - unfold findUserKeys. rewrite !fold_add; auto.
      rewrite findUserKeys_notation; simpl.
      rewrite merge_perms_assoc; trivial.
    - rewrite map_ne_swap; auto.
      unfold findUserKeys.
      rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      rewrite fold_add; auto.
      rewrite IHusrs; auto.
      rewrite findUserKeys_notation.
      rewrite !merge_perms_assoc, merge_perms_sym with (ks1:=ks'); trivial.
      rewrite not_find_in_iff; clean_map_lookups; auto.
  Qed.

  Lemma findUserKeys_has_key_of_user :
    forall {A} (usrs : honest_users A) u_id u_d ks k kp,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> ks $? k = Some kp
      -> findUserKeys usrs $? k <> None.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups.
    - unfold findUserKeys.
      rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      cases (findUserKeys usrs $? k); subst; unfold not; intros.
      + erewrite merge_perms_chooses_greatest in H; eauto; discriminate.
      + eapply merge_perms_no_disappear_perms in H; split_ands; contra_map_lookup.
    - unfold findUserKeys; rewrite fold_add; auto; rewrite findUserKeys_notation; unfold not; intros.
      cases (key_heap e $? k); subst; auto.
      + eapply merge_perms_no_disappear_perms in H0; split_ands; contra_map_lookup.
      + eapply merge_perms_no_disappear_perms in H0; split_ands. assert ( findUserKeys usrs $? k <> None ); eauto.
  Qed.

  Lemma findUserKeys_has_private_key_of_user :
    forall {A} (usrs : honest_users A) u_id u_d ks k,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> ks $? k = Some true
      -> findUserKeys usrs $? k = Some true.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups.
    - unfold findUserKeys.
      rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      cases (findUserKeys usrs $? k); subst.
      + erewrite merge_perms_chooses_greatest; eauto; unfold greatest_permission; rewrite orb_true_r; auto.
      + erewrite merge_perms_came_from_somewhere2; eauto.
    - unfold findUserKeys; rewrite fold_add; auto; rewrite findUserKeys_notation; eauto.
      cases (key_heap e $? k); subst; auto.
      + erewrite merge_perms_chooses_greatest; eauto; unfold greatest_permission; rewrite orb_true_l; auto.
      + erewrite merge_perms_came_from_somewhere1; eauto.
  Qed.

  Lemma findUserKeys_readd_user_same_key_heap_idempotent :
    forall {A} (usrs : honest_users A) u_id ks,
      user_keys usrs u_id = Some ks
      -> findUserKeys usrs $k++ ks = findUserKeys usrs.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; contra_map_lookup; auto.
    unfold user_keys in H.
    cases (x ==n u_id); subst.
    - rewrite add_eq_o in H; simpl in H; auto.
      unfold findUserKeys; rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      invert H.
      rewrite merge_perms_assoc; rewrite merge_perms_refl; trivial.
    - rewrite add_neq_o in H; auto.
      unfold findUserKeys; rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      cases (usrs $? u_id); subst; try discriminate; invert H.
      rewrite merge_perms_assoc. rewrite merge_perms_sym with (ks2:=key_heap u); rewrite <- merge_perms_assoc.
      rewrite IHusrs.
      trivial.
      unfold user_keys; context_map_rewrites; trivial.
  Qed.

  Lemma honest_key_after_new_keys :
    forall msgk k_id,
        honest_key honestk k_id
      -> honest_key (honestk $k++ msgk) k_id.
  Proof.
    invert 1; intros; econstructor; eauto.
    cases (msgk $? k_id); subst; eauto.
    erewrite merge_perms_chooses_greatest by eauto; eauto.
  Qed.

  Hint Resolve honest_key_after_new_keys.

  Lemma honest_keyb_after_new_keys :
    forall msgk k_id,
      honest_keyb honestk k_id = true
      -> honest_keyb (honestk $k++ msgk) k_id = true.
  Proof.
    intros; rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve honest_keyb_after_new_keys.

  Lemma not_honest_key_after_new_msg_keys :
    forall {t} (msg : message t) k,
      ~ honest_key honestk k
      -> (forall (k_id : NatMap.key) (kp : bool), findKeys msg $? k_id = Some kp -> kp = false)
      -> ~ honest_key (honestk $k++ findKeys msg) k.
  Proof.
    unfold not; invert 3; intros.
    cases (honestk $? k); cases (findKeys msg $? k); subst; eauto.
    - cases b; eauto.
      erewrite merge_perms_chooses_greatest in H2; unfold greatest_permission in *; eauto.
      rewrite orb_false_l in H2; invert H2.
      specialize (H0 _ _ Heq0); discriminate.
    - erewrite merge_perms_adds_ks2 in H2; eauto.
      invert H2.
      specialize (H0 _ _ Heq0); discriminate.
  Qed.

  Hint Resolve not_honest_key_after_new_msg_keys.

  (* Lemma message_honestly_signed_after_new_msg_keys : *)
  (*   forall {t} (msg : message t) msgk, *)
  (*     msg_honestly_signed honestk msg = true *)
  (*     -> msg_honestly_signed (honestk $k++ msgk) msg = true. *)
  (* Proof. *)
  (*   induction msg; intros; simpl in *; eauto. *)
  (*   rewrite andb_true_iff in *; split_ands; auto. *)
  (* Qed. *)

  Lemma message_honestly_signed_after_add_keys :
    forall {t} (msg : message t) ks,
      msg_honestly_signed honestk msg = true
      -> msg_honestly_signed (honestk $k++ ks) msg = true.
  Proof.
    intros.
    destruct msg; simpl in *; eauto.
  Qed.

  Lemma message_honestly_signed_after_remove_pub_keys :
    forall {t} (msg : message t) pubk,
      msg_honestly_signed (honestk $k++ pubk) msg = true
      -> (forall k kp, pubk $? k = Some kp -> kp = false)
      -> msg_honestly_signed honestk msg = true.
  Proof.
    intros.
    destruct msg; simpl in *; eauto;
      unfold honest_keyb in *.

    - cases (honestk $? k__sign); cases (pubk $? k__sign); subst.
      + erewrite merge_perms_chooses_greatest in H; unfold greatest_permission in *; simpl in *; eauto.
        specialize (H0 _ _ Heq0);
          cases b; subst; eauto.
      + erewrite merge_perms_adds_ks1 in H; eauto.
      + erewrite merge_perms_adds_ks2 in H; eauto.
        specialize (H0 _ _ Heq0); subst; discriminate.
      + rewrite merge_perms_adds_no_new_perms in H; auto.

    - cases (honestk $? k); cases (pubk $? k); subst.
      + erewrite merge_perms_chooses_greatest in H; unfold greatest_permission in *; simpl in *; eauto.
        specialize (H0 _ _ Heq0);
          cases b; subst; eauto.
      + erewrite merge_perms_adds_ks1 in H; eauto.
      + erewrite merge_perms_adds_ks2 in H; eauto.
        specialize (H0 _ _ Heq0); subst; discriminate.
      + rewrite merge_perms_adds_no_new_perms in H; auto.
  Qed.

  (* Lemma message_contains_only_honest_public_keys_after_new_keys : *)
  (*   forall {t} (msg : message t) msgk, *)
  (*     msg_contains_only_honest_public_keys honestk msg *)
  (*     -> msg_contains_only_honest_public_keys (honestk $k++ msgk) msg. *)
  (* Proof. *)
  (*   induction 1; econstructor; eauto. *)
  (*   cases (msgk $? fst kp); eauto. *)
  (*   erewrite merge_perms_chooses_greatest; eauto; unfold greatest_permission; *)
  (*     rewrite orb_true_l; trivial. *)
  (* Qed. *)

  (* Hint Resolve message_honestly_signed_after_new_msg_keys. *)

  (* Lemma message_queue_safe_after_new_message_keys : *)
  (*   forall {t} (msg : message t) msgs, *)
  (*     message_queue_safe honestk msgs *)
  (*     -> message_queue_safe (honestk $k++ findKeys msg) msgs. *)
  (* Proof. *)
  (*   unfold message_queue_safe; induction 1; intros; eauto. *)
  (*   econstructor; eauto. *)
  (*   destruct x; eauto. *)
  (* Qed. *)

  (* Lemma message_queue_safe_after_msg_keys : *)
  (*   forall msgk msgs, *)
  (*     message_queue_safe honestk msgs *)
  (*     -> message_queue_safe (honestk $k++ msgk) msgs. *)
  (* Proof. *)
  (*   unfold message_queue_safe; induction 1; eauto; intros; econstructor; auto. *)
  (*   destruct x; eauto. *)
  (* Qed. *)

  Lemma cipher_honestly_signed_after_msg_keys :
    forall msgk c,
      cipher_honestly_signed honestk c = true
      -> cipher_honestly_signed (honestk $k++ msgk) c = true.
  Proof.
    unfold cipher_honestly_signed; intros; cases c;
      rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve cipher_honestly_signed_after_msg_keys.

  Lemma ciphers_honestly_signed_after_msg_keys :
    forall msgk cs,
      ciphers_honestly_signed honestk cs
      -> ciphers_honestly_signed (honestk $k++ msgk) cs.
  Proof.
    induction 1; econstructor; eauto.
  Qed.

End KeyMergeTheorems.

Lemma safe_messages_have_only_honest_public_keys :
  forall {t} (msg : message t) honestk,
    msg_contains_only_honest_public_keys honestk msg
    -> forall k_id,
      findKeys msg $? k_id = None
      \/ (honestk $? k_id <> None /\ findKeys msg $? k_id = Some false).
Proof.
  induction 1; eauto; intros; subst.
  - destruct kp; simpl in *; subst.
    cases (k ==n k_id); subst; clean_map_lookups; auto.
    right; split; unfold not; intros; clean_map_lookups; auto.
  - specialize (IHmsg_contains_only_honest_public_keys1 k_id);
      specialize( IHmsg_contains_only_honest_public_keys2 k_id);
      simpl; split_ors; split_ands; eauto.

    + rewrite merge_perms_adds_no_new_perms; eauto.
    + erewrite merge_perms_adds_ks1; eauto.
    + erewrite merge_perms_adds_ks2; eauto.
    + erewrite merge_perms_chooses_greatest; eauto; simpl; auto.
Qed.

Lemma safe_messages_perm_merge_honestk_idempotent :
  forall {t} (msg : message t) honestk,
    msg_contains_only_honest_public_keys honestk msg
    -> honestk $k++ findKeys msg = honestk.
Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    apply safe_messages_have_only_honest_public_keys with (k_id := y) in H; split_ors; split_ands.
    - cases (honestk $? y); eauto.
      + erewrite merge_perms_adds_ks1; eauto.
      + rewrite merge_perms_adds_no_new_perms; auto.
    - cases (honestk $? y); try contradiction.
      erewrite merge_perms_chooses_greatest; eauto; unfold greatest_permission; rewrite orb_false_r; auto.
Qed.

Definition buildUniverse {A B}
           (usrs : honest_users A) (adv : user_data B) (cs : ciphers) (ks : keys)
           (u_id : user_id) (userData : user_data A) : universe A B :=
  {| users        := usrs $+ (u_id, userData)
   ; adversary    := adv
   ; all_ciphers  := cs
   ; all_keys     := ks
   |}.

Definition buildUniverseAdv {A B}
           (usrs : honest_users A) (cs : ciphers) (ks : keys)
           (userData : user_data B) : universe A B :=
  {| users        := usrs
   ; adversary    := userData
   ; all_ciphers  := cs
   ; all_keys     := ks
   |}.

Definition extractPlainText {t} (msg : message t) : option nat :=
  match msg with
  | Plaintext t => Some t
  | _           => None
  end.

Definition unSig {t} (msg : message t) : option (message t) :=
  match msg with
  | Signature m _ _ => Some m
  | _               => None
  end.

Inductive action : Type :=
| Input  t (msg : message t) (pat : msg_pat) (uks : key_perms)
| Output t (msg : message t)
.

Definition rlabel := @label action.

Definition action_adversary_safe (honestk : key_perms) (a : action) : Prop :=
  match a with
  | Input  msg pat _ => msg_pattern_safe honestk pat
                     (* /\ (forall k_id kp, findKeys msg $? k_id = Some kp -> kp = false) *)
  | Output msg       => msg_contains_only_honest_public_keys honestk msg
                     /\ msg_honestly_signed honestk msg = true
                       (* /\ (forall k_id kp, findKeys all_keys msg $? k_id = Some kp -> kp = false) *)
  end.

Definition data_step0 (A B C : Type) : Type :=
  honest_users A * user_data B * ciphers * keys * key_perms * queued_messages * my_ciphers * user_cmd C.

Definition build_data_step {A B C} (U : universe A B) (u_data : user_data C) : data_step0 A B C :=
  (U.(users), U.(adversary), U.(all_ciphers), U.(all_keys), u_data.(key_heap), u_data.(msg_heap), u_data.(c_heap), u_data.(protocol)).

Definition user_id_option (uid : user_id) : option user_id := Some uid.
Coercion user_id_option : user_id >-> option.

Inductive step_user : forall A B C, rlabel -> option user_id -> data_step0 A B C -> data_step0 A B C -> Prop :=

(* Plumbing *)
| StepBindRecur : forall {B r r'} (usrs usrs' : honest_users r') (adv adv' : user_data B)
                    lbl u_id cs cs' qmsgs qmsgs' gks gks' ks ks' mycs mycs'
                    (cmd1 cmd1' : user_cmd r) (cmd2 : r -> user_cmd r'),
      step_user lbl u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, cmd1) (usrs', adv', cs', gks', ks', qmsgs', mycs', cmd1')
    -> step_user lbl u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, Bind cmd1 cmd2) (usrs', adv', cs', gks', ks', qmsgs', mycs', Bind cmd1' cmd2)
| StepBindProceed : forall {B r r'} (usrs : honest_users r) (adv : user_data B) cs u_id gks ks qmsgs mycs (v : r') (cmd : r' -> user_cmd r),
    step_user Silent u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, Bind (Return v) cmd) (usrs, adv, cs, gks, ks, qmsgs, mycs, cmd v)

| StepGen : forall {A B} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks qmsgs mycs n,
    step_user Silent u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, Gen) (usrs, adv, cs, gks, ks, qmsgs, mycs, Return n)

(* Comms  *)
| StepRecv : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks ks' qmsgs qmsgs' mycs mycs'
               (msg : message t) msgs pat newkeys newcs,
      qmsgs = (existT _ _ msg) :: msgs (* we have a message waiting for us! *)
    -> qmsgs' = msgs
    -> findKeys msg = newkeys
    -> newcs = findCiphers msg
    -> ks' = ks $k++ newkeys
    -> mycs' = newcs ++ mycs
    -> msg_accepted_by_pattern pat msg
    -> step_user (Action (Input msg pat ks)) u_id
                (usrs, adv, cs, gks, ks , qmsgs , mycs,  Recv pat)
                (usrs, adv, cs, gks, ks', qmsgs', mycs', Return msg)

| StepRecvDrop : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks qmsgs qmsgs' mycs (msg : message t) pat msgs,
      qmsgs = (existT _ _ msg) :: msgs (* we have a message waiting for us! *)
    -> qmsgs' = msgs
    -> ~ msg_accepted_by_pattern pat msg
    -> step_user Silent u_id (* Error label ... *)
                (usrs, adv, cs, gks, ks, qmsgs , mycs, Recv pat)
                (usrs, adv, cs, gks, ks, qmsgs', mycs, @Recv t pat)

(* Augment attacker's keys with those available through messages sent,
 * including traversing through ciphers already known by attacker, etc.
 *)
| StepSend : forall {A B} {t} (usrs usrs' : honest_users A) (adv adv' : user_data B)
               cs (u_id : user_id) gks ks qmsgs mycs rec_u_id rec_u newkeys (msg : message t),
    findKeys msg = newkeys
    -> keys_mine ks newkeys
    -> adv' = addUserKeys newkeys adv (* TODO: also add ciphers to adv??? *)
    -> usrs $? rec_u_id = Some rec_u
    -> rec_u_id <> u_id
    -> usrs' = usrs $+ (rec_u_id, {| key_heap := rec_u.(key_heap)
                                  ; protocol := rec_u.(protocol)
                                  ; msg_heap := rec_u.(msg_heap) ++ [existT _ _ msg]
                                  ; c_heap   := rec_u.(c_heap) |})
    -> step_user (Action (Output msg)) u_id
                (usrs , adv , cs, gks, ks, qmsgs, mycs, Send rec_u_id msg)
                (usrs', adv', cs, gks, ks, qmsgs, mycs, Return tt)

(* Encryption / Decryption *)
| StepEncrypt : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs cs' u_id gks ks qmsgs mycs mycs'
                  (msg : message t) k__signid k__encid kp__enc kt__enc kt__sign c_id cipherMsg,
      gks $? k__encid  = Some (MkCryptoKey k__encid Encryption kt__enc)
    -> gks $? k__signid = Some (MkCryptoKey k__signid Signing kt__sign)
    -> ks $? k__encid   = Some kp__enc
    -> ks $? k__signid  = Some true
    -> ~ In c_id cs
    -> keys_mine ks (findKeys msg)
    -> incl (findCiphers msg) mycs
    -> cipherMsg = SigEncCipher k__signid k__encid msg
    -> cs' = cs $+ (c_id, cipherMsg)
    -> mycs' = c_id :: mycs
    -> step_user Silent u_id
                (usrs, adv, cs , gks, ks, qmsgs, mycs,  SignEncrypt k__signid k__encid msg)
                (usrs, adv, cs', gks, ks, qmsgs, mycs', Return (SignedCiphertext k__signid k__encid c_id))

| StepDecrypt : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks ks' qmsgs mycs mycs'
                  (msg : message t) k__signid kp__sign k__encid c_id newkeys kt__sign kt__enc newcs,
      cs $? c_id     = Some (SigEncCipher k__signid k__encid msg)
    -> gks $? k__encid  = Some (MkCryptoKey k__encid Encryption kt__enc)
    -> gks $? k__signid = Some (MkCryptoKey k__signid Signing kt__sign)
    -> ks  $? k__encid  = Some true
    -> ks  $? k__signid = Some kp__sign
    -> findKeys msg = newkeys
    -> newcs = findCiphers msg
    -> ks' = ks $k++ newkeys
    -> mycs' = newcs ++ mycs
    -> List.In c_id mycs
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks , qmsgs, mycs,  Decrypt (SignedCiphertext k__signid k__encid c_id))
                (usrs, adv, cs, gks, ks', qmsgs, mycs', Return msg)

(* Signing / Verification *)
| StepSign : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs cs' u_id gks ks qmsgs mycs mycs'
               (msg : message t) k_id kt c_id cipherMsg,
      gks $? k_id = Some (MkCryptoKey k_id Signing kt)
    -> ks  $? k_id = Some true
    -> ~ In c_id cs
    -> cipherMsg = SigCipher k_id msg
    -> cs' = cs $+ (c_id, cipherMsg)
    -> mycs' = c_id :: mycs
    -> step_user Silent u_id
                (usrs, adv, cs , gks, ks, qmsgs, mycs,  Sign k_id msg)
                (usrs, adv, cs', gks, ks, qmsgs, mycs', Return (Signature msg k_id c_id))

| StepVerify : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks qmsgs mycs
                 (msg : message t) k_id kp kt c_id,
      gks $? k_id = Some (MkCryptoKey k_id Signing kt)
    -> ks  $? k_id = Some kp
    -> cs $? c_id = Some (SigCipher k_id msg)
    -> List.In c_id mycs
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks, qmsgs, mycs, Verify k_id (Signature msg k_id c_id))
                (usrs, adv, cs, gks, ks, qmsgs, mycs, Return true)
.

(* Key creation *)
(* | StepGenerateSymKey: forall A cs ks qmsgs (usrDat : user_data A) usage k kid, *)
(*     ~(kid \in (dom ks)) *)
(*     -> k = SymKey (MkCryptoKey kid usage) *)
(*     -> step_user (cs, ks, qmsgs, usrDat, GenerateSymKey usage) *)
(*                 (cs, ks $+ (kid, k), qmsgs, updateUserKeyHeap [k] usrDat, Return k) *)
(* | StepGenerateAsymKey: forall {a : Set} cs ks qmsgs (usrDat : user_data a) usage k kid, *)
(*     ~(kid \in (dom ks)) *)
(*     -> k = AsymKey (MkCryptoKey kid usage) true *)
(*     -> step_user (cs, ks, qmsgs, usrDat, GenerateAsymKey usage) *)
(*                 (cs, ks $+ (kid, k), qmsgs, updateUserKeyHeap [k] usrDat, Return k) *)

(* | Barrier {result : Set} : user_cmd result. *)

Inductive step_universe {A B} : universe A B -> rlabel -> universe A B -> Prop :=
| StepUser : forall U U' (u_id : user_id) userData usrs adv cs gks ks qmsgs mycs lbl (cmd : user_cmd A),
    U.(users) $? u_id = Some userData
    -> step_user lbl u_id
                (build_data_step U userData)
                (usrs, adv, cs, gks, ks, qmsgs, mycs, cmd)
    -> U' = buildUniverse usrs adv cs gks u_id {| key_heap := ks
                                               ; msg_heap := qmsgs
                                               ; protocol := cmd
                                               ; c_heap   := mycs |}
    -> step_universe U lbl U'
| StepAdversary : forall U U' usrs adv cs gks ks qmsgs mycs lbl (cmd : user_cmd B),
    step_user lbl None
              (build_data_step U U.(adversary))
              (usrs, adv, cs, gks, ks, qmsgs, mycs, cmd)
    -> U' = buildUniverseAdv usrs cs gks {| key_heap := ks
                                         ; msg_heap := qmsgs
                                         ; protocol := cmd
                                         ; c_heap   := mycs |}
    -> step_universe U Silent U'
.
