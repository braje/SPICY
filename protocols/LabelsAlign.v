(* DISTRIBUTION STATEMENT A. Approved for public release. Distribution is unlimited.
 *
 * This material is based upon work supported by the Department of the Air Force under Air Force
 * Contract No. FA8702-15-D-0001. Any opinions, findings, conclusions or recommendations expressed
 * in this material are those of the author(s) and do not necessarily reflect the views of the
 * Department of the Air Force.
 *
 * © 2020 Massachusetts Institute of Technology.
 *
 * MIT Proprietary, Subject to FAR52.227-11 Patent Rights - Ownership by the contractor (May 2014)
 *
 * The software/firmware is provided to you on an As-Is basis
 *
 * Delivered to the U.S. Government with Unlimited Rights, as defined in DFARS Part 252.227-7013
 * or 7014 (Feb 2014). Notwithstanding any copyright notice, U.S. Government rights in this work are
 * defined by DFARS 252.227-7013 or DFARS 252.227-7014 as detailed above. Use of this work other than
 * as specifically authorized by the U.S. Government may violate any copyrights that exist in this work. *)

From Coq Require Import
     Classical
     List.

From KeyManagement Require Import
     MyPrelude
     Common
     Automation
     Maps
     Keys
     KeysTheory
     Messages
     Tactics
     Simulation
     RealWorld
     SyntacticallySafe
     AdversarySafety.

From protocols Require Import
     ExampleProtocols
     ProtocolAutomation
     ModelCheck
     SafeProtocol
     RealWorldStepLemmas
.

Require IdealWorld.

Set Implicit Arguments.

(* forall reachable states labels align *)
Inductive labels_always_align {A B} : (universe A B * IdealWorld.universe A) -> Prop :=
| StepLabelsAlign : 
    forall st,
      (forall st', step st st' -> labels_always_align st')
      -> labels_align st
      -> labels_always_align st.

Definition stuck_step_implies_stuck_universe_step {t__hon t__adv}
           (st : universe t__hon t__adv * IdealWorld.universe t__hon) : Prop :=
  (forall st', step st st' -> False)
  -> forall lbl ru',
    step_universe (fst st) lbl ru' -> False.


(* Definition almostEqual {A}  (ud ud' : user_data A) := *)
(*   ud = ud' \/ *)
(*   (exists msg, ud =  *)
(*   {| *)
(*   key_heap := key_heap ud'; *)
(*   protocol := protocol ud'; *)
(*   msg_heap := msg_heap ud' ++ [msg]; *)
(*   c_heap := c_heap ud'; *)
(*   from_nons := from_nons ud'; *)
(*   sent_nons := sent_nons ud'; *)
(*   cur_nonce := cur_nonce ud' |}). *)

(* Lemma non_stepped_ud_almost_equal : *)
(*   forall { A B C } suid lbl bd1 bd2, *)
(*     step_user lbl suid bd1 bd2 *)
(*     -> forall (users1 users2 : honest_users A) (adv1 adv2 : user_data B) cs1 cs2 gks1 gks2 *)
(*         stepper ks1 ks2 qmsgs1 qmsgs2 mycs1 mycs2 froms1 froms2 sents1 sents2 cur_n1 cur_n2 *)
(*         (cmdc1 cmdc2 : user_cmd C) cmd1, *)
(*       bd1 = (users1, adv1, cs1, gks1, ks1, qmsgs1, mycs1, froms1, sents1, cur_n1, cmdc1) *)
(*       -> bd2 = (users2, adv2, cs2, gks2, ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmdc2) *)
(*       -> suid = Some stepper *)
(*     -> users1 $? stepper = Some {| key_heap := ks1 *)
(*                                ; protocol := cmd1 *)
(*                                ; msg_heap := qmsgs1 *)
(*                                ; c_heap := mycs1 *)
(*                                ; from_nons := froms1 *)
(*                                ; sent_nons := sents1 *)
(*                                ; cur_nonce := cur_n1 |} *)
(*     -> (forall uid ud1 ud2, *)
(*           uid <> stepper *)
(*           -> users1 $? uid = Some ud1 *)
(*           -> users2 $? uid = Some ud2 *)
(*           -> almostEqual ud2 ud1). *)
(* Proof. *)
(*   induct 1; inversion 1; inversion 1; intros; subst; clean_context; clean_map_lookups; eauto; unfold almostEqual; eauto. *)
  
(*   destruct (rec_u_id ==n uid); subst; clean_map_lookups; eauto. *)
(* Qed. *)

(* Lemma different_steps_must_be_by_different_users : *)
(*   forall { A B C } (bd1 bd2 bd__other : data_step0 A B C ) lbl1 lbl2 u_id1 u_id2, *)
(*     (* lameAdv b bd1.(adversary) *) *)
(*     step_user lbl1 (Some u_id1) bd1 bd2 *)
(*     -> step_user lbl2 (Some u_id2) bd1 bd__other *)
(*     -> lbl1 <> lbl2 *)
(*     -> u_id1 <> u_id2. *)
(* Proof. *)
(*   (* inversion 2; inversion 1; intros; subst; eauto. *) *)

(*   (* destruct ru1.  unfold build_data_step in *. destruct userData. destruct userData0. simpl in *. *) *)
(*   (* clean_map_lookups. *) *)
(*   (* destruct ru1. destruct adversary. simpl in *. unfold build_data_step in *. simpl in *. *) *)
(*   (* rewrite H in H8. invert H8. admit. admit. *) *)
(* Admitted. *)



        (* relation between ru__other ru'' : only A and global state are different *)
(* Definition only_global_or_single_user_state_changed {A B C} (bd1 bd2 : data_step0 A B C) (u_id : user_id) := *)
(*   forall u_id' u_d1 u_d2 ru1 ru2, *)
(*     ru1.(users) $? u_id' = Some u_d1 *)
(*     -> bd1 = build_data_step ru1 u_d1 *)
(*     -> ru2.(users) $? u_id' = Some u_d2 *)
(*     -> u_id' <> u_id *)
(*     -> u_d1 = u_d2. *)

(* Lemma silent_leading_step_preserves_action_matches : *)
(*   forall {A B C} (* (ru ru' ru__other : RealWorld.universe A B) *) ra u_id1 u_id2 (bd bd' bd__other : data_step0 A B C), *)
(*     (* ru = buildUniverse_step bd u_id1 *) *)
(*      step_user Silent (Some u_id1) bd bd' *)
(*      (* -> step_universe ru Silent ru' *) *)
(*      (* -> bd = build_data_step  *) *)
(*     -> step_user (Action ra) (Some u_id2) bd bd__other *)
(*     -> forall (users1 users2 : honest_users A) (adv1 adv2 : user_data B) cs1 cs2 gks1 gks2 *)
(*          ks1 ks2 qmsgs1 qmsgs2 mycs1 mycs2 froms1 froms2 sents1 sents2 cur_n1 cur_n2 *)
(*         (cmdc1 cmdc2 : user_cmd C), *)
(*       bd = (users1, adv1, cs1, gks1, ks1, qmsgs1, mycs1, froms1, sents1, cur_n1, cmdc1) *)
(*       -> bd' = (users2, adv2, cs2, gks2, ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmdc2) *)
(*     -> exists bd'' , *)
(*         step_user (Action ra) (Some u_id2) bd' bd'' *)
(*         -> only_global_or_single_user_state_changed bd__other bd'' u_id1. *)
(*         (* -> action_matches (buildUniverse_step bd') ra iu ia = action_matches (buildUniverse_step bd'') ra iu ia. *) *)
(* Proof. *)
(*   induction 1; inversion 2; inversion 1; intros; subst; eauto. *)
(*   clear H1. clear H2. eexists.  *)
  
  
(* Lemma silent_step_blah :      *)
(*   forall {A B C} suid lbl bd bd', *)
(*     step_user lbl suid bd bd' *)
(*     -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks' *)
(*         (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs' *)
(*         froms froms' sents sents' cur_n cur_n', *)
(*       bd = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd) *)
(*       -> bd' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd') *)
(*       -> lbl = Silent *)
(*       -> forall cmdc cmdc' u_id1 u_id2 ud2 usrs'', *)
(*           suid = Some u_id1 *)
(*           -> u_id1 <> u_id2 *)
(*           -> usrs $? u_id1 = Some {| key_heap := ks; *)
(*                                     protocol := cmdc; *)
(*                                     msg_heap := qmsgs; *)
(*                                     c_heap   := mycs; *)
(*                                     from_nons := froms; *)
(*                                     sent_nons := sents; *)
(*                                     cur_nonce := cur_n |} *)
(*           -> usrs $? u_id2 = Some ud2 *)
(*           -> usrs'' = usrs' $+ (u_id1, {| key_heap := ks'; *)
(*                                          protocol := cmdc'; *)
(*                                          msg_heap := qmsgs'; *)
(*                                          c_heap   := mycs'; *)
(*                                          from_nons := froms'; *)
(*                                          sent_nons := sents'; *)
(*                                          cur_nonce := cur_n' |}) *)
(*           -> usrs'' $? u_id2 = Some ud2. *)
(* Proof. *)
(*   induction 1; inversion 1; inversion 1; *)
(*     intros; subst; *)
(*       try discriminate; *)
(*       try solve [ clean_map_lookups; trivial ]. *)
(*   specialize (IHstep_user _ _ _ _ _ _ _ _ _ _ _ *)
(*                           _ _ _ _ _ _ _ _ _ _ _ *)
(*                           eq_refl eq_refl eq_refl). *)
(*   specialize (IHstep_user cmdc cmdc'). *)
(*   specialize (IHstep_user _ _ _ _ eq_refl H26 H27 H28 eq_refl). *)
(*   clean_map_lookups; eauto. *)
(* Qed. *)

Lemma syntactically_safe_honest_keys_' :
  forall {A B C} suid lbl bd bd',

    step_user lbl suid bd bd'

    -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks'
        (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs'
        froms froms' sents sents' cur_n cur_n' (* ctx sty *),

      (* how do I get msg introduced? *)

      bd = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
      -> bd' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd')

      -> forall honestk honestk' cmdc cmdc' u_id,
          suid = Some u_id
          (* -> syntactically_safe u_id ctx cmd sty *)
          -> usrs $? u_id = Some {| key_heap := ks;
                                   protocol := cmdc;
                                   msg_heap := qmsgs;
                                   c_heap   := mycs;
                                   from_nons := froms;
                                   sent_nons := sents;
                                   cur_nonce := cur_n |}
          (* -> Vjtypechecker_sound ctx honestk cs u_id *)
          -> honestk  = findUserKeys usrs
          -> message_queue_ok honestk cs qmsgs gks
          -> encrypted_ciphers_ok honestk cs gks
          -> honest_users_only_honest_keys usrs
          -> honestk' = findUserKeys (usrs' $+ (u_id, {| key_heap := ks';
                                                        protocol := cmdc';
                                                        msg_heap := qmsgs';
                                                        c_heap   := mycs';
                                                        from_nons := froms';
                                                        sent_nons := sents';
                                                        cur_nonce := cur_n' |})).
          (* -> ks' $k++ findKeysMessage msg $? k__sign = ks' $? k__sign. *)
Proof.
Admitted.

(*
Lemma syntactically_safe_pk_in_message_owned_by_some_honest_user :
  forall {A B C} suid lbl bd bd',

    step_user lbl suid bd bd'

    -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks'
        (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs'
        froms froms' sents sents' cur_n cur_n' ctx sty p,

      bd = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, (Recv p))
      -> bd' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', (Return c_id))

      -> cs' $? c_id = Some (SigEncCipher k__signid k__encid msg_to nonce msg)
-> forall honestk honestk' cmdc cmdc' u_id,
          suid = Some u_id
          -> syntactically_safe u_id ctx cmd sty
          -> usrs $? u_id = Some {| key_heap := ks;
                                   protocol := cmdc;
                                   msg_heap := qmsgs;
                                   c_heap   := mycs;
                                   from_nons := froms;
                                   sent_nons := sents;
                                   cur_nonce := cur_n |}
          -> typechecker_sound ctx honestk cs u_id
          -> honestk  = findUserKeys usrs
          -> message_queue_ok honestk cs qmsgs gks
          -> encrypted_ciphers_ok honestk cs gks
          -> honest_users_only_honest_keys usrs
          -> honestk' = findUserKeys (usrs' $+ (u_id, {| key_heap := ks';
                                                        protocol := cmdc';
                                                        msg_heap := qmsgs';
                                                        c_heap   := mycs';
                                                        from_nons := froms';
                                                        sent_nons := sents';
                                                        cur_nonce := cur_n' |}))

    findKeysMessage msg $? k__sign = Some true ->
    (exists (u : Map.key),
        (forall data__rw data__iw,
            usrs' $? u = Some data__rw
            -> IdealWorld.users ui $? u = Some data__iw
            -> honest_key (findUserKeys usrs') k__sign
            -> key_heap data__rw $? k__sign = Some true))
.*)


(* Lemma silent_step_then_labeled_step :  *)
(*   forall {A B C} suid lbl bd bd', *)
(*     step_user lbl suid bd bd' *)
(*     -> forall cs cs' (usrs usrs' usrs'': honest_users A) (adv adv' : user_data B) gks gks' *)
(*         (cmd cmd' : user_cmd C) u_id1 cmdc cmdc' *)
(*         ks ks' qmsgs qmsgs' mycs mycs' *)
(*         froms froms' sents sents' cur_n cur_n' suid2 lbl2, *)
(*       bd = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd) *)
(*       -> bd' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd') *)
(*       -> lbl = Silent *)
(*       -> usrs $? u_id1 = Some {| key_heap := ks; *)
(*                                 protocol := cmdc; *)
(*                                 msg_heap := qmsgs; *)
(*                                 c_heap   := mycs; *)
(*                                 from_nons := froms; *)
(*                                 sent_nons := sents; *)
(*                                 cur_nonce := cur_n |} *)
(*       -> usrs'' = users' $+ (u_id1, {| key_heap := ks'; *)
(*                                 protocol := cmdc'; *)
(*                                 msg_heap := qmsgs'; *)
(*                                 c_heap   := mycs'; *)
(*                                 from_nons := froms'; *)
(*                                 sent_nons := sents'; *)
(*                                 cur_nonce := cur_n' |}) *)
(*       -> forall D bd2 bd2', *)
(*           step_user lbl2 suid2 bd2 bd2' *)
(*           -> forall cmdc2 u_id2 ru ia iu ra *)
(*               (cmd2 cmd2' : user_cmd D) ks2 ks2' qmsgs2 qmsgs2' mycs2 mycs2' *)
(*               froms2 froms2' sents2 sents2' cur_n2 cur_n2', *)
(*             suid = Some u_id1 *)
(*             -> suid2 = Some u_id2 *)
(*             -> lbl2 = Action ra *)
(*             -> bd2 = (usrs'', adv', cs', gks', ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmd2) *)
(*             -> bd2' = (usrs''', adv'', cs'', gks'', ks2', qmsgs2', mycs2', froms2', sents2', cur_n2', cmd2') *)
(*             -> u_id1 <> u_id2 *)
(*             -> ru = buildUniverse usrs adv cs gks u_id1 {| key_heap  := ks *)
(*                                                           ; msg_heap  := qmsgs *)
(*                                                           ; protocol  := cmdc *)
(*                                                           ; c_heap    := mycs *)
(*                                                           ; from_nons := froms *)
(*                                                           ; sent_nons := sents *)
(*                                                           ; cur_nonce := cur_n |} *)
(*             -> action_matches ra ru ia iu *)
(*             -> usrs $? u_id2 = Some {| key_heap := ks2; *)
(*                                       protocol := cmdc2; *)
(*                                       msg_heap := qmsgs2; *)
(*                                       c_heap   := mycs2; *)
(*                                       from_nons := froms2; *)
(*                                       sent_nons := sents2; *)
(*                                       cur_nonce := cur_n2 |} *)
(*             -> forall ru', *)
(*                   (* step_user (Action ra) (Some u_id2) *) *)
(*                   (*           (usrs'', adv', cs', gks', ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmd2) *) *)
(*                   (*           bd2'' *) *)
(*                   ru' = buildUniverse usrs' adv' cs' gks' u_id1 {| key_heap  := ks' *)
(*                                                                      ; msg_heap  := qmsgs' *)
(*                                                                      ; protocol  := cmdc' *)
(*                                                                      ; c_heap    := mycs' *)
(*                                                                      ; from_nons := froms' *)
(*                                                                      ; sent_nons := sents' *)
(*                                                                      ; cur_nonce := cur_n' |} *)
(*                   ->  action_matches ra ru' ia iu. *)
(* Proof. *)
(*   induction 6; inversion 4; inversion 1; intros; subst; try discriminate; clean_context. *)
(*   - specialize (IHstep_user _ _ H). *)
(*     specialize (IHstep_user _ _ _ _ _ cmdc' eq_refl eq_refl H3). *)
(*     specialize (IHstep_user _ _ _ _ _ _ _ _ _ _ *)
(*                             _ _ _ _ _ _ _ _ _ _ *)
(*                             eq_refl eq_refl eq_refl eq_refl eq_refl H21 eq_refl H34 H35). *)
(*     eapply IHstep_user; eauto. *)
(*   - generalize H; intros STEP1. *)
(*     eapply silent_step_blah in H; eauto. *)
(*     clean_map_lookups. *)
(*     invert H41; eauto. *)
(*     econstructor; eauto. *)
(*     invert H1. *)
(*     unfold buildUniverse in *; simpl in *. *)
(*     eapply silent_step_message_eq with (u_id3 := u_id1); eauto. *)
(*   - generalize H; intros STEP1. *)
(*     eapply silent_step_blah in H; eauto. *)
(*     clean_map_lookups. *)
(*     invert H41; eauto. *)
(*     eapply Out; eauto. *)
(*     invert H2. *)
(*     unfold buildUniverse in *; simpl in *. *)
(*     eapply silent_step_message_eq with (u_id3 := u_id1); eauto. *)
(*     Unshelve. *)
(*     all: try discriminate; eauto. *)
(* Qed. *)



(*   inversion 1;  intros; subst; eauto; simpl in *. *)
(*   (* inversion 3; inversion 2;  intros; subst; eauto; simpl in *.  *) *)
(*   (* eexists. destruct (nextStep cmd). *) *)
(*   (* invert H13. destruct iu; simpl in *. econstructor. *) *)
(*   (* eauto. eauto. eauto.  *) *)
(* Admitted. *)
  Lemma commutes_sound_recur_cmd1' :
    forall {A B C D} suid1 u_id1 lbl1 (bd1 bd1' : data_step0 A B C),

      step_user lbl1 suid1 bd1 bd1'
      -> suid1 = Some u_id1
      -> forall (bd2 bd2' : data_step0 A B D) lbl2 suid2 u_id2,

          step_user lbl2 suid2 bd2 bd2'
          -> suid2 = Some u_id2
          -> u_id1 <> u_id2

          -> forall cs cs1 cs' (usrs1 usrs1' usrs2 usrs2' : honest_users A) (adv adv1 adv' : user_data B) gks gks1 gks'
              ks1 ks1' qmsgs1 qmsgs1' mycs1 mycs1' cmd1 cmd1' froms1 froms1' sents1 sents1' cur_n1 cur_n1'
              ks2 ks2' qmsgs2 qmsgs2' mycs2 mycs2' cmd2 cmd2' froms2 froms2' sents2 sents2' cur_n2 cur_n2'
              cmdc1 cmdc1' cmdc2 qmsgs2'',

              bd1  = (usrs1,  adv,  cs,  gks,  ks1, qmsgs1, mycs1, froms1, sents1, cur_n1, cmd1)
              -> bd1' = (usrs1', adv1, cs1, gks1, ks1', qmsgs1', mycs1', froms1', sents1', cur_n1', cmd1')
              -> bd2  = (usrs2,  adv1, cs1, gks1, ks2, qmsgs2'', mycs2, froms2, sents2, cur_n2, cmd2)
              -> bd2' = (usrs2', adv', cs', gks', ks2', qmsgs2', mycs2', froms2', sents2', cur_n2', cmd2')
              (* allow protocol to freely vary, since we won't be looking at it *)
              -> usrs1 $? u_id1 = Some (mkUserData ks1 cmdc1 qmsgs1 mycs1 froms1 sents1 cur_n1)
              -> usrs1 $? u_id2 = Some (mkUserData ks2 cmdc2 qmsgs2 mycs2 froms2 sents2 cur_n2)
              -> usrs1' $? u_id2 = Some (mkUserData ks2 cmdc2 qmsgs2'' mycs2 froms2 sents2 cur_n2)
              -> usrs2 = usrs1' $+ (u_id1, mkUserData ks1' cmdc1' qmsgs1' mycs1' froms1' sents1' cur_n1')
              -> encrypted_ciphers_ok (findUserKeys usrs1) cs gks
              -> message_queues_ok cs usrs1 gks
              -> keys_and_permissions_good gks usrs1 adv.(key_heap)
              -> user_cipher_queues_ok cs (findUserKeys usrs1) usrs1
              (* -> next_cmd_safe (findUserKeys usrs1) cs u_id1 froms1 sents1 cmd1 *)
              (* -> next_cmd_safe (findUserKeys usrs1) cs u_id2 froms2 sents2 cmd2 *)
                                  
              (* no recursion *)
              (* -> nextAction cmd1 cmd1 *)
              -> not (nextAction cmd2 cmd2)
              (* -> (forall cmd__n x t (m : crypto t), nextAction cmd1 cmd__n -> cmd__n <> Send x m) *)


              -> forall bd3 cmdc2',
                  bd3 = (usrs1,   adv,  cs,  gks,  ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmd2)
                  -> exists bd3' bd4 bd4' lbl3 lbl4 adv2 cs2 gks2 usrs3' usrs4 usrs4' qmsgs3,
                      step_user lbl3 suid2 bd3 bd3'
                      /\ bd3' = (usrs3', adv2, cs2, gks2, ks2', qmsgs3, mycs2', froms2', sents2', cur_n2', cmd2')
                      /\ usrs4 = usrs3' $+ (u_id2, mkUserData ks2' cmdc2' qmsgs3 mycs2' froms2' sents2' cur_n2')
                      /\ bd4 = (usrs4,   adv2, cs2, gks2, ks1, qmsgs1, mycs1, froms1, sents1, cur_n1, cmd1)
                      /\ bd4' = (usrs4', adv', cs', gks', ks1', qmsgs1', mycs1', froms1', sents1', cur_n1', cmd1')
                      /\ step_user lbl4 suid1 bd4 bd4'
                      /\ ( usrs4' $+ (u_id1, mkUserData ks1' cmdc1' qmsgs1' mycs1' froms1' sents1' cur_n1') = 
                          usrs2' $+ (u_id2, mkUserData ks2' cmdc2' qmsgs2' mycs2' froms2' sents2' cur_n2') )
  .
  Proof.
    induction 1; inversion 5; inversion 1
    ; intros.
    Admitted.

Lemma step_step_recurse_ok :
  forall A B C lbl1 suid1 bd1 bd1',
    step_user lbl1 suid1 bd1 bd1'
    -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks'
        (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs'
        froms froms' sents sents' cur_n cur_n' uid1,
      bd1 = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
      -> bd1' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd')
      -> suid1 = Some uid1
      -> forall cmdc cmdc',
          usrs $? uid1 = Some (mkUserData ks cmdc qmsgs mycs froms sents cur_n)
      -> forall D ks2 qmsgs2 mycs2 froms2 sents2 cur_n2 cmd1 (cmd2 : << D >> -> user_cmd (Base A)) uid2,
          usrs $? uid2 = Some (mkUserData ks2 (Bind cmd1 cmd2) qmsgs2 mycs2 froms2 sents2 cur_n2)
      -> uid1 <> uid2
      -> forall bd2' lbl2 ,
          step_user lbl2 (Some uid2) (usrs, adv, cs, gks, ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, Bind cmd1 cmd2) bd2'
          -> exists lbl3 bd3 qmsgs3,
            usrs' $? uid2 =
            Some
              {| key_heap := ks2;
                 protocol := Bind cmd1 cmd2;
                 msg_heap := qmsgs3;
                 c_heap := mycs2;
                 from_nons := froms2;
                 sent_nons := sents2;
                 cur_nonce := cur_n2 |}
            -> step_user lbl3 (Some uid2)
                        (usrs' $+ (uid1,
                                   {|
                                     key_heap := ks';
                                     protocol := cmdc';
                                     msg_heap := qmsgs';
                                     c_heap := mycs';
                                     from_nons := froms';
                                     sent_nons := sents';
                                     cur_nonce := cur_n' |}), adv', cs', gks', ks2, qmsgs3, mycs2, froms2, sents2, cur_n2, Bind cmd1 cmd2) bd3.
Proof.
  induction 1; inversion 1; inversion 1; intros; subst; eauto.
  - induction H27.
    + admit.
    + admit.
    + do 3 eexists. intros. 
Admitted.


Lemma step_then_step :
  forall A B C lbl1 suid1 bd1 bd1',
    step_user lbl1 suid1 bd1 bd1'
    -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks'
        (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs'
        froms froms' sents sents' cur_n cur_n' uid1,
      bd1 = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
      -> bd1' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd')
      -> suid1 = Some uid1
      -> forall cmdc cmdc',
          usrs $? uid1 = Some (mkUserData ks cmdc qmsgs mycs froms sents cur_n)
      -> forall ks2 qmsgs2 mycs2 froms2 sents2 cur_n2 cmd2 uid2,
          usrs $? uid2 = Some (mkUserData ks2 cmd2 qmsgs2 mycs2 froms2 sents2 cur_n2)
      -> uid1 <> uid2
      -> forall bd2' lbl2 ,
          step_user lbl2 (Some uid2) (usrs, adv, cs, gks, ks2, qmsgs2, mycs2, froms2, sents2, cur_n2, cmd2) bd2'
      -> exists lbl3 bd3 qmsgs3,
            usrs' $? uid2 = Some (mkUserData ks2 cmd2 qmsgs3 mycs2 froms2 sents2 cur_n2)
          -> step_user lbl3 (Some uid2) (usrs' $+ (uid1, (mkUserData ks' cmdc' qmsgs' mycs' froms' sents' cur_n')),
                                        adv', cs', gks', ks2, qmsgs3, mycs2, froms2, sents2, cur_n2, cmd2) bd3.
Proof.
  induction 1; inversion 1; inversion 1; intros; subst; eauto.
  - invert H27. 
    (* + destruct cmd1. *)
    (*   *do 3 eexists; intros; econstructor 2; eauto. *)
    (*   * admit. *)
    (*   * exists lbl2. do 2 eexists. intros. econstructor. admit. *)
    (*   * admit. *)
    (*   * admit *)
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  - invert H27.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  - invert H35.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
      (* Verify? *) 
  - invert H31.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  (* send *)
  - invert H35. 
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto. admit.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
      (* sign enc*)
  - invert H37.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto. admit. admit.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  - invert H36.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  (* sign *)
  - invert H35.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto. admit. admit.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  - invert H31.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto.
  (* gen keys *)
  - invert H31.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto. admit. (* gks *)
    + do 3 eexists; intros; econstructor; eauto. admit.
  - invert H31.
    + admit.
    + do 3 eexists; intros; econstructor 2; eauto.
    + do 3 eexists; intros; econstructor; eauto.
    + destruct (rec_u_id ==n uid1); subst. do 3 eexists; intros. econstructor; eauto.
     do 3 eexists; intros; econstructor; eauto.
    + do 3 eexists; intros; econstructor; eauto. admit. (* gks *)
    + do 3 eexists; intros; econstructor; eauto. admit. 
Admitted.



Lemma labels_align_silent_step' :
  forall A B C suid lbl bd bd',

    step_user lbl suid bd bd'

    -> forall cs cs' (usrs usrs': honest_users A) (adv adv' : user_data B) gks gks'
        (cmd cmd' : user_cmd C) ks ks' qmsgs qmsgs' mycs mycs'
        froms froms' sents sents' cur_n cur_n' uid,

      bd = (usrs, adv, cs, gks, ks, qmsgs, mycs, froms, sents, cur_n, cmd)
      -> bd' = (usrs', adv', cs', gks', ks', qmsgs', mycs', froms', sents', cur_n', cmd')
      -> suid = Some uid
      -> forall cmdc,
          usrs $? uid = Some (mkUserData ks cmdc qmsgs mycs froms sents cur_n)

      -> forall cmdc' iu,
          labels_align ({|
                         users := usrs $+ (uid,
                                           {|
                                             key_heap := ks';
                                             protocol := cmdc';
                                             msg_heap := qmsgs';
                                             c_heap := mycs';
                                             from_nons := froms';
                                             sent_nons := sents';
                                             cur_nonce := cur_n' |});
                         adversary := adv';
                         all_ciphers := cs';
                         all_keys := gks' |}, iu)
       -> labels_align ({|
                         users := usrs;
                         adversary := adv;
                         all_ciphers := cs;
                         all_keys := gks |}, iu).
Proof.
  induction 1; inversion 1; inversion 1; intros; subst; eauto.
  - admit.
  - unfold labels_align in *; intros.
    invert H1; simpl in *.
    destruct userData; unfold build_data_step in *; simpl in *.

Admitted.


Lemma alignment_violation_step' :
  forall t__hon t__adv st st',
    @step t__hon t__adv st st'
    (* -> lameAdv b (fst st).(adversary) *)
    -> labels_always_align st'
    -> labels_always_align st.
Proof.

  induct 1; intros;
    match goal with
    | [ H : labels_always_align _ |- _ ] => invert H
    end.
  - econstructor; intros.
    * econstructor; intros.
      ** admit.
      ** admit.
    * invert H.
      2:admit. (* adversary step, so ignore *)
      unfold buildUniverse in *.
      admit.

  - 
  (* we know that we have stepped from (ru,iu) to (ru',iu).  we know that if the user
   * that stepped was the one from H, then we can use H1 to discharge.
   * However, if it was another user, stepping from (ru,iu) to st', then
   * we need to know that the other user wouldn't have messed us up if it went first, but we
   * know that to be true because of H2 (labels_align (ru',iu)), but we will need to prove that
   * as a lemma  *)


Admitted.

Lemma alignment_violation_step :
  forall t__hon t__adv st st' b,
    @step t__hon t__adv st st'
    -> lameAdv b (fst st).(adversary)
    -> ~ labels_always_align st
    -> ~ labels_always_align st'.
Proof.
  unfold not; intros.
  eauto using alignment_violation_step'.
Qed.

Lemma alignment_violation_steps :
  forall t__hon t__adv st st' b,
    (@step t__hon t__adv)^* st st'
    -> lameAdv b (fst st).(adversary)
    -> ~ labels_always_align st
    -> ~ labels_always_align st'.
Proof.
  induction 1; intros; eauto.

  assert (LAME : lameAdv b (fst y).(adversary)) by eauto using adversary_remains_lame_step.
  destruct x, y, z; simpl in *.

  generalize H; intros VIOL; eapply alignment_violation_step in VIOL; eauto.
Qed.
