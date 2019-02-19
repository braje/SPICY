From Coq Require Import List Classical ClassicalEpsilon.
Require Import Frap Eqdep.

Require Import Common. 
Require IdealWorld.
Require RealWorld.

Import IdealWorld.IdealNotations.
Import RealWorld.RealWorldNotations.

Set Implicit Arguments.

Ltac invert H :=
  (FrapWithoutSets.invert H || (inversion H; clear H));
  repeat match goal with
         (* | [ x : _ |- _ ] => subst x *)
         | [ H : existT _ _ _ = existT _ _ _ |- _ ] => apply inj_pair2 in H; try subst
         end.
  
Lemma addKeyTwice :
  forall K V (k : K) (v v' : V) m,
    m $+ (k, v) $+ (k, v') = m $+ (k, v').
Proof.
  intros. maps_equal.
Qed.

(* Question for Adam.  Is there a better way to do this??? *)
Section decide.
  Variable P : Prop.

  Lemma decided : inhabited (sum P (~P)).
  Proof.
    destruct (classic P).
    constructor; exact (inl _ H).
    constructor; exact (inr _ H).
  Qed.

  Definition decide : sum P (~P) :=
    epsilon decided (fun _ => True).
End decide.

Lemma addRemoveKey : 
  forall K V (k : K) (v : V) m,
    m $? k = None
    -> m $+ (k,v) $- k = m.
Proof.
  intros.
  eapply fmap_ext.
  intros.

  destruct (decide (k0 = k)).
  * subst. simplify. eauto.
  * symmetry.
    rewrite <- lookup_add_ne with (k := k) (v := v); auto.
    rewrite lookup_remove_ne; auto.
Qed.

Theorem lookup_empty_not_Some :
  forall K V (k : K) (v : V),
    empty K V $? k = Some v -> False.
Proof.
  intros.
  apply lookup_Some_dom in H.
  rewrite dom_empty in H. invert H.
Qed.

Hint Rewrite addKeyTwice addRemoveKey.
Hint Resolve lookup_add_eq lookup_empty lookup_empty_not_Some.
Hint Resolve IdealWorld.StepUser' IdealWorld.StepSend' IdealWorld.StepRecv'.

Ltac fixcontext :=
  match goal with
  | [ H : $0 $? _ = Some _ |- _ ] => apply lookup_empty_not_Some in H; contradiction
  | [ H : (_ $+ (_, _)) $? _ = Some _ |- _ ] => apply lookup_split in H; propositional; subst
  | [ H : (_, _) = (_,_) |- _ ] => invert H
  | [ H : In _ _ |- _ ] => inversion H; clear H
  | [ H : _ /\ _ |- _ ] => invert H
  | [ H : (_ :: _) = _ |- _ ] => invert H
  end.

Hint Resolve in_eq in_cons.

(* Labeled transition system simulation statement *)

Definition rstepSilent {A : Type} (U1 U2 : RealWorld.universe A) :=
  RealWorld.lstep_universe U1 Silent U2.

Definition istepSilent {A : Type} (U1 U2 : IdealWorld.universe A) :=
  IdealWorld.lstep_universe U1 Silent U2.

Inductive chan_key : Set :=
| Public (ch_id : IdealWorld.channel_id)
| Auth (ch_id : IdealWorld.channel_id): forall k,
    k.(RealWorld.keyUsage) = RealWorld.Signing -> chan_key
| Enc  (ch_id : IdealWorld.channel_id) : forall k,
    k.(RealWorld.keyUsage) = RealWorld.Encryption -> chan_key
| AuthEnc (ch_id : IdealWorld.channel_id) : forall k1 k2,
      k1.(RealWorld.keyUsage) = RealWorld.Signing
    -> k2.(RealWorld.keyUsage) = RealWorld.Encryption
    -> chan_key
.

Inductive msg_eq : forall t__r t__i,
    RealWorld.message t__r
    -> IdealWorld.message t__i * IdealWorld.channel_id * IdealWorld.channels * IdealWorld.permissions -> Prop :=

(* Still need to reason over visibility of channel -- plaintext really means everyone can see it *)
| PlaintextMessage' : forall content ch_id cs ps,
    ps $? ch_id = Some (IdealWorld.construct_permission true true) ->
    msg_eq (RealWorld.Plaintext content) (IdealWorld.Content content, ch_id, cs, ps)
.

Definition check_cipher (ch_id : IdealWorld.channel_id)
  :=
    forall A B ch_id k (im : IdealWorld.message A) (rm : RealWorld.message B) cphrs (*do we need these??*) chans perms,
      match rm with
      | RealWorld.Ciphertext cphr_id =>
        match cphrs $? cphr_id with
        | None => False
        | Some (RealWorld.Cipher cphr_id k_id msg) =>
          RealWorld.keyId k = k_id /\ msg_eq msg (im,ch_id,chans,perms)
        end
      | _ => False
      end.
    
Definition chan_key_ok :=
  forall A B ch_id (im : IdealWorld.message A) (rm : RealWorld.message B) cphrs chan_keys (*do we need these??*) chans perms,
    match chan_keys $? ch_id with
    | None => False
    | Some (Public _)   => msg_eq rm (im,ch_id,chans,perms)
    | Some (Auth _ k _) =>
      (* check_cipher ch_id k im rm cphrs chans perms *)
      match rm with
      | RealWorld.Ciphertext cphr_id =>
        match cphrs $? cphr_id with
        | None => False
        | Some (RealWorld.Cipher cphr_id k_id msg) =>
          RealWorld.keyId k = k_id /\ msg_eq msg (im,ch_id,chans,perms)
        end
      | _ => False
      end
    | Some (Enc  _ k _) => False
    | Some (AuthEnc _ k1 k2 _ _) => False
    end.


Inductive action_matches :
    RealWorld.action -> IdealWorld.action -> Prop :=
| Inp : forall t__r t__i (msg1 : RealWorld.message t__r) (msg2 : IdealWorld.message t__i) rw iw ch_id cs ps p x y z,
      rw = (RealWorld.Input msg1 p x y z)
    -> iw = IdealWorld.Input msg2 ch_id cs ps
    -> msg_eq msg1 (msg2, ch_id, cs, ps)
    -> action_matches rw iw
| Out : forall t__r t__i (msg1 : RealWorld.message t__r) (msg2 : IdealWorld.message t__i) rw iw ch_id cs ps x,
      rw = RealWorld.Output msg1 x
    -> iw = IdealWorld.Output msg2 ch_id cs ps
    -> msg_eq msg1 (msg2, ch_id, cs, ps)
    -> action_matches rw iw
.

(* Simulation for labeled transition system *)
Definition lsimulates {A : Type}
           (R : RealWorld.universe A -> IdealWorld.universe A -> Prop)
           (U1 : RealWorld.universe A) (U2 : IdealWorld.universe A) :=

(*  call spoofable *)

  (forall U1 U2,
      R U1 U2
      -> forall U1',
        rstepSilent U1 U1' (* or any adversary step *)
        -> exists U2',
          istepSilent ^* U2 U2'
          /\ R U1' U2')

  /\ (forall U1 U2,
      R U1 U2
      -> forall a1 U1',
        RealWorld.lstep_universe U1 (Action a1) U1' (* exclude adversary steps *)
        -> exists a2 U2' U2'',
            istepSilent^* U2 U2'
            /\ IdealWorld.lstep_universe U2' (Action a2) U2''
            /\ action_matches a1 a2
            /\ R U1' U2''
            /\ RealWorld.action_adversary_safe U1.(RealWorld.adversary) a1 = true
    (* and adversary couldn't have constructed message seen in a1 *)
    )

  /\ R U1 U2.

Definition lrefines {A : Type} (U1 : RealWorld.universe A)(U2 : IdealWorld.universe A) :=
  exists R, lsimulates R U1 U2.

Infix "<|" := lrefines (no associativity, at level 70).