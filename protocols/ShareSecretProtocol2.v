(* DISTRIBUTION STATEMENT A. Approved for public release. Distribution is unlimited.
 *
 * This material is based upon work supported by the Department of the Air Force under Air Force 
 * Contract No. FA8702-15-D-0001. Any opinions, findings, conclusions or recommendations expressed 
 * in this material are those of the author(s) and do not necessarily reflect the views of the 
 * Department of the Air Force.
 * 
 * © 2019-2020 Massachusetts Institute of Technology.
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
     List.

Require Import
        MyPrelude
        Maps
        ChMaps
        Messages
        ModelCheck
        Common
        Keys
        Automation
        Tactics
        Simulation
        AdversaryUniverse
        UniverseEqAutomation
        ProtocolAutomation
        SafeProtocol
        ProtocolFunctions.

Require IdealWorld RealWorld.

Import IdealWorld.IdealNotations
       RealWorld.RealWorldNotations
       SimulationAutomation.

Import Sets.
Module Foo <: EMPTY.
End Foo.
Module Import SN := SetNotations(Foo).

Set Implicit Arguments.

Open Scope protocol_scope.

Module ShareSecretProtocol.

  Section IW.
    Import IdealWorld.

    Notation pCH12 := 0.
    Notation pCH21 := 1.
    Notation CH12  := (# pCH12).
    Notation CH21  := (# pCH21).

    Notation empty_chs := (#0 #+ (CH12, []) #+ (CH21, [])).

    Notation PERMS1 := ($0 $+ (pCH12, owner) $+ (pCH21, reader)).
    Notation PERMS2 := ($0 $+ (pCH12, reader) $+ (pCH21, owner)).

    Notation ideal_users :=
      [
        (mkiUsr USR1 PERMS1 
                ( chid <- CreateChannel
                  ; _ <- Send (Permission {| ch_perm := writer ; ch_id := chid |}) CH12
                  ; m <- @Recv Nat (chid #& pCH21)
                  ; @Return (Base Nat) (extractContent m)
        )) ;
      (mkiUsr USR2 PERMS2
              ( m <- @Recv Access CH12
                ; n <- Gen
                ; _ <- let chid := ch_id (extractPermission m)
                      in  Send (Content n) (chid #& pCH21)
                ; @Return (Base Nat) n
      ))
      ].

    Definition ideal_univ_start :=
      mkiU empty_chs ideal_users.

  End IW.

  Section RW.
    Import RealWorld.

    Notation KID1 := 0.
    Notation KID2 := 1.

    Notation KEYS := [ skey KID1 ; skey KID2 ].

    Notation KEYS1 := ($0 $+ (KID1, true) $+ (KID2, false)).
    Notation KEYS2 := ($0 $+ (KID1, false) $+ (KID2, true)).

    Notation real_users :=
      [
        USR1 with KEYS1 >> ( kp <- GenerateAsymKey Encryption
                          ; c1 <- Sign KID1 USR2 (Permission (fst kp, false))
                          ; _  <- Send USR2 c1
                          ; c2 <- @Recv Nat (SignedEncrypted KID2 (fst kp) true)
                          ; m  <- Decrypt c2
                          ; @Return (Base Nat) (extractContent m) ) ;

      USR2 with KEYS2 >> ( c1 <- @Recv Access (Signed KID1 true)
                        ; v  <- Verify KID1 c1
                        ; n  <- Gen
                        ; c2 <- SignEncrypt KID2 (fst (extractPermission (snd v))) USR1 (message.Content n)
                        ; _  <- Send USR1 c2
                        ; @Return (Base Nat) n)
      ].

    Definition real_univ_start :=
      mkrU (mkKeys KEYS) real_users.
  End RW.

  Hint Unfold
       mkiU mkiUsr mkrU mkrUsr
       mkKeys
       real_univ_start
       ideal_univ_start : constants.

  Hint Extern 0 (IdealWorld.lstep_universe _ _ _) =>
    progress(autounfold with constants; simpl).
  
End ShareSecretProtocol.

Module ShareSecretProtocolSecure <: AutomatedSafeProtocol.

  Import ShareSecretProtocol.

  Definition t__hon := Nat.
  Definition t__adv := Unit.
  Definition b := tt.
  Definition iu0  := ideal_univ_start.
  Definition ru0  := real_univ_start.

  Import Gen Tacs SetLemmas.

  Hint Unfold t__hon t__adv b ru0 iu0 ideal_univ_start mkiU real_univ_start mkrU mkrUsr startAdv : core.
  Hint Unfold
       mkiU mkiUsr mkrU mkrUsr
       mkKeys
       real_univ_start
       ideal_univ_start
       noAdv : core.

  Ltac step1 := eapply msc_step_alt; [ unfold oneStepClosure_new; simplify; tidy; rstep; istep | ..].
  Ltac step2 := 
    solve[ simplify
           ; sets
           ; split_ex
           ; propositional
           ; repeat match goal with
                    | [H : (?x1, ?y1) = ?p |- _] =>
                      match p with
                      | (?x2, ?y2) =>
                        tryif (concrete x2; concrete y2)
                        then let H' := fresh H
                             in assert (H' : (x1, y1) = (x2, y2) -> x1 = x2 /\ y1 = y2)
                               by equality
                                ; propositional
                                ; discriminate
                        else invert H
                      | _ => invert H
                      end
                    end
         | eapply intersect_empty_l ].

  Ltac step3 := rewrite ?union_empty_r.

  (* Set Ltac Profiling. *)

  Lemma safe_invariant :
    invariantFor
      {| Initial := {(ru0, iu0)}; Step := @step t__hon t__adv  |}
      (fun st => safety st /\ labels_align st ).
  Proof.
    eapply invariant_weaken.

    - apply multiStepClosure_ok; simpl.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      
    - intros.
      simpl in *; split.
      
      + sets_invert; unfold safety;
          split_ex; simpl in *; subst; solve_honest_actions_safe;
            clean_map_lookups; eauto 8.

        all: unfold mkKeys in *; simpl in *; solve_honest_actions_safe; eauto.

      + sets_invert; unfold labels_align;
          split_ex; subst; intros;
            rstep.

        Ltac clup := subst.
          (* repeat ( *)
          (*     equality1 ||  *)
          (*     match goal with *)
          (*     | [ H : context [ _ #+ (?k,_) #? ?k ] |- _ ] => *)
          (*       is_not_evar k *)
          (*       ; rewrite ChMap.F.add_eq_o in H by trivial *)
          (*     | [ H : context [ _ #+ (?k1,_) #? ?k2 ] |- _ ] => *)
          (*       is_not_evar k1 *)
          (*       ; is_not_evar k2 *)
          (*       ; rewrite ChMap.F.add_neq_o in H by congruence *)
          (*     end); subst. *)

        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto.
        * subst; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto.
        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto.

        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto;
              repeat (clean_map_lookups; solve_concrete_maps).
          
        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto;
              repeat (clean_map_lookups; solve_concrete_maps).

        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto;
              repeat (clean_map_lookups; solve_concrete_maps).

        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto.

        * clup; do 3 eexists; repeat (simple apply conj);
            [ solve [ eauto ]
            | indexedIdealStep; simpl
            | repeat solve_action_matches1; clean_map_lookups; ChMap.clean_map_lookups
            ]; eauto; simpl; eauto.
          
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)
        (* * (do 3 eexists); repeat (simple apply conj); eauto. *)

  Qed.

  (* Show Ltac Profile. *)
  (* Show Ltac Profile "churn2". *)
  
  Lemma U_good : @universe_starts_sane _ Unit b ru0.
  Proof.
    autounfold;
      unfold universe_starts_sane; simpl.
    repeat (apply conj); intros; eauto.
    - solve_perm_merges; eauto.
    - econstructor.
    - unfold AdversarySafety.keys_honest; rewrite Forall_natmap_forall; intros.
      econstructor; unfold mkrUsr; simpl.
      rewrite !findUserKeys_add_reduce, findUserKeys_empty_is_empty; eauto.
      solve_perm_merges.
    - unfold lameAdv; simpl; eauto.
  Qed.

  Lemma univ_ok_start : universe_ok ru0.
  Proof.
    autounfold; econstructor; eauto.
  Qed.

  Lemma adv_univ_ok_start : adv_universe_ok ru0.
  Proof.
    autounfold; unfold adv_universe_ok; eauto.
    unfold keys_and_permissions_good.
    pose proof (adversary_is_lame_adv_univ_ok_clauses U_good).

    intuition eauto;
      simpl in *.

    - solve_simple_maps; eauto.
    - rewrite Forall_natmap_forall; intros.
      solve_simple_maps; simpl;
        unfold permission_heap_good; intros;
          solve_simple_maps; eauto.

    - unfold user_cipher_queues_ok.
      rewrite Forall_natmap_forall; intros.
      cases (USR1 ==n k); cases (USR2 ==n k);
        subst; clean_map_lookups; simpl in *; econstructor; eauto.

    - unfold honest_nonces_ok; intros.
      unfold honest_nonce_tracking_ok.

      destruct (u_id ==n USR1); destruct (u_id ==n USR2);
        destruct (rec_u_id ==n USR1); destruct (rec_u_id ==n USR2);
          subst; try contradiction; try discriminate; clean_map_lookups; simpl;
            repeat (apply conj); intros; clean_map_lookups; eauto.

    - unfold honest_users_only_honest_keys; intros.
      destruct (u_id ==n USR1);
        destruct (u_id ==n USR2);
        subst;
        simpl in *;
        clean_map_lookups;
        unfold mkrUsr; simpl; 
        rewrite !findUserKeys_add_reduce, findUserKeys_empty_is_empty;
        eauto;
        simpl in *;
        solve_perm_merges;
        solve_concrete_maps;
        solve_simple_maps;
        eauto.
  Qed.
  
  Lemma universe_starts_safe : universe_ok ru0 /\ adv_universe_ok ru0.
  Proof.
    repeat (simple apply conj);
      eauto using univ_ok_start, adv_univ_ok_start.
  Qed.
  

End ShareSecretProtocolSecure.

(*
 * 1) make protocols  518.64s user 0.45s system 99% cpu 8:39.13 total  ~ 6.2GB
 * 2) add cleanup of chmaps to close:
 *    make protocols  414.45s user 0.43s system 99% cpu 6:54.90 total  ~ 5.6GB
 *
 *
 *)
