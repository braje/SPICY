From Coq Require Import List.
Require Import Frap.

Require Import Common Simulation.
Require IdealWorld RealWorld.

Import IdealWorld.IdealNotations.
Import RealWorld.RealWorldNotations.

Set Implicit Arguments.

(* User ids *)
Definition A : user_id   := 0.
Definition B : user_id   := 1.
Definition ADV : user_id := 2.

Section IdealProtocol.
  Import IdealWorld.

  Definition CH__A2B : channel_id := 0.
  Definition CH__B2A : channel_id := 1.

  Definition PERMS__a := $0 $+ (CH__A2B, {| read := false; write := true |}) $+ (CH__B2A, {| read := true; write := false |}).
  Definition PERMS__b := $0 $+ (CH__B2A, {| read := false; write := true |}) $+ (CH__A2B, {| read := true; write := false |}).

  Definition mkiU (cv : channels) (p__a p__b : cmd bool): universe bool :=
    {| channel_vector := cv
     ; users :=
         [ (A,   {| perms    := PERMS__a ; protocol := p__a |})
         ; (B,   {| perms    := PERMS__b ; protocol := p__b |})
         ]
    |}.

  Definition ideal_univ_start :=
    mkiU ($0 $+ (CH__A2B, { }) $+ (CH__B2A, { }))
         ( n <- Gen
         ; _ <- Send (Content n) CH__A2B
         ; m <- @Recv Nat CH__B2A
         ; Return match extractContent m with
                  | None =>    false
                  | Some n' => if n ==n n' then true else false
                  end)
         ( m <- @Recv Nat CH__A2B
         ; _ <- Send m CH__B2A
         ; Return true).

  Definition ideal_univ_sent1 n :=
    mkiU ($0 $+ (CH__A2B, {Exm (Content n)}) $+ (CH__B2A, { }))
         ( _ <- Return tt
         ; m <- @Recv Nat CH__B2A
         ; Return match extractContent m with
                  | None =>    false
                  | Some n' => if n ==n n' then true else false
                  end)
         ( m <- @Recv Nat CH__A2B
         ; _ <- Send m CH__B2A
         ; Return true).

  Definition ideal_univ_recd1 n :=
    mkiU ($0 $+ (CH__A2B, {Exm (Content n)}) $+ (CH__B2A, { }))
         ( m <- @Recv Nat CH__B2A
         ; Return match extractContent m with
                  | None =>    false
                  | Some n' => if n ==n n' then true else false
                  end)
         ( m <- Return (Content n)
         ; _ <- Send m CH__B2A
         ; Return true).

  Definition ideal_univ_sent2 n :=
    mkiU ($0 $+ (CH__A2B, {Exm (Content n)}) $+ (CH__B2A, {Exm (Content n)}))
         ( m <- @Recv Nat CH__B2A
         ; Return match extractContent m with
                  | None =>    false
                  | Some n' => if n ==n n' then true else false
                  end)
         ( _ <- Return tt
         ; Return true).

  Definition ideal_univ_recd2 n :=
    mkiU ($0 $+ (CH__A2B, {Exm (Content n)}) $+ (CH__B2A, {Exm (Content n)}))
         ( m <- Return (Content n)
         ; Return match extractContent m with
                  | None =>    false
                  | Some n' => if n ==n n' then true else false
                  end)
         (Return true).

  Definition ideal_univ_done n :=
    mkiU ($0 $+ (CH__A2B, {Exm (Content n)}) $+ (CH__B2A, {Exm (Content n)}))
         (Return true)
         (Return true).

End IdealProtocol.

Section RealProtocolParams.
  Import RealWorld.

  Definition KID1 : key_identifier := 0.
  Definition KID2 : key_identifier := 1.

  Definition KEY1  := MkCryptoKey KID1 Signing.
  Definition KEY2  := MkCryptoKey KID2 Signing.
  Definition KEY__A  := AsymKey KEY1 true.
  Definition KEY__B  := AsymKey KEY2 true.
  Definition KEYS  := $0 $+ (KID1, AsymKey KEY1 true) $+ (KID2, AsymKey KEY2 true).

  Definition A__keys := $0 $+ (KID1, AsymKey KEY1 true)  $+ (KID2, AsymKey KEY2 false).
  Definition B__keys := $0 $+ (KID1, AsymKey KEY1 false) $+ (KID2, AsymKey KEY2 true).
End RealProtocolParams.

Module Type enemy.
  Import RealWorld.
  Parameter code : user_cmd bool.
End enemy.

Section RealProtocol.
  Import RealWorld.

  Definition mkrU (usr_msgs : queued_messages) (cs : ciphers) (p__a p__b : user_cmd bool) (adversaries : user_list (user_data bool)) : universe bool :=
    {| users            :=
           (A, {| key_heap := A__keys ; protocol := p__a |})
         :: (B, {| key_heap := B__keys ; protocol := p__b |})
         :: adversaries
     ; users_msg_buffer := usr_msgs
     ; all_keys         := KEYS
     ; all_ciphers      := cs
     ; adversary        := $0
     |}.

  Definition real_univ_start cs :=
    mkrU $0 cs
         ( n  <- Gen
         ; m  <- Sign KEY__A (Plaintext n)
         ; _  <- Send B m
         ; m' <- @Recv (Pair Nat CipherId) (Signed KID2 Accept)
         ; Return match unPair m' with
                  | Some (Plaintext n', _) => if n ==n n' then true else false (* also do verify? *)
                  | _ => false
                  end)

         ( m  <- @Recv (Pair Nat CipherId) (Signed KID1 Accept)
         ; v  <- Verify (AsymKey KEY1 false) m
         ; m' <- match unPair m with
                | Some (p,_) => Sign KEY__B p
                | Nothing    => Sign KEY__B (Plaintext 1)
                end
         ; _  <- Send A m'
         ; Return v).

  Definition real_univ_sent1 n cs cid1 :=
    mkrU ($0 $+ (B, [Exm (Signature (Plaintext n) cid1)]))
         (cs $+ (cid1, Cipher cid1 KID1 (Plaintext n)))
         ( _  <- Return tt
         ; m' <- @Recv (Pair Nat CipherId) (Signed KID2 Accept)
         ; Return match unPair m' with
                  | Some (Plaintext n', _) => if n ==n n' then true else false (* also do verify? *)
                  | _ => false
                  end)

         ( m  <- @Recv (Pair Nat CipherId) (Signed KID1 Accept)
         ; v  <- Verify (AsymKey KEY1 false) m
         ; m' <- match unPair m with
                | Some (p,_) => Sign KEY__B p
                | Nothing    => Sign KEY__B (Plaintext 1)
                end
         ; _  <- Send A m'
         ; Return v).

  Definition real_univ_recd1 n cs cid1 :=
    mkrU $0
         (cs $+ (cid1, Cipher cid1 KID1 (Plaintext n)))
         ( _  <- Return tt
         ; m' <- @Recv (Pair Nat CipherId) (Signed KID2 Accept)
         ; Return match unPair m' with
                  | Some (Plaintext n', _) => if n ==n n' then true else false (* also do verify? *)
                  | _ => false
                  end)

         ( m  <- Return (Signature (Plaintext n) cid1)
         ; v  <- Verify (AsymKey KEY1 false) m
         ; m' <- match unPair m with
                | Some (p,_) => Sign KEY__B p
                | Nothing    => Sign KEY__B (Plaintext 1)
                end
         ; _  <- Send A m'
         ; Return v).

  Definition real_univ_sent2 n cid1 cid2 :=
    mkrU ($0 $+ (A, [Exm (Signature (Plaintext n) cid2)]))
         ($0 $+ (cid1, Cipher cid1 KID1 (Plaintext n)) $+ (cid2, Cipher cid2 KID2 (Plaintext n)))
         ( _  <- Return tt
         ; m' <- @Recv (Pair Nat CipherId) (Signed KID2 Accept)
         ; Return match unPair m' with
                  | Some (Plaintext n', _) => if n ==n n' then true else false (* also do verify? *)
                  | _ => false
                  end)

         ( _  <- Return tt ; Return true).

  Definition real_univ_recd2 n cid1 cid2 :=
    mkrU $0 ($0 $+ (cid1, Cipher cid1 KID1 (Plaintext n)) $+ (cid2, Cipher cid2 KID2 (Plaintext n)))
         ( m' <- Return (Signature (Plaintext n) cid2)
         ; Return match unPair m' with
                  | Some (Plaintext n', _) => if n ==n n' then true else false (* also do verify? *)
                  | _ => false
                  end)

         ( _  <- Return tt ; Return true).

  Definition real_univ_done cs :=
    mkrU $0 cs (Return true) (Return true).

  Inductive RPingPongBase: RealWorld.universe bool -> IdealWorld.universe bool -> Prop :=
  | Start : forall U__r cs,
        rstepSilent^* (real_univ_start cs []) U__r
      -> RPingPongBase U__r ideal_univ_start

  | Sent1 : forall U__r cs cid1 n,
        rstepSilent^* (real_univ_sent1 n cs cid1 []) U__r
      -> RPingPongBase U__r (ideal_univ_sent1 n)

  | Recd1 : forall U__r cs cid1 n,
        rstepSilent^* (real_univ_recd1 n cs cid1 []) U__r
      -> RPingPongBase U__r (ideal_univ_recd1 n)

  | Sent2 : forall U__r cid1 cid2 n,
        rstepSilent^* (real_univ_sent2 n cid1 cid2 []) U__r
      -> RPingPongBase U__r (ideal_univ_sent2 n)

  | Recd2 : forall U__r cid1 cid2 n,
        rstepSilent^* (real_univ_recd2 n cid1 cid2 []) U__r
      -> RPingPongBase U__r (ideal_univ_recd2 n)

  | Done : forall cs n,
      RPingPongBase (real_univ_done cs []) (ideal_univ_done n)
  .

End RealProtocol.

Module SimulationAutomation.

  Ltac churn1 :=
    match goal with
    | [ H: In _ _ |- _ ] => invert H
    | [ H : $0 $? _ = Some _ |- _ ] => apply lookup_empty_not_Some in H; contradiction
    | [ H : _ $? _ = Some _ |- _ ] => apply lookup_split in H; propositional; subst
    | [ H : (_ $- _) $? _ = Some _ |- _ ] => rewrite addRemoveKey in H by auto
    | [ H : Some _ = Some _ |- _ ] => invert H

    | [ H : (_ :: _) = _ |- _ ] => invert H
    | [ H : (_,_) = (_,_) |- _ ] => invert H

    | [ H : updF _ _ _ = _ |- _ ] => unfold updF; simpl in H

    | [ H: RealWorld.Cipher _ _ _ = RealWorld.Cipher _ _ _ |- _ ] => invert H
    | [ H: RealWorld.SymKey _ = _ |- _ ] => invert H
    | [ H: RealWorld.AsymKey _ _ = _ |- _ ] => invert H

    | [ H: exists _, _ |- _ ] => invert H
    | [ H: _ /\ _ |- _ ] => invert H

    (* Only take a user step if we have chosen a user *)
    | [ H: RealWorld.lstep_user A _ _ _ |- _ ] => invert H
    | [ H: RealWorld.lstep_user B _ _ _ |- _ ] => invert H

    | [ H: rstepSilent _ _ |- _ ] => invert H (* unfold rstepSilent in H *)
    | [ H: RealWorld.lstep_universe _ _ _ |- _ ] => invert H

    (* Effectively clears hypotheses of this kind, assuming they are correct.  Otherwise,
     * I have problems with the automation trying to identify cipher ids. *)
    | [ H : RealWorld.keyId _ = _ |- _] => invert H

    | [ H: RealWorld.signMessage _ _ _ = _ |- _ ] => unfold RealWorld.encryptMessage; simpl in H
    | [ H: RealWorld.encryptMessage _ _ _ = _ |- _ ] => unfold RealWorld.encryptMessage; simpl in H

    | [ H: RealWorld.msg_accepted_by_pattern _ _ _ = _ |- _ ] =>
      unfold RealWorld.msg_accepted_by_pattern in H;
      rewrite lookup_add_eq in H by eauto;
      try discriminate
    (* | [ H : match (_ $+ (_, RealWorld.Cipher _ _ _)) $? _ with _ => _ end = false |- _ ] => *)
    (*   rewrite lookup_add_eq in H by eauto; try discriminate *)
    | [ H : RealWorld.msg_spoofable _ _ _ = _ |- _] =>
      unfold RealWorld.msg_spoofable in H;
      rewrite lookup_add_eq in H by eauto;
      simplify;
      discriminate
    end.

  Ltac risky1 :=
    match goal with
    | [ H: rstepSilent^* _ _ |- _ ] => invert H
      (* idtac "risk"; (churn1 || idtac "nochurn"); invert H *)
    end.

  Ltac churn := 
    repeat (repeat churn1; try risky1; repeat churn1).

  Ltac istep_univ pick :=
    eapply IdealWorld.LStepUser'; simpl; [ pick; reflexivity | | reflexivity]; simpl.

  Ltac user0 := left.
  Ltac user1 := right;left.

  Ltac istep_univ0 := istep_univ user0.
  Ltac istep_univ1 := istep_univ user1.

  Ltac r_single_silent_step :=
      eapply RealWorld.LStepBindProceed
    || eapply RealWorld.LGen
    || eapply RealWorld.LStepRecvDrop
    || eapply RealWorld.LStepEncrypt
    || eapply RealWorld.LStepDecrypt
    || eapply RealWorld.LStepSign
    || eapply RealWorld.LStepVerify
  .

  Ltac real_silent_step pick :=
    eapply TrcFront; [
      eapply RealWorld.LStepUser'; simpl; [pick; reflexivity | | reflexivity];
        (eapply RealWorld.LStepBindRecur; r_single_silent_step) || r_single_silent_step
     |]; simpl.

  Ltac real_silent_step0 := real_silent_step user0.
  Ltac real_silent_step1 := real_silent_step user1.

  Ltac i_single_silent_step :=
      eapply IdealWorld.LStepBindProceed
    || eapply IdealWorld.LStepGen
    || eapply IdealWorld.LStepCreateChannel
  .

  Ltac ideal_silent_step pick :=
    eapply TrcFront; [
      eapply IdealWorld.LStepUser'; simpl;
      [ pick; reflexivity | | reflexivity];
      (eapply IdealWorld.LStepBindRecur; i_single_silent_step) || i_single_silent_step
     |]; simpl.

  Ltac ideal_silent_step0 := ideal_silent_step user0.
  Ltac ideal_silent_step1 := ideal_silent_step user1.
  Ltac ideal_silent_steps := (ideal_silent_step0 || ideal_silent_step1) ; repeat ideal_silent_step0; repeat ideal_silent_step1; eapply TrcRefl.

  Remove Hints TrcRefl TrcFront.

  Hint Constructors RPingPongBase action_matches msg_eq.
  Hint Resolve IdealWorld.LStepSend' IdealWorld.LStepRecv'.

  Hint Extern 2 (rstepSilent ^* _ _) => (solve [eapply TrcRefl]) || real_silent_step0.
  Hint Extern 2 (rstepSilent ^* _ _) => (solve [eapply TrcRefl]) || real_silent_step1.
  Hint Extern 1 (RPingPongBase _ (RealWorld.updateUniverse _ _ _ _ _ _ _ _) _) => unfold RealWorld.updateUniverse; simpl.

  Hint Extern 2 (IdealWorld.lstep_universe _ _ _) => istep_univ0.
  Hint Extern 2 (IdealWorld.lstep_universe _ _ _) => istep_univ1.
  Hint Extern 1 (IdealWorld.lstep_user _ (_,(IdealWorld.Bind _ _)%idealworld,_) _) => eapply IdealWorld.LStepBindRecur.
  Hint Extern 1 (istepSilent ^* _ _) => ideal_silent_steps || apply TrcRefl.

  Hint Extern 1 (In _ _) => progress simpl.

  Hint Extern 1 (RealWorld.encryptMessage _ _ _ = _) => unfold RealWorld.encryptMessage; simpl.
  Hint Extern 1 (RealWorld.signMessage _ _ _ = _) => unfold RealWorld.signMessage; simpl.
  Hint Extern 1 (RealWorld.action_adversary_safe _ _ = _) => unfold RealWorld.action_adversary_safe; simplify.
  Hint Extern 1 (IdealWorld.msg_permissions_valid _ _) => progress simpl.

  Hint Extern 1 (A__keys $? _ = _) => unfold A__keys, B__keys, KEY1, KEY2, KEY__A, KEY__B, KID1, KID2.
  Hint Extern 1 (B__keys $? _ = _) => unfold A__keys, B__keys, KEY1, KEY2, KEY__A, KEY__B, KID1, KID2.
  Hint Extern 1 (PERMS__a $? _ = _) => unfold PERMS__a.
  Hint Extern 1 (PERMS__b $? _ = _) => unfold PERMS__b.
  Hint Extern 1 (add _ _ _ $? _ = Some _) => rewrite lookup_add_ne by discriminate.
  Hint Extern 1 (add _ _ _ = _) => maps_equal; try discriminate.
  Hint Extern 1 (_ \in _) => sets.

End SimulationAutomation.

Import SimulationAutomation.

Section FeebleSimulates.

  Lemma rpingbase_silent_simulates :
    forall U__r U__i,
      RPingPongBase U__r U__i
      -> forall U__r',
        rstepSilent U__r U__r'
        -> exists U__i',
          istepSilent ^* U__i U__i'
          /\ RPingPongBase U__r' U__i'.
  Proof.
    intros.
    invert H.

    - churn;
        (eexists; constructor; swap 1 2; [eapply Start |]; eauto 8).

    - churn;
        (eexists; constructor; swap 1 2; [eapply Sent1 |]; eauto 8).

    - churn;
        (eexists; constructor; swap 1 2; [eapply Recd1 |]; eauto 8).

    - churn;
        (eexists; constructor; swap 1 2; [eapply Sent2 |]; eauto 8).

    - churn;
        (eexists; constructor; swap 1 2; [eapply Recd2 |]; eauto 8).

    - churn.

  Qed.

  Lemma rpingbase_loud_simulates : 
    forall U__r U__i,
      RPingPongBase U__r U__i
      -> forall a1 U__r',
        RealWorld.lstep_universe U__r (Action a1) U__r'
        -> exists a2 U__i' U__i'',
            istepSilent^* U__i U__i'
            /\ IdealWorld.lstep_universe U__i' (Action a2) U__i''
            /\ action_matches a1 a2
            /\ RPingPongBase U__r' U__i''
            /\ RealWorld.action_adversary_safe U__r.(RealWorld.adversary) a1 = true.
  Proof.
    intros.
    invert H; churn.
    
    unfold ideal_univ_start, RealWorld.updateUniverse, RealWorld.multiMapAdd; simpl.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | ]; eauto; eauto 12.
      admit.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | | ]; eauto; eauto 12.
      admit.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | | ]; eauto; eauto 12.
      admit.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | | ]; eauto; eauto 12.
      admit.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | | ]; eauto; eauto 12.
      admit.

    - do 3 eexists.
      propositional; swap 1 4; swap 2 4; swap 3 4;
        [simplify | | | | ]; eauto; eauto 12.
      admit.

  Admitted.

  Theorem base_pingpong_refines_ideal_pingpong :
    real_univ_start $0 [] <| ideal_univ_start.
  Proof.
    exists RPingPongBase.
    firstorder; eauto using rpingbase_silent_simulates, rpingbase_loud_simulates.
  Qed.

End FeebleSimulates. 

Section SingleAdversarySimulates.

  (* If we have a simulation proof, we know that:
   *   1) No receives could have accepted spoofable messages
   *   2) Sends we either of un-spoofable, or were 'public' and are safely ignored
   *
   * This should mean we can write some lemmas that say we can:
   *   safely ignore all adversary messages (wipe them from the universe) -- Adam's suggestion, I am not exactly sure how...
   *   or, prove an appended simulation relation, but I am not sure how to generically express this
   *)

  Definition add_adversary {A} (U__r : RealWorld.universe A) (advcode : RealWorld.user_cmd A) :=
    RealWorld.addUniverseUsers U__r [(ADV, {| RealWorld.key_heap := $0 ; RealWorld.protocol := advcode |})].

  Definition strip_adversary {A} (U__r : RealWorld.universe A) : RealWorld.universe A :=
    {|
      RealWorld.users            := removelast U__r.(RealWorld.users)
    ; RealWorld.users_msg_buffer := U__r.(RealWorld.users_msg_buffer)
    ; RealWorld.all_keys         := U__r.(RealWorld.all_keys)
    ; RealWorld.all_ciphers      := U__r.(RealWorld.all_ciphers)
    ; RealWorld.adversary        := U__r.(RealWorld.adversary)
    |}.


  Lemma step_clean_or_adversary :
    forall {A} (U__r U__ra U__ra' : RealWorld.universe A) advcode lbl u_id u,
      In (u_id,u) U__r.(RealWorld.users)
      -> u_id <> ADV
      -> U__ra = add_adversary U__r advcode
      -> RealWorld.lstep_universe U__ra lbl U__ra'
      -> forall stepUdata uks advk cs ks qmsgs (cmd' : RealWorld.user_cmd A),
          (* Legit step *)
          ( forall stepUid,
              In (stepUid,stepUdata) U__r.(RealWorld.users)
            /\ RealWorld.lstep_user
                stepUid lbl
                (RealWorld.universe_data_step U__r stepUdata)
                (advk, cs, ks, qmsgs, uks, cmd')

          ) \/
          (* Adversary step *)
          ( In (ADV,stepUdata) U__ra.(RealWorld.users)
          /\ RealWorld.lstep_user
              ADV lbl
              (RealWorld.universe_data_step U__ra stepUdata)
              (advk, cs, ks, qmsgs, uks, cmd')

          )
  .
  Proof.
  Admitted.

  Lemma simulates_implies_noninterference:
    forall {A} (U__r U__ra : RealWorld.universe A) (U__i : IdealWorld.universe A),
      U__r <| U__i
      -> forall U__ra' u_id advcode a udata,
        U__ra = add_adversary U__r advcode
        -> RealWorld.lstep_universe U__ra (Action a) U__ra'
        -> RealWorld.lstep_user u_id (Action a) (RealWorld.universe_data_step U__ra udata) (RealWorld.universe_data_step U__ra' udata) 
        -> In (u_id,udata) U__ra.(RealWorld.users)
        -> u_id <> ADV.
  Proof.
  Admitted.


  (* Maybe this isn't provable.  One big question I have is whether we can actually
   * make the connection for some arbitrary relation.  The biggest problem (maybe)
   * being that adversaries will certainly affect the book keeping fields of the
   * simulation relation like: all_keys, all_ciphers, users_message_buffer.
   * There is no guarantee that the R in the original simulation relation doesn't say
   * something relevant about those fields.
   *)
  Theorem simulates_implies_sim_with_adv :
    forall {A} (U__r U__ra : RealWorld.universe A) (U__i : IdealWorld.universe A),
      U__r <| U__i
      -> forall advcode,
        U__ra = add_adversary U__r advcode
        -> U__ra <| U__i.
  Proof.

  Admitted.



  (* Can't really write this as is.  Perhaps derive some
   * kind of traces predicate like in MessagesAndRefinement?  Does that
   * get to the final theorem we want to prove?
   *)
  (* Definition final_answers_agree {A} (U__r : RealWorld.universe A) (U__i : IdealWorld.universe A) : *)
  (*   forall U__r' U__i', *)
  (*     RealWorld.lstep_universe^* U__r lbl U__r' *)
  (*     -> IdealWorld.lstep_universe^* U__i lbl' U__i' *)
  (*     ->  *)









  Definition still_simulates_with_adversary (U__i : IdealWorld.universe bool)  (U__r : RealWorld.universe bool) :=
    U__r <| U__i
    -> forall U__r' advcode,
      U__r' = RealWorld.addUniverseUsers U__r [(ADV, {| RealWorld.key_heap := $0 ; RealWorld.protocol := advcode |})]
      -> U__r' <| U__i.



    (* Idea:  We have a relation: R : Ureal -> Uideal and need R' : U'real -> Uideal  where U'real is augmented
     *        with the adversary.  One approach may be to find R'' : U'real -> Ureal and then compose the relations.
     *        Hrm.  Relations don't really compose...
     *  What components could go into this R''?
     *    1. rstepSilent^* -- could provide some support for dropping messages sent by the adversary
     *    2. some U'real -> Ureal which just peels off the adversary
     * 
     * I think the biggest remaining challenge is handling Sends from the adversary.  Should these be 'loud?'
     *
     *)

(* How do we augment the simulation relation from above to include an arbitrary adversary? *)

End SingleAdversarySimulates.