From Coq Require Import
     List
     Morphisms
     Eqdep
     (* Program.Equality (* for dependent induction *) *)
.

Require Import
        MyPrelude
        Maps
        Messages
        Common
        MapLtac
        Keys
        Automation
        Tactics.

Require IdealWorld
        RealWorld.

Set Implicit Arguments.

Lemma accepted_safe_msg_pattern_honestly_signed :
  forall {t} (msg : RealWorld.crypto t) honestk pat,
    RealWorld.msg_pattern_safe honestk pat
    -> RealWorld.msg_accepted_by_pattern pat msg
    -> RealWorld.msg_honestly_signed honestk msg = true.
Proof.
  intros.
  destruct msg;
    repeat match goal with
           | [ H : RealWorld.msg_pattern_safe _ _ |- _] => invert H
           | [ H : RealWorld.msg_accepted_by_pattern _ _ |- _] => invert H
           end; simpl; rewrite <- RealWorld.honest_key_honest_keyb; auto.
Qed.

Hint Resolve accepted_safe_msg_pattern_honestly_signed.

(******************** CIPHER CLEANING *********************
 **********************************************************
 *
 * Function to clean ciphehrs and lemmas about it.
 *)

Section CleanCiphers.
  Import RealWorld.

  Variable honestk : key_perms.

  Definition honest_cipher_filter_fn (c_id : cipher_id) (c : cipher) :=
    cipher_honestly_signed honestk c.

  Lemma honest_cipher_filter_fn_proper :
    Proper (eq  ==>  eq  ==>  eq) honest_cipher_filter_fn.
  Proof.
    solve_proper.
  Qed.

  Lemma honest_cipher_filter_fn_filter_proper :
    Proper
      ( eq  ==>  eq  ==>  Equal  ==>  Equal)
      (fun (k : NatMap.key) (e : cipher) (m : t cipher) => if honest_cipher_filter_fn k e then m $+ (k, e) else m).
  Proof.
    unfold Proper, respectful;
      unfold Equal; intros; apply map_eq_Equal in H1; subst; auto.
  Qed.

  Lemma honest_cipher_filter_fn_filter_transpose :
    transpose_neqkey Equal
       (fun (k : NatMap.key) (e : cipher) (m : t cipher) => if honest_cipher_filter_fn k e then m $+ (k, e) else m).
  Proof.
    unfold transpose_neqkey, Equal, honest_cipher_filter_fn, cipher_honestly_signed; intros.
    cases e; cases e'; simpl;
      repeat match goal with
             | [ |- context[if ?cond then _ else _] ] => cases cond
             | [ |- context[_ $+ (?k1,_) $? ?k2] ] => cases (k1 ==n k2); subst; clean_map_lookups
             end; eauto.
  Qed.

  Lemma honest_cipher_filter_fn_filter_proper_eq :
    Proper
      ( eq  ==>  eq  ==>  eq  ==>  eq)
      (fun (k : NatMap.key) (e : cipher) (m : t cipher) => if honest_cipher_filter_fn k e then m $+ (k, e) else m).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_cipher_filter_fn_filter_transpose_eq :
    transpose_neqkey eq
       (fun (k : NatMap.key) (e : cipher) (m : t cipher) => if honest_cipher_filter_fn k e then m $+ (k, e) else m).
  Proof.
    unfold transpose_neqkey, honest_cipher_filter_fn, cipher_honestly_signed; intros.
    cases e; cases e'; subst; simpl;
      repeat match goal with
             | [ |- context[if ?cond then _ else _] ] => cases cond
             | [ |- context[_ $+ (?k1,_) $? ?k2] ] => cases (k1 ==n k2); subst; clean_map_lookups
             end; eauto;
        rewrite map_ne_swap; eauto.
  Qed.

  Definition clean_ciphers (cs : ciphers) :=
    filter honest_cipher_filter_fn cs.

  Hint Resolve
       honest_cipher_filter_fn_proper
       honest_cipher_filter_fn_filter_proper
       honest_cipher_filter_fn_filter_transpose
       honest_cipher_filter_fn_filter_proper_eq
       honest_cipher_filter_fn_filter_transpose_eq.

  Lemma clean_ciphers_mapsto_iff : forall cs c_id c,
      MapsTo c_id c (clean_ciphers cs) <-> MapsTo c_id c cs /\ honest_cipher_filter_fn c_id c = true.
  Proof.
    intros.
    apply filter_iff; eauto.
  Qed.

  Lemma clean_ciphers_keeps_honest_cipher :
    forall c_id c cs,
      cs $? c_id = Some c
      -> honest_cipher_filter_fn c_id c = true
      -> clean_ciphers cs $? c_id = Some c.
  Proof.
    intros.
    rewrite <- find_mapsto_iff.
    rewrite <- find_mapsto_iff in H.
    apply clean_ciphers_mapsto_iff; intuition idtac.
  Qed.

  Lemma honest_key_not_cleaned : forall cs c_id c k,
      cs $? c_id = Some c
      -> k = cipher_signing_key c
      -> honest_key honestk k
      -> clean_ciphers cs $? c_id = Some c.
  Proof.
    intros.
    eapply clean_ciphers_keeps_honest_cipher; auto.
    unfold honest_cipher_filter_fn, cipher_honestly_signed.
    destruct c; subst.
    + invert H. rewrite <- honest_key_honest_keyb; eauto.
    + invert H. rewrite <- honest_key_honest_keyb; eauto.
  Qed.

  Hint Constructors
       msg_accepted_by_pattern
       msg_contains_only_honest_public_keys.

  Hint Extern 1 (_ $+ (?k, _) $? ?k = Some _) => rewrite add_eq_o.
  Hint Extern 1 (_ $+ (?k, _) $? ?v = _) => rewrite add_neq_o.

  Lemma clean_ciphers_eliminates_dishonest_cipher :
    forall c_id c cs k,
      cs $? c_id = Some c
      -> honest_keyb honestk k = false
      -> k = cipher_signing_key c
      -> clean_ciphers cs $? c_id = None.
  Proof.
    intros; unfold clean_ciphers, filter.
    apply P.fold_rec_bis; intros; eauto.
    cases (honest_cipher_filter_fn k0 e); eauto.
    cases (c_id ==n k0); subst; eauto.
    exfalso.
    rewrite find_mapsto_iff in H2; rewrite H2 in H; invert H.
    unfold honest_cipher_filter_fn, cipher_honestly_signed, cipher_signing_key in *.
    cases c; rewrite H0 in Heq; invert Heq. 
  Qed.

  Hint Resolve clean_ciphers_eliminates_dishonest_cipher clean_ciphers_keeps_honest_cipher.

  Lemma clean_ciphers_keeps_added_honest_cipher :
    forall c_id c cs,
      honest_cipher_filter_fn c_id c = true
      -> ~ In c_id cs
      -> clean_ciphers (cs $+ (c_id,c)) = clean_ciphers cs $+ (c_id,c).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (c_id ==n y); subst; clean_map_lookups; eauto.
    unfold clean_ciphers, filter; rewrite fold_add; eauto.
    rewrite H; auto.
  Qed.

  Lemma clean_ciphers_reduces_or_keeps_same_ciphers :
    forall c_id c cs k,
      cs $? c_id = Some c
      -> cipher_signing_key c = k
      -> ( clean_ciphers  cs $? c_id = Some c
        /\ honest_keyb honestk k = true)
      \/ ( clean_ciphers cs $? c_id = None
        /\ honest_keyb honestk k = false).
  Proof.
    intros.
    case_eq (honest_keyb honestk k); intros; eauto.
    left; intuition idtac.
    eapply clean_ciphers_keeps_honest_cipher; eauto.
    unfold honest_cipher_filter_fn, cipher_signing_key in *.
    cases c; try invert H0; eauto.
  Qed.

  Lemma clean_ciphers_no_new_ciphers :
    forall c_id cs,
      cs $? c_id = None
      -> clean_ciphers cs $? c_id = None.
  Proof.
    intros.
    unfold clean_ciphers, filter.
    apply P.fold_rec_bis; intros; eauto.
    cases (honest_cipher_filter_fn k e); eauto.
    - case (c_id ==n k); intro; subst; unfold honest_cipher_filter_fn.
      + rewrite find_mapsto_iff in H0; rewrite H0 in H; invert H.
      + rewrite add_neq_o; eauto.
  Qed.

  Hint Resolve clean_ciphers_no_new_ciphers.

  Lemma clean_ciphers_eliminates_added_dishonest_cipher :
    forall c_id c cs k,
      cs $? c_id = None
      -> honest_keyb honestk k = false
      -> k = cipher_signing_key c
      -> clean_ciphers cs = clean_ciphers (cs $+ (c_id,c)).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (y ==n c_id); subst.
    - rewrite clean_ciphers_no_new_ciphers; auto.
      symmetry.
      eapply clean_ciphers_eliminates_dishonest_cipher; eauto.
    - unfold clean_ciphers at 2, filter.
      rewrite fold_add; auto. simpl.
      unfold honest_cipher_filter_fn at 1.
      cases c; simpl in *; try invert H1; rewrite H0; trivial.
  Qed.

  Lemma not_in_ciphers_not_in_cleaned_ciphers :
    forall c_id cs,
      ~ In c_id cs
      -> ~ In c_id (clean_ciphers cs).
  Proof.
    intros.
    rewrite not_find_in_iff in H.
    apply not_find_in_iff; eauto.
  Qed.

  Hint Resolve not_in_ciphers_not_in_cleaned_ciphers.

  Lemma dishonest_cipher_cleaned :
    forall cs c_id cipherMsg k,
      cipher_signing_key cipherMsg = k
      -> honest_keyb honestk k = false
      -> ~ In c_id cs
      -> clean_ciphers cs = clean_ciphers (cs $+ (c_id, cipherMsg)).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    case_eq (cs $? y); intros; simpl in *.
    - eapply clean_ciphers_reduces_or_keeps_same_ciphers in H2; eauto.
      split_ors; split_ands;
        unfold clean_ciphers, filter; rewrite fold_add by auto;
          unfold honest_cipher_filter_fn; cases cipherMsg; invert H; simpl in *; rewrite H0; reflexivity.
    - rewrite clean_ciphers_no_new_ciphers; auto. eapply clean_ciphers_no_new_ciphers in H2.
      unfold clean_ciphers, filter. rewrite fold_add by auto.
      unfold honest_cipher_filter_fn; cases cipherMsg; invert H; simpl in *; rewrite H0; eauto. 
  Qed.

  Hint Resolve dishonest_cipher_cleaned.

  Hint Extern 1 (honest_cipher_filter_fn _ ?c = _) => unfold honest_cipher_filter_fn; cases c.

  Lemma clean_ciphers_added_honest_cipher_not_cleaned :
    forall cs c_id c k,
        honest_key honestk k
      -> k = cipher_signing_key c
      -> clean_ciphers (cs $+ (c_id,c)) = clean_ciphers cs $+ (c_id,c).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.

    case (y ==n c_id); intros; subst; clean_map_lookups.
    - erewrite clean_ciphers_keeps_honest_cipher; auto.
      invert H; unfold honest_cipher_filter_fn; eauto.
      unfold cipher_honestly_signed, honest_keyb;
        cases c; simpl in *; context_map_rewrites; auto; invert H0; rewrite H1; trivial.
    - case_eq (clean_ciphers cs $? y); intros; subst;
        cases (cs $? y); subst; eauto.
        * assert (cs $? y = Some c1) as CSY by assumption;
            eapply clean_ciphers_reduces_or_keeps_same_ciphers in CSY; eauto;
              split_ors; split_ands;
                clean_map_lookups.
          eapply clean_ciphers_keeps_honest_cipher; eauto.
        * exfalso; eapply clean_ciphers_no_new_ciphers in Heq; contra_map_lookup.
        * assert (cs $? y = Some c0) as CSY by assumption;
            eapply clean_ciphers_reduces_or_keeps_same_ciphers in CSY; eauto;
              split_ors; split_ands; contra_map_lookup; eauto.
  Qed.

  Lemma clean_ciphers_idempotent :
    forall cs,
      ciphers_honestly_signed honestk cs
      -> clean_ciphers cs = cs.
  Proof.
    unfold clean_ciphers, filter, ciphers_honestly_signed; intros.
    apply P.fold_rec_bis; intros; Equal_eq; subst; eauto.
    unfold honest_cipher_filter_fn.
    rewrite find_mapsto_iff in H0.
    assert (cipher_honestly_signed honestk e = true).
    eapply Forall_natmap_in_prop with (P := fun c => cipher_honestly_signed honestk c = true); eauto.
    rewrite H2; trivial.
  Qed.

  Lemma clean_ciphers_honestly_signed :
    forall cs,
      ciphers_honestly_signed honestk (clean_ciphers cs).
  Proof.
    unfold ciphers_honestly_signed; intros.
    rewrite Forall_natmap_forall; intros.
    rewrite <- find_mapsto_iff, clean_ciphers_mapsto_iff in H; split_ands.
    unfold honest_cipher_filter_fn in *; assumption.
  Qed.

End CleanCiphers.

(******************** MESSAGE CLEANING ********************
 **********************************************************
 *
 * Function to clean messages and lemmas about it.
 *)

Section CleanMessages.
  Import RealWorld.

  Section CleanMessagesImpl.
    Variable honestk : key_perms.
    Variable msgs : queued_messages.

    Definition msg_filter (sigM : { t & crypto t } ) : bool :=
      match sigM with
      | existT _ _ msg => msg_honestly_signed honestk msg
      end.

    Definition clean_messages :=
      List.filter msg_filter.

  End CleanMessagesImpl.

  Lemma clean_messages_keeps_honestly_signed :
    forall {t} (msg : crypto t) honestk msgs,
      msg_honestly_signed honestk msg = true
      -> clean_messages honestk (msgs ++ [existT _ _ msg])
        = clean_messages honestk msgs ++ [existT _ _ msg].
  Proof.
    intros; unfold clean_messages.
    induction msgs; simpl; eauto.
    - rewrite H; trivial.
    - cases (msg_filter honestk a); subst; eauto.
      rewrite IHmsgs; trivial.
  Qed.

  Lemma clean_messages_drops_not_honestly_signed :
    forall {t} (msg : crypto t) msgs honestk,
      msg_honestly_signed honestk msg = false
      -> clean_messages honestk (msgs ++ [existT _ _ msg])
        = clean_messages honestk msgs.
  Proof.
    intros; unfold clean_messages. (*  *)
    induction msgs; simpl; eauto.
    - rewrite H; trivial.
    - cases (msg_filter honestk a); subst; eauto.
      rewrite IHmsgs; trivial.
  Qed.

  Lemma clean_message_keeps_safely_patterned_message :
    forall {t} (msg : crypto t) honestk msgs pat,
      msg_pattern_safe honestk pat
      -> msg_accepted_by_pattern pat msg
      -> clean_messages honestk (existT _ _ msg :: msgs)
        = (existT _ _ msg) :: clean_messages honestk msgs.
  Proof.
    intros.
    assert (msg_honestly_signed honestk msg = true) by eauto.
    unfold clean_messages; simpl;
      match goal with
      | [ H : msg_honestly_signed _ _ = _ |- _ ] => rewrite H
      end; trivial.
  Qed.

  Lemma clean_messages_idempotent :
    forall msgs honestk,
      clean_messages honestk (clean_messages honestk msgs) = clean_messages honestk msgs.
  Proof.
    induction msgs; intros; eauto.
    simpl.
    case_eq (msg_filter honestk a); intros; eauto.
    simpl; rewrite H; auto.
    rewrite IHmsgs; trivial.
  Qed.

End CleanMessages.

(******************** KEYS CLEANING ***********************
 **********************************************************
 *
 * Function to clean keys and lemmas about it.
 *)

Section CleanKeys.
  Import RealWorld.

  Variable honestk : key_perms.

  Definition honest_key_filter_fn (k_id : key_identifier) (k : key) :=
    match honestk $? k_id with
    | Some true => true
    | _ => false
    end.

  Definition clean_keys :=
    filter honest_key_filter_fn.

  Lemma honest_key_filter_fn_proper :
    Proper (eq  ==>  eq  ==>  eq) honest_key_filter_fn.
  Proof.
    solve_proper.
  Qed.

  Lemma honest_key_filter_fn_filter_proper :
    Proper (eq  ==>  eq  ==>  eq  ==>  eq) (fun k v m => if honest_key_filter_fn k v then m $+ (k,v) else m).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_key_filter_fn_filter_transpose :
    transpose_neqkey eq (fun k v m => if honest_key_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey; intros.
    unfold honest_key_filter_fn.
    cases (honestk $? k); cases (honestk $? k'); eauto.
    destruct b; destruct b0; eauto.
    rewrite map_ne_swap; auto.
  Qed.

  Lemma honest_key_filter_fn_filter_proper_Equal :
    Proper (eq  ==>  eq  ==>  Equal  ==>  Equal) (fun k v m => if honest_key_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold Equal, Proper, respectful; intros; subst.
    destruct (honest_key_filter_fn y y0); eauto.
    destruct (y ==n y2); subst; clean_map_lookups; auto.
  Qed.

  Lemma honest_key_filter_fn_filter_transpose_Equal :
    transpose_neqkey Equal (fun k v m => if honest_key_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, Equal; intros.
    unfold honest_key_filter_fn.
    cases (honestk $? k); cases (honestk $? k'); eauto.
    destruct b; destruct b0; eauto.
    rewrite map_ne_swap; auto.
  Qed.

  Hint Resolve
       honest_key_filter_fn_proper
       honest_key_filter_fn_filter_proper honest_key_filter_fn_filter_transpose
       honest_key_filter_fn_filter_proper_Equal honest_key_filter_fn_filter_transpose_Equal.

  Lemma clean_keys_inv :
    forall k_id k ks,
      clean_keys ks $? k_id = Some k
      -> ks $? k_id = Some k
      /\ honest_key_filter_fn k_id k = true.
  Proof.
    unfold clean_keys; intros until ks.
    rewrite <- !find_mapsto_iff.
    apply filter_iff; eauto.
  Qed.

  Lemma clean_keys_inv' :
    forall k_id k ks,
      clean_keys ks $? k_id = None
      -> ks $? k_id = Some k
      -> honest_key_filter_fn k_id k = false.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; clean_map_lookups; eauto.

    destruct (x ==n k_id); subst; clean_map_lookups; eauto.
    - unfold clean_keys,filter in H0; rewrite fold_add in H0; eauto.
      cases (honest_key_filter_fn k_id k); clean_map_lookups; try discriminate; trivial.
    - eapply IHks; eauto.
      unfold clean_keys, filter in H0.
      rewrite fold_add in H0; eauto.
      cases (honest_key_filter_fn x e); eauto.
      clean_map_lookups; eauto.
  Qed.

  Lemma clean_keys_keeps_honest_key :
    forall k_id k ks,
        ks $? k_id = Some k
      -> honest_key_filter_fn k_id k = true
      -> clean_keys ks $? k_id = Some k.
  Proof.
    unfold clean_keys; intros.
    rewrite <- !find_mapsto_iff.
    apply filter_iff; eauto.
    rewrite find_mapsto_iff; eauto.
  Qed.

  Lemma clean_keys_drops_dishonest_key :
    forall k_id k ks,
        ks $? k_id = Some k
      -> honest_key_filter_fn k_id k = false
      -> clean_keys ks $? k_id = None.
  Proof.
    unfold clean_keys; intros.
    rewrite <- not_find_in_iff.
    unfold not; intros.
    rewrite in_find_iff in H1.
    cases (filter honest_key_filter_fn ks $? k_id); try contradiction.
    rewrite <- find_mapsto_iff in Heq.
    rewrite filter_iff in Heq; eauto.
    split_ands.
    rewrite find_mapsto_iff in H2.
    clean_map_lookups.
    rewrite H0 in H3; discriminate.
  Qed.

  Lemma clean_keys_adds_no_keys :
    forall k_id ks,
        ks $? k_id = None
      -> clean_keys ks $? k_id = None.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; eauto.
    unfold clean_keys, filter; rewrite fold_add; eauto.
    destruct (x ==n k_id); subst; clean_map_lookups.
    destruct (honest_key_filter_fn x e); eauto.
    clean_map_lookups; eauto.
  Qed.

  Lemma clean_keys_idempotent :
    forall ks,
      clean_keys (clean_keys ks) = clean_keys ks.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (clean_keys ks $? y); eauto using clean_keys_adds_no_keys.
    eapply clean_keys_keeps_honest_key; auto.
    apply clean_keys_inv in Heq; split_ands; auto.
  Qed.

  Definition honest_perm_filter_fn (k_id : key_identifier) (kp : bool) :=
    match honestk $? k_id with
    | Some true => true
    | _ => false
    end.

  Definition clean_key_permissions :=
    filter honest_perm_filter_fn.

  Lemma honest_perm_filter_fn_proper :
    Proper (eq  ==>  eq  ==>  eq) honest_perm_filter_fn.
  Proof.
    solve_proper.
  Qed.

  Lemma honest_perm_filter_fn_filter_proper :
    Proper (eq  ==>  eq  ==>  eq  ==>  eq) (fun k v m => if honest_perm_filter_fn k v then m $+ (k,v) else m).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_perm_filter_fn_filter_transpose :
    transpose_neqkey eq (fun k v m => if honest_perm_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey; intros.
    unfold honest_perm_filter_fn.
    cases (honestk $? k); cases (honestk $? k'); eauto.
    destruct b; destruct b0; eauto.
    rewrite map_ne_swap; auto.
  Qed.

  Lemma honest_perm_filter_fn_filter_proper_Equal :
    Proper (eq  ==>  eq  ==>  Equal  ==>  Equal) (fun k v m => if honest_perm_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold Equal, Proper, respectful; intros; subst.
    destruct (honest_perm_filter_fn y y0); eauto.
    destruct (y ==n y2); subst; clean_map_lookups; auto.
  Qed.

  Lemma honest_perm_filter_fn_filter_transpose_Equal :
    transpose_neqkey Equal (fun k v m => if honest_perm_filter_fn k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, Equal; intros.
    unfold honest_perm_filter_fn.
    cases (honestk $? k); cases (honestk $? k'); eauto.
    destruct b; destruct b0; eauto.
    rewrite map_ne_swap; auto.
  Qed.

  Hint Resolve
       honest_perm_filter_fn_proper
       honest_perm_filter_fn_filter_proper honest_perm_filter_fn_filter_transpose
       honest_perm_filter_fn_filter_proper_Equal honest_perm_filter_fn_filter_transpose_Equal.

  Lemma clean_key_permissions_inv :
    forall k_id k ks,
      clean_key_permissions ks $? k_id = Some k
      -> ks $? k_id = Some k
      /\ honest_perm_filter_fn k_id k = true.
  Proof.
    unfold clean_key_permissions; intros until ks.
    rewrite <- !find_mapsto_iff.
    apply filter_iff; eauto.
  Qed.

  Lemma clean_key_permissions_inv' :
    forall k_id k ks,
      clean_key_permissions ks $? k_id = None
      -> ks $? k_id = Some k
      -> honest_perm_filter_fn k_id k = false.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; clean_map_lookups; eauto.

    destruct (x ==n k_id); subst; clean_map_lookups; eauto.
    - unfold clean_key_permissions,filter in H0; rewrite fold_add in H0; eauto.
      cases (honest_perm_filter_fn k_id k); clean_map_lookups; try discriminate; trivial.
    - eapply IHks; eauto.
      unfold clean_key_permissions, filter in H0.
      rewrite fold_add in H0; eauto.
      cases (honest_perm_filter_fn x e); eauto.
      clean_map_lookups; eauto.
  Qed.

  Lemma clean_key_permissions_adds_no_permissions :
    forall k_id ks,
        ks $? k_id = None
      -> clean_key_permissions ks $? k_id = None.
  Proof.
    induction ks using P.map_induction_bis; intros; Equal_eq; eauto.
    unfold clean_key_permissions, filter; rewrite fold_add; eauto.
    destruct (x ==n k_id); subst; clean_map_lookups.
    destruct (honest_perm_filter_fn x e); eauto.
    clean_map_lookups; eauto.
  Qed.

  Lemma clean_key_permissions_keeps_honest_permission :
    forall k_id k ks,
        ks $? k_id = Some k
      -> honest_perm_filter_fn k_id k = true
      -> clean_key_permissions ks $? k_id = Some k.
  Proof.
    unfold clean_key_permissions; intros.
    rewrite <- !find_mapsto_iff.
    apply filter_iff; eauto.
    rewrite find_mapsto_iff; eauto.
  Qed.

  Lemma clean_key_permissions_drops_dishonest_permission :
    forall k_id k ks,
        ks $? k_id = Some k
      -> honest_perm_filter_fn k_id k = false
      -> clean_key_permissions ks $? k_id = None.
  Proof.
    unfold clean_key_permissions; intros.
    rewrite <- not_find_in_iff.
    unfold not; intros.
    rewrite in_find_iff in H1.
    cases (filter honest_perm_filter_fn ks $? k_id); try contradiction.
    rewrite <- find_mapsto_iff in Heq.
    rewrite filter_iff in Heq; eauto.
    split_ands.
    rewrite find_mapsto_iff in H2.
    clean_map_lookups.
    rewrite H0 in H3; discriminate.
  Qed.

  Lemma clean_key_permissions_idempotent :
    forall ks,
      clean_key_permissions ks = clean_key_permissions (clean_key_permissions ks).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    symmetry; cases (clean_key_permissions ks $? y).
    - generalize (clean_key_permissions_inv _ _ Heq); intros;
        split_ands; apply clean_key_permissions_keeps_honest_permission; eauto.
    - eapply clean_key_permissions_adds_no_permissions; eauto.
  Qed.

  Lemma clean_key_permissions_distributes_merge_key_permissions :
    forall perms1 perms2,
      clean_key_permissions (perms1 $k++ perms2) = clean_key_permissions perms1 $k++ clean_key_permissions perms2.
  Proof.
    intros; apply map_eq_Equal; unfold Equal; intros.
    cases (clean_key_permissions perms1 $? y);
      cases (clean_key_permissions perms2 $? y);
      cases (clean_key_permissions (perms1 $k++ perms2) $? y); simplify_key_merges1; eauto;
        repeat (
            match goal with
            | [ H1 : honest_perm_filter_fn ?y _ = true, H2 : honest_perm_filter_fn ?y _ = false |- _ ] =>
              unfold honest_perm_filter_fn in *; cases (honestk $? y); try discriminate
            | [ H : (if ?b then _ else _) = _ |- _ ] => destruct b; try discriminate
            | [ H : clean_key_permissions _ $? _ = Some _ |- _ ] => apply clean_key_permissions_inv in H
            | [ H0 : ?perms $? ?y = Some _ , H : clean_key_permissions ?perms $? ?y = None |- _ ] =>
              apply (clean_key_permissions_inv' _ _ H) in H0; clear H
            | [ H1 : _ $? ?y = Some _, H2 : perms1 $k++ perms2 $? ?y = None |- _ ] =>
              apply merge_perms_no_disappear_perms in H2; split_ands; contra_map_lookup
            | [ H0 : ?perms $? ?y = None , H : clean_key_permissions ?perms $? ?y = None |- _ ] =>
              simplify_key_merges1; eauto 2
            | [ H : clean_key_permissions ?perms $? ?y = None |- _ ] =>
              match goal with
                | [ H : perms $? y = _ |- _ ] => fail 1
                | _ => cases (perms $? y)
              end
            | [ H1 : perms1 $? ?y = _, H2 : perms2 $? ?y = _ |- _ ] => simplify_key_merges1
            end; split_ands; auto 2).
  Qed.

  Lemma clean_honest_key_permissions_distributes :
    forall perms pubk,
      (forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true /\ kp = false)
      -> clean_key_permissions (perms $k++ pubk) = clean_key_permissions perms $k++ pubk.
  Proof.
    intros.

    rewrite clean_key_permissions_distributes_merge_key_permissions.
    apply map_eq_Equal; unfold Equal; intros.
    cases (pubk $? y).
    - specialize (H _ _ Heq); split_ands; subst.
      assert (clean_key_permissions pubk $? y = Some false)
        by (eapply clean_key_permissions_keeps_honest_permission; eauto; unfold honest_perm_filter_fn; context_map_rewrites; trivial).
      cases (clean_key_permissions perms $? y);
        simplify_key_merges; eauto.
    - assert (clean_key_permissions pubk $? y = None) 
        by (apply clean_key_permissions_adds_no_permissions; eauto).
      cases (clean_key_permissions perms $? y);
        simplify_key_merges; eauto.
  Qed.

  Lemma adv_no_honest_key_honest_key :
    forall pubk,
      (forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true /\ kp = false)
      -> forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true.
  Proof.
    intros.
    specialize (H _ _ H0); intuition idtac.
  Qed.

End CleanKeys.

(******************** USER CLEANING ***********************
 **********************************************************
 *
 * Function to clean users and lemmas about it.
 *)

Section CleanUsers.
  Import RealWorld.

  Variable honestk : key_perms.

  Definition clean_users {A} (usrs : honest_users A) :=
    map (fun u_d => {| key_heap := clean_key_permissions honestk u_d.(key_heap)
                  ; protocol := u_d.(protocol)
                  ; msg_heap := clean_messages honestk u_d.(msg_heap)
                  ; c_heap   := u_d.(c_heap) |}) usrs.

  Lemma clean_users_notation :
    forall {A} (usrs : honest_users A),
      map (fun u_d => {| key_heap := clean_key_permissions honestk u_d.(key_heap)
                    ; protocol := u_d.(protocol)
                    ; msg_heap := clean_messages honestk u_d.(msg_heap)
                    ; c_heap   := u_d.(c_heap) |}) usrs = clean_users usrs.
  Proof. unfold clean_users; trivial. Qed.

  Lemma clean_users_cleans_user :
    forall {A} (usrs : honest_users A) u_id u_d u_d',
      usrs $? u_id = Some u_d
      -> u_d' = {| key_heap := clean_key_permissions honestk u_d.(key_heap)
                ; protocol := u_d.(protocol)
                ; msg_heap :=  clean_messages honestk u_d.(msg_heap)
                ; c_heap   := u_d.(c_heap) |}
      -> clean_users usrs $? u_id = Some u_d'.
  Proof.
    intros.
    unfold clean_users; rewrite map_o; unfold option_map;
      context_map_rewrites; subst; auto.
  Qed.

  Lemma clean_users_cleans_user_inv :
    forall {A} (usrs : honest_users A) u_id u_d,
      clean_users usrs $? u_id = Some u_d
      -> exists msgs perms,
        usrs $? u_id = Some {| key_heap := perms
                             ; protocol := u_d.(protocol)
                             ; msg_heap := msgs
                             ; c_heap   := u_d.(c_heap) |}
        /\ u_d.(key_heap) = clean_key_permissions honestk perms
        /\ u_d.(msg_heap) = clean_messages honestk msgs.
  Proof.
    intros.
    unfold clean_users in *. rewrite map_o in H. unfold option_map in *.
    cases (usrs $? u_id); try discriminate; eauto.
    destruct u; destruct u_d; simpl in *.
    invert H.
    eexists; eauto.
  Qed.

  Lemma clean_users_add_pull :
    forall {A} (usrs : honest_users A) u_id u,
      clean_users (usrs $+ (u_id,u))
      = clean_users usrs $+ (u_id, {| key_heap := clean_key_permissions honestk u.(key_heap)
                                    ; protocol := u.(protocol)
                                    ; msg_heap :=  clean_messages honestk u.(msg_heap)
                                    ; c_heap   := u.(c_heap) |}).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (y ==n u_id); subst; clean_map_lookups; eauto;
      unfold clean_users; rewrite !map_o; unfold option_map; clean_map_lookups; auto.
  Qed.

  Lemma clean_users_adds_no_users :
    forall {A} (usrs : honest_users A) u_id,
      usrs $? u_id = None
      -> clean_users usrs $? u_id = None.
  Proof.
    unfold clean_users; intros.
    rewrite map_o; simpl.
    unfold option_map; context_map_rewrites; trivial.
  Qed.

  Hint Resolve findUserKeys_foldfn_proper findUserKeys_foldfn_transpose
       findUserKeys_foldfn_proper_Equal findUserKeys_foldfn_transpose_Equal.

  Lemma clean_users_idempotent :
    forall {A} (usrs : honest_users A),
      clean_users (clean_users usrs) = clean_users usrs.
  Proof.
    intros; apply map_eq_Equal; unfold Equal; intros.
    case_eq (clean_users usrs $? y); intros.
    - destruct u; simpl in *; eapply clean_users_cleans_user; eauto; simpl.
      apply clean_users_cleans_user_inv in H; split_ex; split_ands.
      destruct H; split_ands; simpl in *; eauto.
      f_equal; subst; eauto using clean_messages_idempotent, clean_key_permissions_idempotent.
    - unfold clean_users in *.
      rewrite map_o in H; unfold option_map in H; cases (usrs $? y); try discriminate.

      rewrite !map_o, Heq; trivial.
  Qed.

End CleanUsers.

Section FindUserKeysCleanUsers.
  Import RealWorld.

  Hint Resolve findUserKeys_foldfn_proper findUserKeys_foldfn_transpose
       findUserKeys_foldfn_proper_Equal findUserKeys_foldfn_transpose_Equal.

  Hint Resolve clean_users_adds_no_users.

  Lemma findUserKeys_add_user :
    forall {A} (usrs : honest_users A) u_id u_d,
      ~ In u_id usrs
      -> findUserKeys (usrs $+ (u_id, u_d)) =
        findUserKeys usrs $k++ key_heap u_d.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    unfold findUserKeys at 1.
    rewrite fold_add; eauto.
  Qed.

  Lemma findUserKeys_clean_users_addnl_keys :
    forall {A} (usrs : honest_users A) honestk ukeys k_id,
      findUserKeys (clean_users honestk usrs) $? k_id = Some true
      -> findUserKeys (clean_users (honestk $k++ ukeys) usrs) $? k_id = Some true.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; contra_map_lookup; auto.
    rewrite clean_users_add_pull; simpl.
    unfold findUserKeys at 1.
    rewrite fold_add; clean_map_lookups; eauto.
    simpl; rewrite findUserKeys_notation.
    rewrite clean_users_add_pull in H;
      unfold findUserKeys in H; rewrite fold_add in H; clean_map_lookups; eauto.
    simpl in *; rewrite findUserKeys_notation in H.
    apply merge_perms_split in H; split_ors.
    - specialize (IHusrs H);
        cases (clean_key_permissions (honestk $k++ ukeys) (key_heap e) $? k_id);
        simplify_key_merges; eauto.
    - assert (clean_key_permissions (honestk $k++ ukeys) (key_heap e) $? k_id = Some true).
      eapply clean_key_permissions_inv in H; split_ands.
      eapply clean_key_permissions_keeps_honest_permission; eauto.
      unfold honest_perm_filter_fn; context_map_rewrites; trivial.
      unfold honest_perm_filter_fn in H1.
      cases (honestk $? k_id); cases (ukeys $? k_id);
        try discriminate;
        simplify_key_merges1;
        eauto.
      destruct b; try discriminate; eauto.
      cases (findUserKeys (clean_users (honestk $k++ ukeys) usrs) $? k_id); simplify_key_merges; eauto.
  Qed.

  Hint Resolve findUserKeys_clean_users_addnl_keys.

  Lemma clean_users_no_change_honestk :
    forall {A} (usrs : honest_users A) k_id,
      findUserKeys usrs $? k_id = Some true
      -> findUserKeys (clean_users (findUserKeys usrs) usrs) $? k_id = Some true.
  Proof.
    intros.
    unfold clean_users.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; eauto.
    rewrite clean_users_notation in *.
    unfold findUserKeys in H; rewrite fold_add in H; eauto;
      rewrite findUserKeys_notation in H.
    remember (findUserKeys (usrs $+ (x,e))) as honestk.
    rewrite clean_users_add_pull.
    unfold findUserKeys at 1.
    rewrite fold_add; clean_map_lookups; eauto using clean_users_adds_no_users;
      simpl; rewrite findUserKeys_notation.

    apply merge_perms_split in H; split_ors.
    - specialize (IHusrs H).
      assert (findUserKeys (clean_users honestk usrs) $? k_id = Some true).
      subst.
      rewrite findUserKeys_add_user; eauto.
      cases (clean_key_permissions honestk (key_heap e) $? k_id); simplify_key_merges; eauto.

    - assert ( honestk $? k_id = Some true )
        by (subst; eapply findUserKeys_has_private_key_of_user with (u_id := x); clean_map_lookups; eauto).
      assert (clean_key_permissions honestk (key_heap e) $? k_id = Some true).
      eapply clean_key_permissions_keeps_honest_permission; eauto.
      unfold honest_perm_filter_fn; context_map_rewrites; trivial.
      cases (findUserKeys (clean_users honestk usrs) $? k_id); simplify_key_merges; eauto.
  Qed.

  Lemma clean_users_removes_non_honest_keys :
    forall {A} (usrs : honest_users A) k_id u_id u_d,
      findUserKeys usrs $? k_id = Some false
      -> clean_users (findUserKeys usrs) usrs $? u_id = Some u_d
      -> key_heap u_d $? k_id = None.
  Proof.
    intros.
    eapply clean_users_cleans_user_inv in H0; eauto; split_ex; split_ands.
    rewrite H1.
    cases (x0 $? k_id).
    - eapply clean_key_permissions_drops_dishonest_permission; eauto.
      unfold honest_perm_filter_fn; rewrite H; trivial.
    - eapply clean_key_permissions_adds_no_permissions; auto.
  Qed.

  Lemma findUserKeys_clean_users_removes_non_honest_keys :
    forall {A} (usrs : honest_users A) honestk k_id,
      honestk $? k_id = Some false
      -> findUserKeys (clean_users honestk usrs) $? k_id = None.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; eauto.
    rewrite clean_users_add_pull.
    unfold findUserKeys; rewrite fold_add; clean_map_lookups; eauto.
    rewrite findUserKeys_notation; simpl.
    assert (clean_key_permissions honestk (key_heap e) $? k_id = None).
    cases (key_heap e $? k_id).
    eapply clean_key_permissions_drops_dishonest_permission; eauto.
    unfold honest_perm_filter_fn; context_map_rewrites; trivial.
    eapply clean_key_permissions_adds_no_permissions; auto.
    simplify_key_merges; eauto.
  Qed.

  Lemma findUserKeys_clean_users_removes_non_honest_keys' :
    forall {A} (usrs : honest_users A) honestk k_id,
      honestk $? k_id = None
      -> findUserKeys (clean_users honestk usrs) $? k_id = None.
  Proof.
    intros.
    induction usrs using P.map_induction_bis; intros; Equal_eq; subst; eauto.
    rewrite clean_users_add_pull.
    unfold findUserKeys; rewrite fold_add; clean_map_lookups; eauto.
    rewrite findUserKeys_notation; simpl.
    assert (clean_key_permissions honestk (key_heap e) $? k_id = None).
    cases (key_heap e $? k_id).
    eapply clean_key_permissions_drops_dishonest_permission; eauto.
    unfold honest_perm_filter_fn; context_map_rewrites; trivial.
    eapply clean_key_permissions_adds_no_permissions; auto.
    simplify_key_merges; eauto.
  Qed.

  Lemma findUserKeys_clean_users_correct :
    forall {A} (usrs : honest_users A) k_id,
      match findUserKeys usrs $? k_id with
      | Some true => findUserKeys (clean_users (findUserKeys usrs) usrs) $? k_id = Some true
      | _ => findUserKeys (clean_users (findUserKeys usrs) usrs) $? k_id = None
      end.
  Proof.
    intros.
    cases (findUserKeys usrs $? k_id); try destruct b;
      eauto using
            findUserKeys_clean_users_removes_non_honest_keys
          , findUserKeys_clean_users_removes_non_honest_keys'
          , clean_users_no_change_honestk.
  Qed.

  Lemma clean_key_permissions_ok_extra_user_cleaning :
    forall {A} (usrs : honest_users A) perms,
      clean_key_permissions (findUserKeys usrs) perms =
      clean_key_permissions (findUserKeys (clean_users (findUserKeys usrs) usrs)) (clean_key_permissions (findUserKeys usrs) perms).
  Proof.
    intros; symmetry.
    apply map_eq_Equal; unfold Equal; intros.
    case_eq (clean_key_permissions (findUserKeys usrs) perms $? y); intros.
    - apply clean_key_permissions_inv in H; split_ands.
      apply clean_key_permissions_keeps_honest_permission; eauto.
      apply clean_key_permissions_keeps_honest_permission; eauto.
      unfold honest_perm_filter_fn in *.
      cases (findUserKeys usrs $? y); try discriminate; destruct b0; try discriminate.
      pose proof (findUserKeys_clean_users_correct usrs y) as CORRECT.
      rewrite Heq in CORRECT.
      rewrite CORRECT; trivial.
    - apply clean_key_permissions_adds_no_permissions; eauto.
  Qed.

  Lemma clean_messages_ok_extra_user_cleaning :
    forall {A} (usrs : honest_users A) msgs,
      clean_messages (findUserKeys usrs) msgs =
      clean_messages (findUserKeys (clean_users (findUserKeys usrs) usrs)) (clean_messages (findUserKeys usrs) msgs).
  Proof.
    induction msgs; eauto; simpl;
      rewrite IHmsgs.
    case_eq ( msg_filter (findUserKeys usrs) a ); intros.
    - assert (msg_filter (findUserKeys (clean_users (findUserKeys usrs) usrs)) a = true).
      unfold msg_filter, msg_honestly_signed, honest_keyb in *; destruct a;
        destruct c; try discriminate.
      + cases (findUserKeys usrs $? k__sign); try discriminate; destruct b; try discriminate.
        assert (findUserKeys (clean_users (findUserKeys usrs) usrs) $? k__sign = Some true).
        pose proof (findUserKeys_clean_users_correct usrs k__sign).
        rewrite Heq in H0; eauto.
        rewrite H0; trivial.
      + cases (findUserKeys usrs $? k); try discriminate; destruct b; try discriminate.
        assert (findUserKeys (clean_users (findUserKeys usrs) usrs) $? k = Some true).
        pose proof (findUserKeys_clean_users_correct usrs k).
        rewrite Heq in H0; eauto.
        rewrite H0; trivial.
      + simpl. rewrite H0. rewrite <- IHmsgs. rewrite <- IHmsgs; trivial.
    - rewrite <- !IHmsgs; trivial.
  Qed.

  Hint Resolve
       clean_key_permissions_ok_extra_user_cleaning
       clean_messages_ok_extra_user_cleaning.

  Lemma clean_users_idempotent' :
    forall {A} (usrs : honest_users A),
      clean_users (findUserKeys (clean_users (findUserKeys usrs) usrs)) (clean_users (findUserKeys usrs) usrs) =
      clean_users (findUserKeys usrs) usrs.
  Proof.
    intros; apply map_eq_Equal; unfold Equal; intros.
    case_eq (clean_users (findUserKeys usrs) usrs $? y); intros.
    - apply clean_users_cleans_user_inv in H; split_ex; split_ands.
      destruct u; simpl in *.
      eapply clean_users_cleans_user; eauto.
      eapply clean_users_cleans_user; eauto.
      f_equal; simpl; subst; eauto.

    - unfold clean_users in H; rewrite map_o in H; unfold option_map in H.
      cases (usrs $? y); try discriminate.
      apply clean_users_adds_no_users; eauto.
  Qed.

  Lemma clean_keys_ok_extra_user_cleaning :
    forall {A} (usrs : honest_users A) gks,
      clean_keys (findUserKeys usrs) gks =
      clean_keys (findUserKeys (clean_users (findUserKeys usrs) usrs)) (clean_keys (findUserKeys usrs) gks).
  Proof.
    intros; symmetry.
    apply map_eq_Equal; unfold Equal; intros.
    case_eq (clean_keys (findUserKeys usrs) gks $? y); intros.
    - generalize (clean_keys_inv _ _ _ H); intros; split_ands.
      apply clean_keys_keeps_honest_key; eauto.
      unfold honest_key_filter_fn in *.
      cases (findUserKeys usrs $? y); try discriminate; destruct b; try discriminate.
      pose proof (findUserKeys_clean_users_correct usrs y) as CORRECT.
      rewrite Heq in CORRECT.
      rewrite CORRECT; trivial.
    - apply clean_keys_adds_no_keys; eauto.
  Qed.

  Lemma clean_ciphers_ok_extra_user_cleaning :
    forall {A} (usrs : honest_users A) cs,
      clean_ciphers (findUserKeys usrs) cs =
      clean_ciphers (findUserKeys (clean_users (findUserKeys usrs) usrs)) (clean_ciphers (findUserKeys usrs) cs).
  Proof.
    intros; symmetry.
    apply map_eq_Equal; unfold Equal; intros.
    case_eq (clean_ciphers (findUserKeys usrs) cs $? y); intros.
    - apply clean_ciphers_keeps_honest_cipher; eauto.
      rewrite <- find_mapsto_iff in H; apply clean_ciphers_mapsto_iff in H; split_ands.
      rewrite find_mapsto_iff in H.
      unfold honest_cipher_filter_fn, cipher_honestly_signed, honest_keyb in *.
      destruct c.
      + cases (findUserKeys usrs $? k_id); try discriminate; destruct b; try discriminate.
        pose proof (findUserKeys_clean_users_correct usrs k_id) as CORRECT.
        rewrite Heq in CORRECT.
        rewrite CORRECT; trivial.
      + cases (findUserKeys usrs $? k__sign); try discriminate; destruct b; try discriminate.
        pose proof (findUserKeys_clean_users_correct usrs k__sign) as CORRECT.
        rewrite Heq in CORRECT.
        rewrite CORRECT; trivial.
    - apply clean_ciphers_no_new_ciphers; eauto.
  Qed.

  (* Lemma clean_users_no_change_findUserKeys : *)
  (*   forall {A} (usrs : honest_users A), *)
  (*     findUserKeys (clean_users usrs) = findUserKeys usrs. *)
  (* Proof. *)
  (*   induction usrs using P.map_induction_bis; intros; Equal_eq; contra_map_lookup; auto. *)
  (*   unfold findUserKeys. *)
  (*   rewrite fold_add; auto. *)
  (*   rewrite clean_users_add_pull; auto. simpl. *)
  (*   apply map_eq_Equal; unfold Equal; intros. *)
  (*   rewrite !fold_add; auto. simpl. *)
  (*   rewrite !findUserKeys_notation, IHusrs; trivial. *)

  (*   unfold not; intros. *)
  (*   admit. *)
  (*   apply map_in_iff in H0; contradiction. *)
  (* Qed. *)
End FindUserKeysCleanUsers.

Section StripAdv.
  Import RealWorld.

  Definition clean_adv {B} (adv : user_data B) (honestk : key_perms) (b : B) :=
    {| key_heap := clean_key_permissions honestk adv.(key_heap)
     ; protocol := Return b
     ; msg_heap := []
     ; c_heap   := [] |}.

  Definition strip_adversary_univ {A B} (U__r : universe A B) (b : B) : universe A B :=
    let honestk := findUserKeys U__r.(users)
    in {| users       := clean_users honestk U__r.(users)
        ; adversary   := clean_adv U__r.(adversary) honestk b
        (* ; adversary   := {| key_heap := U__r.(adversary).(key_heap) *)
        (*                   ; protocol := Return b *)
        (*                   ; msg_heap := U__r.(adversary).(msg_heap) *)
        (*                   ; c_heap   := U__r.(adversary).(c_heap) |} *)
        ; all_ciphers := clean_ciphers honestk U__r.(all_ciphers)
        ; all_keys    := clean_keys honestk U__r.(all_keys)
       |}.

  Definition strip_adversary {A B} (U__r : universe A B) : simpl_universe A :=
    let honestk := findUserKeys U__r.(users)
    in {| s_users       := clean_users honestk U__r.(users)
        ; s_all_ciphers := clean_ciphers honestk U__r.(all_ciphers)
        ; s_all_keys    := clean_keys honestk U__r.(all_keys)
       |}.

  Definition strip_adversary_simpl {A} (U__r : simpl_universe A) : simpl_universe A :=
    let honestk := findUserKeys U__r.(s_users)
    in {| s_users       := clean_users honestk U__r.(s_users)
        ; s_all_ciphers := clean_ciphers honestk U__r.(s_all_ciphers)
        ; s_all_keys    := clean_keys honestk U__r.(s_all_keys)
       |}.

  Definition strip_action (honestk : key_perms) (act : action) :=
    match act with
    | Input msg pat perms => Input msg pat (clean_key_permissions honestk perms)
    | output              => output
    end.

  Definition strip_label (honestk : key_perms) (lbl : label) :=
    match lbl with
    | Silent => Silent
    | Action a => Action (strip_action honestk a)
    end.

  Lemma peel_strip_univ_eq_strip_adv :
    forall A B (U : universe A B) b,
      peel_adv (strip_adversary_univ U b) = strip_adversary U.
  Proof.
    unfold peel_adv, strip_adversary, strip_adversary_univ; trivial.
  Qed.

End StripAdv.