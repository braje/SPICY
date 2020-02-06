(* DISTRIBUTION STATEMENT A. Approved for public release. Distribution is unlimited.
 *
 * This material is based upon work supported by the Department of the Air Force under Air Force 
 * Contract No. FA8702-15-D-0001. Any opinions, findings, conclusions or recommendations expressed 
 * in this material are those of the author(s) and do not necessarily reflect the views of the 
 * Department of the Air Force.
 * 
 * © 2019 Massachusetts Institute of Technology.
 * 
 * MIT Proprietary, Subject to FAR52.227-11 Patent Rights - Ownership by the contractor (May 2014)
 * 
 * The software/firmware is provided to you on an As-Is basis
 * 
 * Delivered to the U.S. Government with Unlimited Rights, as defined in DFARS Part 252.227-7013
 * or 7014 (Feb 2014). Notwithstanding any copyright notice, U.S. Government rights in this work are
 * defined by DFARS 252.227-7013 or DFARS 252.227-7014 as detailed above. Use of this work other than
 * as specifically authorized by the U.S. Government may violate any copyrights that exist in this work. *)

Require Import
        MyPrelude
        Sets.

Set Implicit Arguments.

Module Foo <: EMPTY.
End Foo.
Module Import SN := SetNotations(Foo).

Record trsys state := {
  Initial : state -> Prop;
  Step : state -> state -> Prop
}.

Definition invariantFor {state} (sys : trsys state) (invariant : state -> Prop) :=
  forall s, sys.(Initial) s
            -> forall s', sys.(Step)^* s s'
                          -> invariant s'.

Theorem use_invariant : forall {state} (sys : trsys state) (invariant : state -> Prop) s s',
  invariantFor sys invariant
  -> sys.(Step)^* s s'
  -> sys.(Initial) s
  -> invariant s'.
Proof.
  firstorder.
Qed.

Theorem invariant_weaken : forall {state} (sys : trsys state)
  (invariant1 invariant2 : state -> Prop),
  invariantFor sys invariant1
  -> (forall s, invariant1 s -> invariant2 s)
  -> invariantFor sys invariant2.
Proof.
  unfold invariantFor; intuition eauto.
Qed.

Theorem invariant_induction : forall {state} (sys : trsys state)
  (invariant : state -> Prop),
  (forall s, sys.(Initial) s -> invariant s)
  -> (forall s, invariant s -> forall s', sys.(Step) s s' -> invariant s')
  -> invariantFor sys invariant.
Proof.
  unfold invariantFor; intros.
  assert (invariant s) by eauto.
  clear H1.
  induction H2; eauto.
Qed.


Definition oneStepClosure_current {state} (sys : trsys state)
           (invariant1 invariant2 : state -> Prop) :=
  forall st, invariant1 st
             -> invariant2 st.

Definition oneStepClosure_new {state} (sys : trsys state)
           (invariant1 invariant2 : state -> Prop) :=
  forall st st', invariant1 st
                 -> sys.(Step) st st'
                 -> invariant2 st'.

Definition oneStepClosure {state} (sys : trsys state)
           (invariant1 invariant2 : state -> Prop) :=
  oneStepClosure_current sys invariant1 invariant2
  /\ oneStepClosure_new sys invariant1 invariant2.

Theorem prove_oneStepClosure : forall state (sys : trsys state) (inv1 inv2 : state -> Prop),
  (forall st, inv1 st -> inv2 st)
  -> (forall st st', inv1 st -> sys.(Step) st st' -> inv2 st')
  -> oneStepClosure sys inv1 inv2.
Proof.
  unfold oneStepClosure; tauto.
Qed.

Theorem oneStepClosure_done : forall state (sys : trsys state) (invariant : state -> Prop),
  (forall st, sys.(Initial) st -> invariant st)
  -> oneStepClosure sys invariant invariant
  -> invariantFor sys invariant.
Proof.
  unfold oneStepClosure, oneStepClosure_current, oneStepClosure_new.
  intuition eauto using invariant_induction.
Qed.

Inductive multiStepClosure {state} (sys : trsys state)
  : (state -> Prop) -> (state -> Prop) -> (state -> Prop) -> Prop :=
| MscDone : forall inv,
    (* oneStepClosure sys inv inv *)
    multiStepClosure sys inv ({ }) inv (* enforce worklist is empty and delete premise *)
| MscStep : forall inv worklist inv' inv'',
    oneStepClosure sys worklist inv'
    (* -> (forall st st', (inv \setminus worklist) st -> sys.(Step) st st' -> inv' st') *)
    -> multiStepClosure sys (inv \cup inv') (inv' \setminus inv) inv''
    -> multiStepClosure sys inv worklist inv''.

(* add extra hypothesis that says : (inv \ wl) o step \incl inv *)
Lemma multiStepClosure_ok' : forall state (sys : trsys state) (inv worklist inv' : state -> Prop),
    multiStepClosure sys inv worklist inv'
    -> forall wl,
        (forall st, sys.(Initial) st -> inv st)
      -> wl = worklist
      -> (forall st st', (inv \setminus wl) st -> sys.(Step) st st' -> inv st')
      -> invariantFor sys inv'.
Proof.
  induction 1; simpl; intros.
  - eapply invariant_induction; subst; sets idtac; eauto.
  - subst.
    eapply IHmultiStepClosure; intros; eauto.
    + apply H1 in H2; sets idtac.
    + assert (inv st) by (sets idtac).
      unfold oneStepClosure, oneStepClosure_current, oneStepClosure_new in H; destruct H.
      sets idtac.
      * assert (worklist st \/ ~ worklist st) as WL by sets idtac; destruct WL; eauto.
      * assert (worklist st \/ ~ worklist st) as WL by sets idtac; destruct WL; eauto.
Qed.

Theorem multiStepClosure_ok : forall state (sys : trsys state) (inv : state -> Prop),
  multiStepClosure sys sys.(Initial) sys.(Initial) inv
  -> invariantFor sys inv.
Proof.
  intros.
  eapply multiStepClosure_ok'; eauto.
  intros.
  sets idtac.
Qed.

Theorem oneStepClosure_empty : forall state (sys : trsys state),
  oneStepClosure sys (constant nil) (constant nil).
Proof.
  unfold oneStepClosure, oneStepClosure_current, oneStepClosure_new; intuition.
Qed.

Theorem oneStepClosure_split : forall state (sys : trsys state) st sts (inv1 inv2 : state -> Prop),
  (forall st', sys.(Step) st st' -> inv1 st')
  -> oneStepClosure sys (constant sts) inv2
  -> oneStepClosure sys (constant (st :: sts)) (constant (st :: nil) \cup inv1 \cup inv2).
Proof.
  unfold oneStepClosure, oneStepClosure_current, oneStepClosure_new; intuition.

  inversion H0; subst.
  unfold union; simpl; tauto.

  unfold union; simpl; eauto.

  unfold union in *; simpl in *.
  intuition (subst; eauto).
Qed.

Theorem singleton_in : forall {A} (x : A) rest,
  (constant (x :: nil) \cup rest) x.
Proof.
  unfold union; simpl; auto.
Qed.

Theorem singleton_in_other : forall {A} (x : A) (s1 s2 : set A),
  s2 x
  -> (s1 \cup s2) x.
Proof.
  unfold union; simpl; auto.
Qed.
