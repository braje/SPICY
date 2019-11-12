From Coq Require Import String Sumbool Morphisms.

Require Import
        MyPrelude
        Common
        Maps
        Tactics
        Keys
        Messages.

Set Implicit Arguments.

Module RW_message <: GRANT_ACCESS.
  Definition access := key_permission.
End RW_message.

Module message := Messages(RW_message).
Import message.
Export message.

Definition cipher_id := nat.

Inductive crypto : type -> Type :=
| Content {t} (c : message t) : crypto t
| SignedCiphertext {t} (c_id : cipher_id) : crypto t
.

(* We need to handle non-deterministic message  -- external choice on ordering *)
Inductive msg_pat :=
| Accept
| Signed (k : key_identifier)
| SignedEncrypted (k__sign k__enc : key_identifier)
.

Definition msg_seq : Set := (option user_id) * nat.

Definition msg_seq_eq (s1 s2 : msg_seq) : {s1 = s2} + {s1 <> s2}.
  repeat (decide equality).
Defined.

Inductive cipher : Type :=
| SigCipher {t} (k__sign : key_identifier) (msg_to : user_id) (c_nonce : msg_seq) (msg : message t) : cipher
| SigEncCipher {t} (k__sign k__enc : key_identifier) (msg_to : user_id) (c_nonce : msg_seq) (msg : message t) : cipher
.

Definition cipher_signing_key (c : cipher) :=
  match c with
  | SigCipher k _ _ _      => k
  | SigEncCipher k _ _ _ _ => k
  end.

Definition cipher_to_user (c : cipher) :=
  match c with
  | SigCipher _ to _ _      => to
  | SigEncCipher _ _ to _ _ => to
  end.

Definition cipher_nonce (c : cipher) :=
  match c with
  | SigCipher _ _ n _      => n
  | SigEncCipher _ _ _ n _ => n
  end.

Definition queued_messages := list (sigT crypto).
Definition ciphers         := NatMap.t cipher.
Definition my_ciphers      := list cipher_id.
Definition recv_nonces     := list msg_seq.
Definition sent_nonces     := list msg_seq.

(* Definition recv_nonces     := NatMap.t nat. *)
(* Definition send_nonces     := NatMap.t (NatMap.t nat). *)

Inductive msg_accepted_by_pattern (cs : ciphers) (opt_uid_to : option user_id) : forall {t : type}, msg_pat -> crypto t -> Prop :=
| MsgAccept : forall {t} (m : crypto t),
    msg_accepted_by_pattern cs opt_uid_to Accept m
| ProperlySigned : forall {t} c_id k (m : message t) msg_to nonce,
    cs $? c_id = Some (@SigCipher t k msg_to nonce m)
    -> opt_uid_to = Some msg_to
    -> msg_accepted_by_pattern cs opt_uid_to (Signed k) (@SignedCiphertext t c_id)
| ProperlyEncrypted : forall {t} c_id k__sign k__enc (m : message t) msg_to nonce,
    cs $? c_id = Some (SigEncCipher k__sign k__enc msg_to nonce m)
    -> opt_uid_to = Some msg_to
    -> msg_accepted_by_pattern cs opt_uid_to (SignedEncrypted k__sign k__enc) (@SignedCiphertext t c_id).

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

  Lemma honest_keyb_true_findKeys :
    forall k,
      honest_keyb k = true
      -> honestk $? k = Some true.
  Proof.
    intros; rewrite <- honest_key_honest_keyb in H; invert H; eauto.
  Qed.

  Inductive content_only_honest_public_keys : forall {t}, message t -> Prop :=
  | ContentHPK : forall txt,
      content_only_honest_public_keys (message.Content txt)
  | AccessHPK : forall kp,
      honestk $? fst kp = Some true
      -> snd kp = false
      -> content_only_honest_public_keys (message.Permission kp)
  | PairHPK : forall t1 t2 (m1 : message t1) (m2 : message t2),
      content_only_honest_public_keys m1
      -> content_only_honest_public_keys m2
      -> content_only_honest_public_keys (message.MsgPair m1 m2).

  Inductive msg_contains_only_honest_public_keys (cs : ciphers) : forall {t}, crypto t -> Prop :=
  | PlaintextHPK : forall {t} (txt : message t),
      content_only_honest_public_keys txt
      -> msg_contains_only_honest_public_keys cs (Content txt)
  | HonestlyEncryptedHPK : forall t (m : message t) c_id msg_to nonce k__sign k__enc,
      cs $? c_id = Some (SigEncCipher k__sign k__enc msg_to nonce m)
      -> content_only_honest_public_keys m
      -> honest_key k__enc
      -> msg_contains_only_honest_public_keys cs (@SignedCiphertext t c_id)
  | SignedPayloadHPK : forall {t} (m : message t) c_id msg_to nonce k__sign,
      cs $? c_id = Some (SigCipher k__sign msg_to nonce m)
      -> content_only_honest_public_keys m
      -> msg_contains_only_honest_public_keys cs (@SignedCiphertext t c_id).

  Hint Constructors msg_contains_only_honest_public_keys.

  Definition msg_cipher_id {t} (msg : crypto t) : option cipher_id :=
    match msg with
    | SignedCiphertext c_id => Some c_id
    | _ => None
    end.

  Definition msg_signing_key {t} (cs : ciphers) (msg : crypto t) : option key_identifier :=
    match msg with
    | Content _ => None
    | SignedCiphertext c_id =>
      match cs $? c_id with
      | Some c => Some (cipher_signing_key c)
      | None   => None
      end
    end.

  Definition msg_destination_user {t} (cs : ciphers) (msg : crypto t) : option user_id :=
    match msg with
    | Content _ => None
    | SignedCiphertext c_id =>
      match cs $? c_id with
      | Some c => Some (cipher_to_user c)
      | None   => None
      end
    end.

  Definition msg_honestly_signed {t} (cs : ciphers) (msg : crypto t) : bool :=
    match msg_signing_key cs msg with
    | Some k => honest_keyb k
    | _ => false
    end.

  Definition msg_to_this_user {t} (cs : ciphers) (to_usr : option user_id) (msg : crypto t) : bool :=
    match msg_destination_user cs msg with
    | Some to_usr' => match to_usr with
                     | None => true
                     | Some to_hon_user => if to_usr' ==n to_hon_user then true else false
                     end
    | _ => false
    end.

  Definition msg_signed_addressed (cs : ciphers) (to_user_id : option user_id) {t} (msg : crypto t) :=
    msg_honestly_signed cs msg && msg_to_this_user cs to_user_id msg.

  Definition keys_mine (my_perms key_perms: key_perms) : Prop :=
    forall k_id kp,
      key_perms $? k_id = Some kp
    ->  my_perms $? k_id = Some kp
    \/ (my_perms $? k_id = Some true /\ kp = false).

  Definition cipher_honestly_signed (c : cipher) : bool :=
    match c with
    | SigCipher k_id _ _ _              => honest_keyb k_id
    | SigEncCipher k__signid k__encid _ _ _ => honest_keyb k__signid
    end.

  Definition ciphers_honestly_signed :=
    Forall_natmap (fun c => cipher_honestly_signed c = true).

  Inductive msg_pattern_safe : msg_pat -> Prop :=
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
| Send {t} (uid : user_id) (msg : crypto t) : user_cmd unit
| Recv {t} (pat : msg_pat) : user_cmd (crypto t)

(* Crypto!! *)
| SignEncrypt {t} (k__sign k__enc : key_identifier) (msg : message t) : user_cmd (crypto t)
| Decrypt {t} (c : crypto t) : user_cmd (message t)

| Sign    {t} (k : key_identifier) (msg : message t) : user_cmd (crypto t)
| Verify  {t} (k : key_identifier) (c : crypto t) : user_cmd (bool * message t)

| GenerateSymKey  (usage : key_usage) : user_cmd key_permission
| GenerateAsymKey (usage : key_usage) : user_cmd key_permission
.

Module RealWorldNotations.
  Notation "x <- c1 ; c2" := (Bind c1 (fun x => c2)) (right associativity, at level 75) : realworld_scope.
  Delimit Scope realworld_scope with realworld.
End RealWorldNotations.
Import  RealWorldNotations.
Open Scope realworld_scope.

Record user_data (A : Type) :=
  mkUserData {
      key_heap  : key_perms
    ; protocol  : user_cmd A
    ; msg_heap  : queued_messages
    ; c_heap    : my_ciphers
    ; from_nons : recv_nonces
    ; sent_nons : sent_nonces
    ; cur_nonce : nat
    }.

Definition honest_users A := user_list (user_data A).

Record simpl_universe (A : Type) :=
  mkSimplUniverse {
      s_users       : honest_users A
    ; s_all_ciphers : ciphers
    ; s_all_keys    : keys
    }.

Record universe (A B : Type) :=
  mkUniverse {
      users       : honest_users A
    ; adversary   : user_data B
    ; all_ciphers : ciphers
    ; all_keys    : keys
    }.

Definition peel_adv {A B} (U : universe A B) : simpl_universe A :=
   {| s_users       := U.(users)
    ; s_all_ciphers := U.(all_ciphers)
    ; s_all_keys    := U.(all_keys) |}.

Definition findUserKeys {A} (us : user_list (user_data A)) : key_perms :=
  fold (fun u_id u ks => ks $k++ u.(key_heap)) us $0.

Definition addUserKeys {A} (ks : key_perms) (u : user_data A) : user_data A :=
  {| key_heap  := u.(key_heap) $k++ ks
   ; protocol  := u.(protocol)
   ; msg_heap  := u.(msg_heap)
   ; c_heap    := u.(c_heap)
   ; from_nons := u.(from_nons)
   ; sent_nons := u.(sent_nons)
   ; cur_nonce := u.(cur_nonce)
  |}.

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

Fixpoint findKeysMessage {t} (msg : message t) : key_perms :=
  match msg with
  | message.Permission k => $0 $+ (fst k, snd k) 
  | message.Content _ => $0
  | message.MsgPair m1 m2 => findKeysMessage m1 $k++ findKeysMessage m2
  end.

Definition findKeysCrypto {t} (cs : ciphers) (msg : crypto t) : key_perms :=
  match msg with
  | Content  m          => findKeysMessage m
  | SignedCiphertext c_id  =>
    match cs $? c_id with
    | Some (SigCipher _ _ _ m) => findKeysMessage m
    | _ => $0
    end
  end.

Definition findCiphers {t} (msg : crypto t) : my_ciphers :=
  match msg with
  | Content _          => []
  | SignedCiphertext c => [c]
  end.

Definition findMsgCiphers {t} (msg : crypto t) : queued_messages :=
  match msg with
  | Content _          => []
  | SignedCiphertext _ => [existT _ _ msg]
  (* | Signature m c      => (existT _ _ msg) :: findMsgCiphers m *)
  end.

Definition msgCiphersSignedOk {t} (honestk : key_perms) (cs : ciphers) (msg : crypto t) :=
  Forall (fun sigm => match sigm with
                     (existT _ _ m) => msg_honestly_signed honestk cs m = true
                   end) (findMsgCiphers msg).

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

Section RealWorldLemmas.

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
    forall {A} (usrs : honest_users A) u_id u_d proto msgs mycs froms sents cur_n,
      usrs $? u_id = Some u_d
      -> findUserKeys usrs = findUserKeys (usrs $+ (u_id, {| key_heap  := key_heap u_d
                                                          ; protocol  := proto
                                                          ; msg_heap  := msgs
                                                          ; c_heap    := mycs
                                                          ; from_nons := froms
                                                          ; sent_nons := sents
                                                          ; cur_nonce := cur_n
                                                         |} )).
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
    forall {A} (usrs : honest_users A) u_id ks proto msgs mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := ks
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n |})) = findUserKeys usrs.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups.
    - rewrite map_add_eq.
      unfold findUserKeys.
      unfold user_keys in *; rewrite add_eq_o in H; invert H; auto.
      rewrite !fold_add; simpl; eauto.
    - rewrite map_ne_swap; auto.
      unfold findUserKeys.
      assert (user_keys usrs u_id = Some ks) by (unfold user_keys in H; rewrite add_neq_o in H; auto).
      rewrite fold_add; auto.
      rewrite !findUserKeys_notation.
      rewrite IHusrs; auto.
      unfold findUserKeys at 2.
      rewrite fold_add; auto.
      rewrite not_find_in_iff; clean_map_lookups; trivial.
  Qed.

  Lemma findUserKeys_readd_user_addnl_keys :
    forall {A} (usrs : honest_users A) u_id proto msgs ks ks' mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := ks $k++ ks'
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n |})) = findUserKeys usrs $k++ ks'.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups; try rewrite map_add_eq.
    - unfold findUserKeys. rewrite !fold_add; auto.
      rewrite findUserKeys_notation; simpl.
      unfold user_keys in H; rewrite add_eq_o in H; invert H; auto.
      rewrite merge_perms_assoc; trivial.
    - rewrite map_ne_swap; auto.
      unfold findUserKeys.
      assert (user_keys usrs u_id = Some ks) by (unfold user_keys in H; rewrite add_neq_o in H; auto).
      rewrite fold_add; auto.
      rewrite findUserKeys_notation.
      rewrite fold_add; auto.
      rewrite IHusrs; auto.
      rewrite findUserKeys_notation.
      rewrite !merge_perms_assoc, merge_perms_sym with (ks1:=ks'); trivial.
      rewrite not_find_in_iff; clean_map_lookups; auto.
  Qed.

  Lemma findUserKeys_readd_user_private_key :
    forall {A} (usrs : honest_users A) u_id proto msgs k_id ks mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := add_key_perm k_id true ks
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n  |})) = findUserKeys usrs $+ (k_id,true).
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto.
    cases (x ==n u_id); subst; clean_map_lookups.
    - unfold user_keys in H; rewrite add_eq_o in H; clean_map_lookups; trivial.
      rewrite map_add_eq; eauto.
      unfold findUserKeys; rewrite !fold_add; simpl; eauto.
      unfold add_key_perm, greatest_permission; cases (key_heap e $? k_id); subst; simpl;
        apply map_eq_Equal; unfold Equal; intros;
          cases (fold (fun (_ : NatMap.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u) usrs $0 $? y);
          cases (key_heap e $? y);
          destruct (y ==n k_id); subst;
            clean_map_lookups;
            simplify_key_merges;
            eauto.

    - assert (user_keys usrs u_id = Some ks) by (unfold user_keys in *; clean_map_lookups; auto).
      rewrite map_ne_swap by trivial.
      unfold findUserKeys; rewrite !fold_add with (k:=x) by (rewrite ?not_find_in_iff; clean_map_lookups; eauto).
      rewrite !findUserKeys_notation, IHusrs; auto.

      apply map_eq_Equal; unfold Equal; intros.
      cases (findUserKeys usrs $? y); cases (key_heap e $? y); destruct (k_id ==n y); subst;
        clean_map_lookups;
        simplify_key_merges;
        eauto.
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
      + erewrite merge_perms_adds_ks2; eauto.
    - unfold findUserKeys; rewrite fold_add; auto; rewrite findUserKeys_notation; eauto.
      cases (key_heap e $? k); subst; auto.
      + erewrite merge_perms_chooses_greatest; eauto; unfold greatest_permission; rewrite orb_true_l; auto.
      + erewrite merge_perms_adds_ks1 with (ks1:=findUserKeys usrs); eauto.
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
    forall honestk msgk k_id,
        honest_key honestk k_id
      -> honest_key (honestk $k++ msgk) k_id.
  Proof.
    invert 1; intros; econstructor; eauto.
    cases (msgk $? k_id); subst; eauto.
    - erewrite merge_perms_chooses_greatest by eauto; eauto.
    - erewrite merge_perms_adds_ks1; eauto.
  Qed.

  Hint Resolve honest_key_after_new_keys.

  Lemma honest_keyb_after_new_keys :
    forall honestk msgk k_id,
      honest_keyb honestk k_id = true
      -> honest_keyb (honestk $k++ msgk) k_id = true.
  Proof.
    intros; rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve honest_keyb_after_new_keys.

  Lemma not_honest_key_after_new_pub_keys :
    forall pubk honestk k,
      ~ honest_key honestk k
      -> (forall (k_id : NatMap.key) (kp : bool), pubk $? k_id = Some kp -> kp = false)
      -> ~ honest_key (honestk $k++ pubk) k.
  Proof.
    unfold not; invert 3; intros.
    cases (honestk $? k); cases (pubk $? k); subst;
      simplify_key_merges1; clean_map_lookups; eauto.
    - cases b; cases b0; simpl in *; eauto; try discriminate.
      specialize (H0 _ _ Heq0); discriminate.
    - specialize (H0 _ _ Heq0); discriminate.
  Qed.

  Hint Resolve not_honest_key_after_new_pub_keys.

  Lemma message_honestly_signed_after_add_keys :
    forall {t} (msg : crypto t) cs honestk ks,
      msg_honestly_signed honestk cs msg = true
      -> msg_honestly_signed (honestk $k++ ks) cs msg = true.
  Proof.
    intros.
    destruct msg; unfold msg_honestly_signed in *; simpl in *;
      try discriminate;
      repeat
        match goal with
        | [ |- context [ cs $? ?cid ]] => cases (cs $? cid); clean_map_lookups
        | [ |- context [ match ?c with _ => _ end ]] =>
          match type of c with
          | cipher => destruct c
          end
        end; eauto.
  Qed.

  Lemma message_honestly_signed_after_remove_pub_keys :
    forall {t} (msg : crypto t) honestk cs pubk,
      msg_honestly_signed (honestk $k++ pubk) cs msg = true
      -> (forall k kp, pubk $? k = Some kp -> kp = false)
      -> msg_honestly_signed honestk cs msg = true.
  Proof.
    intros.
    destruct msg; simpl in *; eauto;
      unfold msg_honestly_signed in *;
      repeat
        match goal with
        | [ H : match msg_signing_key ?cs ?c with _ => _ end = _ |- _ ] => cases (msg_signing_key cs c); try discriminate
        | [ |- context [ honest_keyb _ _ ] ] => unfold honest_keyb in *
        | [ H : match ?honk $k++ ?pubk $? ?k with _ => _ end = _ |- _ ] =>
          match goal with
          | [ H : honk $? k = _ |- _ ] => fail 1
          | _ => cases (honk $? k); cases (pubk $? k); simplify_key_merges1
          end
        | [ |- context [ if ?b then _ else _ ] ] => destruct b; subst
        | [ H : (forall k kp, ?pubk $? k = Some kp -> _), H1 : ?pubk $? _ = Some _ |- _ ] => specialize (H _ _ H1); subst
        end; try discriminate; auto.
  Qed.

  Lemma cipher_honestly_signed_after_msg_keys :
    forall honestk msgk c,
      cipher_honestly_signed honestk c = true
      -> cipher_honestly_signed (honestk $k++ msgk) c = true.
  Proof.
    unfold cipher_honestly_signed. intros; cases c; trivial;
      rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve cipher_honestly_signed_after_msg_keys.

  Lemma ciphers_honestly_signed_after_msg_keys :
    forall honestk msgk cs,
      ciphers_honestly_signed honestk cs
      -> ciphers_honestly_signed (honestk $k++ msgk) cs.
  Proof.
    induction 1; econstructor; eauto.
  Qed.

End RealWorldLemmas.

Lemma safe_messages_have_only_honest_public_keys :
  forall {t} (msg : message t) honestk,
    content_only_honest_public_keys honestk msg
    -> forall k_id,
      findKeysMessage msg $? k_id = None
      \/ (honestk $? k_id = Some true /\ findKeysMessage msg $? k_id = Some false).
Proof.
  induction 1; intros; subst; simpl in *; eauto.
  - destruct kp; simpl in *; subst;
      destruct (k_id ==n k); subst; clean_map_lookups; eauto.
  - specialize (IHcontent_only_honest_public_keys1 k_id).
    specialize (IHcontent_only_honest_public_keys2 k_id).
    split_ors; split_ands; eauto.
    + left; simplify_key_merges1; eauto.
    + right. intuition eauto; simplify_key_merges1; eauto.
    + right. intuition eauto; simplify_key_merges1; eauto.
    + right. intuition eauto; simplify_key_merges1; eauto.
Qed.

Hint Resolve safe_messages_have_only_honest_public_keys.

Lemma safe_cryptos_have_only_honest_public_keys :
  forall {t} (msg : crypto t) honestk cs,
    msg_contains_only_honest_public_keys honestk cs msg
    -> forall k_id,
      findKeysCrypto cs msg $? k_id = None
      \/ (honestk $? k_id = Some true /\ findKeysCrypto cs msg $? k_id = Some false).
Proof.
  intros.
  unfold findKeysCrypto; invert H; eauto;
    context_map_rewrites; eauto.
Qed.

Lemma safe_messages_perm_merge_honestk_idempotent :
  forall {t} (msg : crypto t) honestk cs,
    msg_contains_only_honest_public_keys honestk cs msg
    -> honestk $k++ findKeysCrypto cs msg = honestk.
Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    apply safe_cryptos_have_only_honest_public_keys with (k_id := y) in H; split_ors; split_ands;
      cases (honestk $? y); simplify_key_merges; clean_map_lookups; eauto.
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
  | message.Content t => Some t
  | _           => None
  end.

Definition updateTrackedNonce {t} (to_usr : option user_id) (froms : recv_nonces) (cs : ciphers) (msg : crypto t) :=
  match msg with
  | Content _ => froms
  | SignedCiphertext c_id =>
    match cs $? c_id with
    | None => froms
    | Some c =>
      match to_usr with
      | None => froms
      | Some to_uid =>
        if to_uid ==n cipher_to_user c
        then match count_occ msg_seq_eq froms (cipher_nonce c) with
             | 0 => cipher_nonce c :: froms
             | _ => froms
             end
        else froms
      end                
      (* let nonce := cipher_nonce c in *)
      (* let kid   := cipher_signing_key c *)
      (* in  match froms $? kid with *)
      (*     | None => froms $+ (kid, nonce) *)
      (*     | Some nonce' => *)
      (*       if nonce' <? nonce then froms $+ (kid,nonce) else froms *)
      (*     end *)
    end
  end.

(* Definition updateSendNonce (tos : send_nonces) (k_id : key_identifier) (u_id : user_id) := *)
(*   match tos $? k_id with *)
(*   | None => (0, tos $+ (k_id, ($0 $+ (u_id, 0)))) *)
(*   | Some usrs => *)
(*     match usrs $? u_id with *)
(*     | None => (0, tos $+ (k_id, usrs $+ (u_id, 0))) *)
(*     | Some nonce => (nonce+1, tos $+ (k_id, usrs $+ (u_id, nonce+1))) *)
(*     end *)
(*   end. *)

(* Definition cipher_nonce_absent_or_gt (froms : recv_nonces) (c : cipher) := *)
(*     froms $? cipher_signing_key c = None *)
(*   \/ (exists n, froms $? cipher_signing_key c = Some n /\ n < cipher_nonce c). *)

(* Definition overlapping_msg_nonce_smaller (new_cipher : cipher) (cs : ciphers) {t} (msg : crypto t) : Prop := *)
(*   forall c_id c, *)
(*       msg = SignedCiphertext c_id *)
(*     -> cs $? c_id = Some c *)
(*     -> cipher_signing_key c = cipher_signing_key new_cipher *)
(*     -> cipher_nonce c < cipher_nonce new_cipher. *)

Definition msg_nonce_not_same (new_cipher : cipher) (cs : ciphers) {t} (msg : crypto t) : Prop :=
  forall c_id c,
    msg = SignedCiphertext c_id
    -> cs $? c_id = Some c
    -> cipher_nonce new_cipher <> cipher_nonce c.
    (* \/ cipher_to_user new_cipher <> cipher_to_user c. *)

Definition msg_nonce_same (new_cipher : cipher) (cs : ciphers) {t} (msg : crypto t) : Prop :=
  forall c_id c,
      msg = SignedCiphertext c_id
    -> cs $? c_id = Some c
    -> cipher_nonce new_cipher = cipher_nonce c.
    (* /\ cipher_to_user new_cipher = cipher_to_user c. *)


Definition msg_not_replayed {t} (to_usr : option user_id) (cs : ciphers) (froms : recv_nonces) (msg : crypto t) (msgs : queued_messages) : Prop :=
  exists c_id c,
      msg = SignedCiphertext c_id
    /\ cs $? c_id = Some c
    /\ ~ List.In (cipher_nonce c) froms
    /\ Forall (fun sigM => match sigM with
                       | (existT _ _ m) => msg_to_this_user cs to_usr m = true
                                        -> msg_nonce_not_same c cs m
                       end) msgs.
    (* /\ cipher_nonce_absent_or_gt froms c *)
    (* /\ Forall (fun sigM => match sigM with existT _ _ m => overlapping_msg_nonce_smaller c cs m end) msgs. *)

Inductive action : Type :=
| Input  t (msg : crypto t) (pat : msg_pat) (froms : recv_nonces)
| Output t (msg : crypto t) (from_user : option user_id) (to_user : option user_id) (sents : sent_nonces)
.

Definition rlabel := @label action.

Definition action_adversary_safe (honestk : key_perms) (cs : ciphers) (a : action) : Prop :=
  match a with
  | Input  msg pat froms    => msg_pattern_safe honestk pat
                            /\ exists c_id c, msg = SignedCiphertext c_id
                                      /\ cs $? c_id = Some c
                                      /\ ~ List.In (cipher_nonce c) froms
  | Output msg msg_from msg_to sents => msg_contains_only_honest_public_keys honestk cs msg
                                     /\ msg_honestly_signed honestk cs msg = true
                                     /\ msg_to_this_user cs msg_to msg = true
                                     /\ msgCiphersSignedOk honestk cs msg
                                     /\ exists c_id c, msg = SignedCiphertext c_id
                                               /\ cs $? c_id = Some c
                                               /\ fst (cipher_nonce c) = msg_from  (* only send my messages *)
                                               /\ ~ List.In (cipher_nonce c) sents
                                   (* /\ msg_not_replayed cs to_frms msg to_q *)
  end.

Definition data_step0 (A B C : Type) : Type :=
  honest_users A * user_data B * ciphers * keys * key_perms * queued_messages * my_ciphers * recv_nonces * sent_nonces * nat * user_cmd C.

Definition build_data_step {A B C} (U : universe A B) (u_data : user_data C) : data_step0 A B C :=
  (U.(users), U.(adversary), U.(all_ciphers), U.(all_keys),
   u_data.(key_heap), u_data.(msg_heap), u_data.(c_heap), u_data.(from_nons), u_data.(sent_nons), u_data.(cur_nonce), u_data.(protocol)).

Inductive step_user : forall A B C, rlabel -> option user_id -> data_step0 A B C -> data_step0 A B C -> Prop :=

(* Plumbing *)
| StepBindRecur : forall {B r r'} (usrs usrs' : honest_users r') (adv adv' : user_data B)
                    lbl u_id cs cs' qmsgs qmsgs' gks gks' ks ks' mycs mycs' froms froms' sents sents' cur_n cur_n'
                    (cmd1 cmd1' : user_cmd r) (cmd2 : r -> user_cmd r'),
    step_user lbl u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd1)
                       (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd1')
    -> step_user lbl u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Bind cmd1 cmd2)
                         (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', Bind cmd1' cmd2)
| StepBindProceed : forall {B r r'} (usrs : honest_users r) (adv : user_data B) cs u_id gks ks qmsgs mycs froms sents cur_n
                      (v : r') (cmd : r' -> user_cmd r),
    step_user Silent u_id
              (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Bind (Return v) cmd)
              (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd v)

| StepGen : forall {A B} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks qmsgs mycs froms sents cur_n n,
    step_user Silent u_id (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Gen)
              (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Return n)

(* Comms  *)
| StepRecv : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks ks' qmsgs qmsgs' mycs mycs' froms froms'
               sents cur_n (msg : crypto t) msgs pat newkeys newcs,
      qmsgs = (existT _ _ msg) :: msgs (* we have a message waiting for us! *)
    -> qmsgs' = msgs
    -> findKeysCrypto cs msg = newkeys
    -> newcs = findCiphers msg
    -> ks' = ks $k++ newkeys
    -> mycs' = newcs ++ mycs
    -> froms' = updateTrackedNonce u_id froms cs msg
    -> msg_accepted_by_pattern cs u_id pat msg
    -> step_user (Action (Input msg pat froms)) u_id
                (usrs, adv, cs, gks, ks , qmsgs , mycs, froms, sents, cur_n,  Recv pat)
                (usrs, adv, cs, gks, ks', qmsgs', mycs', froms', sents, cur_n, Return msg)

| StepRecvDrop : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs suid gks ks qmsgs qmsgs'
                   mycs froms froms' sents cur_n (msg : crypto t) pat msgs,
      qmsgs = (existT _ _ msg) :: msgs (* we have a message waiting for us! *)
    -> qmsgs' = msgs
    -> froms' = (if msg_signed_addressed (findUserKeys usrs) cs suid msg
               then updateTrackedNonce suid froms cs msg
               else froms)
    -> ~ msg_accepted_by_pattern cs suid pat msg
    -> step_user Silent suid (* Error label ... *)
                (usrs, adv, cs, gks, ks, qmsgs , mycs, froms,  sents, cur_n, Recv pat)
                (usrs, adv, cs, gks, ks, qmsgs', mycs, froms', sents, cur_n, @Recv t pat)

(* Augment attacker's keys with those available through messages sent, *)
(*  * including traversing through ciphers already known by attacker, etc. *)
(*  *)
| StepSend : forall {A B} {t} (usrs usrs' : honest_users A) (adv adv' : user_data B)
               cs suid gks ks qmsgs mycs froms sents sents' cur_n rec_u_id rec_u newkeys (msg : crypto t),
    findKeysCrypto cs msg = newkeys
    -> keys_mine ks newkeys
    -> incl (findCiphers msg) mycs
    -> usrs $? rec_u_id = Some rec_u
    -> Some rec_u_id <> suid
    -> sents' = updateTrackedNonce (Some rec_u_id) sents cs msg
    -> usrs' = usrs $+ (rec_u_id, {| key_heap  := rec_u.(key_heap)
                                  ; protocol  := rec_u.(protocol)
                                  ; msg_heap  := rec_u.(msg_heap) ++ [existT _ _ msg]
                                  ; c_heap    := rec_u.(c_heap)
                                  ; from_nons := rec_u.(from_nons)
                                  ; sent_nons := rec_u.(sent_nons)
                                  ; cur_nonce := rec_u.(cur_nonce) |})
    -> adv' = 
      {| key_heap  := adv.(key_heap) $k++ newkeys
       ; protocol  := adv.(protocol)
       ; msg_heap  := adv.(msg_heap) ++ [existT _ _ msg]
       ; c_heap    := adv.(c_heap)
       ; from_nons := adv.(from_nons)
       ; sent_nons := adv.(sent_nons)
       ; cur_nonce := adv.(cur_nonce) |}
    -> step_user (Action (Output msg suid (Some rec_u_id) sents)) suid
                (usrs , adv , cs, gks, ks, qmsgs, mycs, froms, sents,  cur_n, Send rec_u_id msg)
                (usrs', adv', cs, gks, ks, qmsgs, mycs, froms, sents', cur_n, Return tt)

(* Encryption / Decryption *)
| StepEncrypt : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs cs' u_id gks ks qmsgs mycs mycs' froms sents
                  cur_n cur_n' (msg : message t) k__signid k__encid kp__enc kt__enc kt__sign c_id cipherMsg msg_to,
      gks $? k__encid  = Some (MkCryptoKey k__encid Encryption kt__enc)
    -> gks $? k__signid = Some (MkCryptoKey k__signid Signing kt__sign)
    -> ks $? k__encid   = Some kp__enc
    -> ks $? k__signid  = Some true
    -> ~ In c_id cs
    -> keys_mine ks (findKeysMessage msg)
    (* -> incl (findCiphers msg) mycs *)
    (* -> pr_nonce_tos = updateTrackedNonce tos k__signid msg_to *)
    -> cur_n' = 1 + cur_n
    -> cipherMsg = SigEncCipher k__signid k__encid msg_to (u_id, cur_n) msg
    -> cs' = cs $+ (c_id, cipherMsg)
    -> mycs' = c_id :: mycs
    (* -> tos' = snd pr_nonce_tos *)
    -> step_user Silent u_id
                (usrs, adv, cs , gks, ks, qmsgs, mycs,  froms, sents, cur_n,  SignEncrypt k__signid k__encid msg)
                (usrs, adv, cs', gks, ks, qmsgs, mycs', froms, sents, cur_n', Return (SignedCiphertext c_id))

| StepDecrypt : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks ks' qmsgs mycs mycs'
                  (msg : message t) k__signid kp__sign k__encid c_id nonce newkeys kt__sign kt__enc msg_to froms sents cur_n,
      cs $? c_id     = Some (SigEncCipher k__signid k__encid msg_to nonce msg)
    -> gks $? k__encid  = Some (MkCryptoKey k__encid Encryption kt__enc)
    -> gks $? k__signid = Some (MkCryptoKey k__signid Signing kt__sign)
    -> ks  $? k__encid  = Some true
    -> ks  $? k__signid = Some kp__sign
    -> findKeysMessage msg = newkeys
    (* -> newcs = findCiphers msg *)
    -> ks' = ks $k++ newkeys
    -> mycs' = (* newcs ++  *)mycs
    -> List.In c_id mycs
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks , qmsgs, mycs,  froms, sents, cur_n, Decrypt (SignedCiphertext c_id))
                (usrs, adv, cs, gks, ks', qmsgs, mycs', froms, sents, cur_n, Return msg)

(* Signing / Verification *)
| StepSign : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs cs' u_id gks ks qmsgs mycs mycs' froms sents cur_n cur_n'
               (msg : message t) k_id kt c_id cipherMsg msg_to,
      gks $? k_id = Some (MkCryptoKey k_id Signing kt)
    -> ks  $? k_id = Some true
    -> ~ In c_id cs
    -> cur_n' = 1 + cur_n
    (* -> pr_nonce_tos = updateSendNonce tos k_id msg_to *)
    -> cipherMsg = SigCipher k_id msg_to (u_id, cur_n) msg
    -> cs' = cs $+ (c_id, cipherMsg)
    -> mycs' = c_id :: mycs
    -> step_user Silent u_id
                (usrs, adv, cs , gks, ks, qmsgs, mycs,  froms, sents, cur_n,  Sign k_id msg)
                (usrs, adv, cs', gks, ks, qmsgs, mycs', froms, sents, cur_n', Return (SignedCiphertext c_id))

| StepVerify : forall {A B} {t} (usrs : honest_users A) (adv : user_data B) cs u_id gks ks qmsgs mycs froms sents cur_n
                 (msg : message t) k_id kp kt c_id nonce msg_to,
      gks $? k_id = Some (MkCryptoKey k_id Signing kt)
    -> ks  $? k_id = Some kp
    -> cs $? c_id = Some (SigCipher k_id msg_to nonce msg)
    -> List.In c_id mycs
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Verify k_id (SignedCiphertext c_id))
                (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, Return (true, msg))
| StepGenerateSymKey: forall {A B} (usrs : honest_users A) (adv : user_data B)
                        cs u_id gks gks' ks ks' qmsgs mycs froms sents cur_n
                        (k_id : key_identifier) k usage,
    gks $? k_id = None
    -> k = MkCryptoKey k_id usage SymKey
    -> gks' = gks $+ (k_id, k)
    -> ks' = add_key_perm k_id true ks
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, GenerateSymKey usage)
                (usrs, adv, cs, gks', ks', qmsgs, mycs, froms, sents, cur_n, Return (k_id, true))
| StepGenerateAsymKey: forall {A B} (usrs : honest_users A) (adv : user_data B)
                         cs u_id gks gks' ks ks' qmsgs mycs froms sents cur_n
                         (k_id : key_identifier) k usage,
    gks $? k_id = None
    -> k = MkCryptoKey k_id usage AsymKey
    -> gks' = gks $+ (k_id, k)
    -> ks' = add_key_perm k_id true ks
    -> step_user Silent u_id
                (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, GenerateAsymKey usage)
                (usrs, adv, cs, gks', ks', qmsgs, mycs, froms, sents, cur_n, Return (k_id, true))
.

Inductive step_universe {A B} : universe A B -> rlabel -> universe A B -> Prop :=
| StepUser : forall U U' (u_id : user_id) userData usrs adv cs gks ks qmsgs mycs froms sents cur_n lbl (cmd : user_cmd A),
    U.(users) $? u_id = Some userData
    -> step_user lbl (Some u_id)
                (build_data_step U userData)
                (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
    -> U' = buildUniverse usrs adv cs gks u_id {| key_heap  := ks
                                               ; msg_heap  := qmsgs
                                               ; protocol  := cmd
                                               ; c_heap    := mycs
                                               ; from_nons := froms
                                               ; sent_nons := sents
                                               ; cur_nonce := cur_n |}
    -> step_universe U lbl U'
| StepAdversary : forall U U' usrs adv cs gks ks qmsgs mycs froms sents cur_n lbl (cmd : user_cmd B),
    step_user lbl None
              (build_data_step U U.(adversary))
              (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
    -> U' = buildUniverseAdv usrs cs gks {| key_heap  := ks
                                         ; msg_heap  := qmsgs
                                         ; protocol  := cmd
                                         ; c_heap    := mycs
                                         ; from_nons := froms
                                         ; sent_nons := sents
                                         ; cur_nonce := cur_n |}
    -> step_universe U Silent U'
.
