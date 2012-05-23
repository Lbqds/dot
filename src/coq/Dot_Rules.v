(** The DOT calculus -- Rules *)

Require Export Dot_Labels.
Require Import Metatheory.
Require Export Dot_Syntax Dot_Definitions.

(* ********************************************************************** *)
(** * #<a name="red"></a># Reduction *)
Reserved Notation "s |~ a ~~> b  ~| s'" (at level 60).

(* ********************************************************************** *)
(** * #<a name="ev"></a># Evaluation *)
Reserved Notation "s |~ a ~>~ b ~| s'" (at level 60).

(* ********************************************************************** *)
(** * #<a name="typing"></a># Typing *)
(* Type Equivalence *)
Reserved Notation "E |= T ~=: T'" (at level 69).
(* Type Assigment *)
Reserved Notation "E |= t ~: T" (at level 69).
(* Membership *)
Reserved Notation "E |= t ~mem~ l ~: D" (at level 69).
(* Expansion *)
Reserved Notation "E |= T ~< DS" (at level 69).
(* Subtyping *)
Reserved Notation "E |= t ~<: T" (at level 69).
(* Declaration subsumption *)
(* E |= D ~<: D' *)
(* Well-formed types *)
(* E |= T ~wf~ *)
(* Well-formed declarations *)
(* E |= D ~wf *)


Inductive value_to_ref : tm -> tm -> Prop :=
  | value_to_ref_ref : forall a, value_to_ref (ref a) (ref a)
  | value_to_ref_wid : forall a v t, value_to_ref v (ref a) -> value_to_ref (wid v t) (ref a)
.

Inductive path_red : env -> tm -> tm -> Prop :=
  | path_red_base : forall G s Tc ags v v' l a a',
     binds a (Tc, ags) s ->
     lbl.binds l v' ags ->
     value_label l ->
     value_to_ref v (ref a) ->
     value_to_ref v' (ref a') ->
     path_red (G, s) (sel v l) (ref a')
  | path_red_wid : forall E p T,
     path p ->
     path_red E (wid p T) p
  | path_red_sel : forall E l p p',
     path p ->
     path_red E p p' ->
     path_red E (sel p l) (sel p' l)
.

Inductive up_value : store -> tm -> label -> tm -> tm -> Prop :=
  | up_value_var : forall s a l v,
     value_label l ->
     up_value s (ref a) l v v
  | up_value_wid : forall s v T l v' T',
     value_label l ->
     value v ->
     (nil, s) |= (wid v T) ~mem~ l ~: (decl_tm T') ->
     up_value s (wid v T) l v' (wid v' T')

with up_method : store -> tm -> label -> tm -> tm -> tm -> Prop :=
  | up_method_var : forall s a m v t,
     method_label m ->
     up_method s (ref a) m v t (t ^^ v)
  | up_method_wid : forall s v T m v' t' a S' T' S'' T'',
     method_label m ->
     value v ->
     (nil, s) |= (wid v T) ~mem~ m ~: (decl_mt S' T') ->
     value_to_ref v (ref a) ->
     (nil, s) |= (ref a) ~mem~ m ~: (decl_mt S'' T'') ->
     up_method s (wid v T) m v' t' (wid (t' ^^ (wid v' S'')) T')

with red : store -> tm -> store -> tm -> Prop :=
(*| red_beta : forall s T t v,
     wf_store s ->
     lc_tm (lam T t) ->
     value v ->
     s |~ (app (lam T t)) v ~~> (t ^^ v) ~| s*)
(*| red_app_fun : forall s s' t e e',
     lc_tm t ->
     s |~        e ~~> e'        ~| s' ->
     s |~  app e t ~~> app e' t  ~| s'*)
(*| red_app_arg : forall s s' v e e',
     value v ->
     s |~        e ~~> e'        ~| s' ->
     s |~  app v e ~~> app v e'  ~| s'*)
  | red_msel : forall s a Tc ags l t v v' t',
     wf_store s ->
     binds a (Tc, ags) s ->
     lbl.binds l t ags ->
     method_label l ->
     value v' ->
     value v ->
     value_to_ref v (ref a) ->
     up_method s v l v' t t' ->
     s |~ (msel v l v') ~~> t' ~| s
  | red_msel_tgt1 : forall s s' l e1 e2 e1',
     s |~             e1 ~~> e1'             ~| s' ->
     s |~ (msel e1 l e2) ~~> (msel e1' l e2) ~| s'
  | red_msel_tgt2 : forall s s' l v1 e2 e2',
    value v1 ->
     s |~             e2 ~~> e2'             ~| s' ->
     s |~ (msel v1 l e2) ~~> (msel v1 l e2') ~| s'
  | red_sel : forall s a Tc ags l v v' v'',
     wf_store s -> 
     binds a (Tc, ags) s ->
     lbl.binds l v' ags ->
     value_label l ->
     value v ->
     value_to_ref v (ref a) ->
     up_value s v l v' v'' ->
     s |~ (sel v l) ~~> v'' ~| s
  | red_sel_tgt : forall s s' l e e',
     s |~         e ~~> e'         ~| s' ->
     s |~ (sel e l) ~~> (sel e' l) ~| s'
  | red_wid_tgt : forall s s' e e' t,
     s |~         e ~~> e'         ~| s' ->
     s |~ (wid e t) ~~> (wid e' t) ~| s'
  | red_new : forall s Tc a ags t,
     wf_store s -> 
     lc_tm (new Tc ags t) ->
     concrete Tc ->
     (forall l v, lbl.binds l v (ags ^args^ ref a) -> (value_label l /\ value v) \/ (method_label l)) ->
     a `notin` dom s ->
     s |~   (new Tc ags t) ~~> t ^^ (ref a)   ~| ((a ~ ((Tc, ags ^args^ (ref a)))) ++ s)
where "s |~ a ~~> b  ~| s'" := (red s a s' b)

with ev : store -> tm -> store -> tm -> Prop :=
  | ev_value : forall s v,
     wf_store s ->
     value v ->
     s |~ v ~>~ v ~| s
  | ev_wid : forall s s' e t v,
     s |~ e ~>~ v ~| s' ->
     s |~ (wid e t) ~>~ (wid v t) ~| s'
(*| ev_beta : forall si s1 s2 sf t1 t2 t11 v2 vf T,
     si |~ t1 ~>~ (lam T t11) ~| s1 ->
     lc_tm (lam T t11) ->
     s1 |~ t2 ~>~ v2 ~| s2 ->
     s2 |~ (t11 ^^ v2) ~>~ vf ~| sf ->
     si |~ (app t1 t2) ~>~ vf ~| sf*)
  | ev_msel : forall si s1 s2 sf va a Tc ags l t tl t' v' v tl',
     si |~ t ~>~ va ~| s1 ->
     value_to_ref va (ref a) ->
     s1 |~ t' ~>~ v' ~| s2 ->
     binds a (Tc, ags) sf ->
     lbl.binds l tl ags ->
     method_label l ->
     up_method s2 va l v' tl tl' ->
     s2 |~ tl' ~>~ v ~| sf ->
     si |~ (msel t l t') ~>~ v ~| sf
  | ev_sel : forall si sf va a Tc ags t l v v',
     si |~ t ~>~ va ~| sf ->
     value_to_ref va (ref a) ->
     binds a (Tc, ags) sf ->
     lbl.binds l v ags ->
     value_label l ->
     up_value sf va l v v' ->
     si |~ (sel t l) ~>~ v' ~| sf
  | ev_new : forall si sf a Tc ags t vf,
     lc_tm (new Tc ags t) ->
     concrete Tc ->
     (forall l v, lbl.binds l v ags -> (value_label l /\ value (v ^^ (ref a))) \/ (method_label l)) ->
     a `notin` dom si ->
     ((a ~ ((Tc, ags ^args^ (ref a)))) ++ si) |~ t ~>~ vf ~| sf ->
     si |~ (new Tc ags t) ~>~ vf ~| sf
where "s |~ a ~>~ b  ~| s'" := (ev s a s' b)

with same_tp : env -> tp -> tp -> Prop :=
  | same_tp_any : forall E T T',
      E |= T ~<: T' ->
      E |= T' ~<: T ->
      E |= T ~=: T'
where "E |= T ~=: T'" := (same_tp E T T')

with typing : env -> tm -> tp -> Prop :=
  | typing_var : forall G P x T,
      wf_env (G, P) ->
      lc_tp T ->
      binds x T G ->
      (G, P) |= (fvar x) ~: T
  | typing_ref : forall G P a T args,
      wf_env (G, P) ->
      binds a (T, args) P ->
      (G, P) |= (ref a) ~: T
  | typing_wid : forall E t T T',
      E |= t ~: T' ->
      E |= T' ~<: T ->
      E |= (wid t T) ~: T
  | typing_sel : forall E t l T',
      value_label l ->
      E |= t ~mem~ l ~: (decl_tm T') ->
      wfe_tp E T' ->
      E |= (sel t l) ~: T'
  | typing_msel : forall E t t' l S T T',
      method_label l ->
      E |= t ~mem~ l ~: (decl_mt S T) ->
      E |= t' ~: T' ->
      E |= T' ~=: S ->
      wfe_tp E T ->
      E |= (msel t l t') ~: T
(* | typing_app : forall E t t' S T T',
      E |= t ~: (tp_fun S T) ->
      E |= t' ~: T' ->
      E |= T' ~<: S ->
      E |= (app t t') ~: T*)
(* | typing_abs : forall L E S t T,
      wfe_tp E S ->
      (forall x, x \notin L -> (ctx_bind E x S) |= (t ^ x) ~: T) ->
      E |= (lam S t) ~: (tp_fun S T)*)
  | typing_new : forall L L' E Tc args t T' ds,
      wfe_tp E Tc ->
      concrete Tc ->
      E |= Tc ~< ds ->
      lbl.uniq args ->
      (forall l v, lbl.binds l v args -> (value_label l \/ method_label l) /\ (exists d, decls_binds l d ds)) ->
      (forall x, x \notin L ->
        (forall l d, decls_binds l d ds ->
          (forall S U, d ^d^ x = decl_tp S U -> (ctx_bind E x Tc) |= S ~<: U) /\
          (forall S U, d ^d^ x = decl_mt S U -> (exists v,
            lbl.binds l v args /\ (forall y, y \notin L' ->
              (exists U', (ctx_bind (ctx_bind E x Tc) y S) |= ((v ^ x) ^ y) ~: U' /\ (ctx_bind (ctx_bind E x Tc) y S) |= U' ~=: U)))) /\
          (forall V, d ^d^ x = decl_tm V -> (exists v,
            lbl.binds l v args /\ syn_value (v ^ x) /\ (exists V', (ctx_bind E x Tc) |= (v ^ x) ~: V' /\ (ctx_bind E x Tc) |= V' ~=: V))))) ->
      (forall x, x \notin L -> (ctx_bind E x Tc) |= t ^ x ~: T') ->
      E |= (new Tc args t) ~: T'
where "E |= t ~: T" := (typing E t T)

with mem : env -> tm -> label -> decl -> Prop :=
  | mem_path : forall E p l T DS D,
      path p ->
      E |= p ~: T ->
      expands E T DS ->
      decls_binds l D DS ->
      mem E p l (D ^d^ p)
  | mem_term : forall E t l T DS D,
      E |= t ~: T ->
      expands E T DS ->
      decls_binds l D DS ->
      lc_decl D ->
      mem E t l D
where "E |= t ~mem~ l ~: D" := (mem E t l D)

with expands : env -> tp -> decls -> Prop :=
  | expands_rfn : forall E T DSP DS DSM,
      expands E T DSP ->
      and_decls DSP (decls_fin DS) DSM ->
      expands E (tp_rfn T DS) DSM
  | expands_tsel : forall E p L S U DS,
      path p ->
      type_label L ->
      E |= p ~mem~ L ~: (decl_tp S U) ->
      expands E U DS ->
      expands E (tp_sel p L) DS
  | expands_and : forall E T1 DS1 T2 DS2 DSM,
      expands E T1 DS1 ->
      expands E T2 DS2 ->
      and_decls DS1 DS2 DSM ->
      expands E (tp_and T1 T2) DSM
  | expands_or : forall E T1 DS1 T2 DS2 DSM,
      expands E T1 DS1 ->
      expands E T2 DS2 ->
      or_decls DS1 DS2 DSM ->
      expands E (tp_or T1 T2) DSM
  | expands_top : forall E,
      wf_env E ->
      expands E tp_top (decls_fin nil)
(*| expands_fun : forall E S T,
      wf_env E ->
      expands E (tp_fun S T) (decls_fin nil)*)
  | expands_bot : forall E DS,
      wf_env E ->
      bot_decls DS ->
      expands E tp_bot DS
where "E |= T ~< DS" := (expands E T DS)

with sub_tp : env -> tp -> tp -> Prop :=
  | sub_tp_refl : forall E T,
      wf_env E -> wfe_tp E T ->
      E |= T ~<: T
(*| sub_tp_fun : forall E S1 S2 T1 T2,
      E |= T1 ~<: S1 ->
      E |= S2 ~<: T2 ->
      E |= (tp_fun S1 S2) ~<: (tp_fun T1 T2)*)
  | sub_tp_rfn_r : forall L E S T DS' DS,
      E |= S ~<: T ->
      E |= S ~< DS' ->
      decls_ok (decls_fin DS) ->       
      (forall z, z \notin L -> forall_decls (ctx_bind E z S) (DS' ^ds^ z) ((decls_fin DS) ^ds^ z) sub_decl) ->
      decls_dom_subset (decls_fin DS) DS' ->
      wfe_tp E (tp_rfn T DS) ->
      E |= S ~<: (tp_rfn T DS)
  | sub_tp_rfn_l : forall E T T' DS,
      E |= T ~<: T' ->
      decls_ok (decls_fin DS) ->
      wfe_tp E (tp_rfn T DS) ->
      E |= (tp_rfn T DS) ~<: T'
  | sub_tp_tsel_r : forall E p L S U S',
      path p ->
      type_label L ->
      E |= p ~mem~ L ~: (decl_tp S U) ->
      E |= S ~<: U ->
      E |= S' ~<: S ->
      E |= S' ~<: (tp_sel p L)
  | sub_tp_tsel_l : forall E p L S U U',
      path p ->
      type_label L ->
      E |= p ~mem~ L ~: (decl_tp S U) ->
      E |= S ~<: U ->
      E |= U ~<: U' ->
      E |= (tp_sel p L) ~<: U'
  | sub_tp_and_r : forall E T T1 T2,
      E |= T ~<: T1 -> E |= T ~<: T2 ->
      E |= T ~<: (tp_and T1 T2)
  | sub_tp_and_l1 : forall E T T1 T2,
      wf_env E -> wfe_tp E T2 ->
      E |= T1 ~<: T ->
      E |= (tp_and T1 T2) ~<: T
  | sub_tp_and_l2 : forall E T T1 T2,
      wf_env E -> wfe_tp E T1 ->
      E |= T2 ~<: T ->
      E |= (tp_and T1 T2) ~<: T
  | sub_tp_or_r1 : forall E T T1 T2,
      wf_env E -> wfe_tp E T2 ->
      E |= T ~<: T1 ->
      E |= T ~<: (tp_or T1 T2)
  | sub_tp_or_r2 : forall E T T1 T2,
      wf_env E -> wfe_tp E T1 ->
      E |= T ~<: T2 ->
      E |= T ~<: (tp_or T1 T2)
  | sub_tp_or_l : forall E T T1 T2,
      E |= T1 ~<: T -> E |= T2 ~<: T ->
      E |= (tp_or T1 T2) ~<: T
  | sub_tp_top : forall E T,
      wf_env E -> wfe_tp E T ->
      E |= T ~<: tp_top
  | sub_tp_bot : forall E T,
      wf_env E -> wfe_tp E T ->
      E |= tp_bot ~<: T
  | sub_tp_path_red : forall E T p p' L,
      wfe_tp E (tp_sel p L) ->
      path_red E p p' ->
      E |= T ~<: (tp_sel p' L) ->
      E |= T ~<: (tp_sel p L)
where "E |= S ~<: T" := (sub_tp E S T)

with sub_decl : env -> decl -> decl -> Prop :=
  | sub_decl_tp : forall E S1 T1 S2 T2,
      E |= S2 ~<: S1 ->
      E |= T1 ~<: T2 ->
      sub_decl E (decl_tp S1 T1) (decl_tp S2 T2)
  | sub_decl_tm : forall E T1 T2,
      E |= T1 ~<: T2 ->
      sub_decl E (decl_tm T1) (decl_tm T2)

with wf_tp : env -> tp -> Prop :=
  | wf_rfn : forall L E T DS,
      decls_ok (decls_fin DS) ->
      wfe_tp E T ->
      (forall z, z \notin L ->
        forall l d, decls_binds l d (decls_fin DS) -> (wf_decl (ctx_bind E z (tp_rfn T DS)) (d ^d^ z))) ->
      wf_tp E (tp_rfn T DS)
(*| wf_fun : forall E T1 T2,
      wfe_tp E T1 ->
      wfe_tp E T2 ->
      wf_tp E (tp_fun T1 T2)*)
  | wf_tsel_1 : forall E p L S U,
      path p ->
      type_label L ->
      E |= p ~mem~ L ~: (decl_tp S U) ->
      wfe_tp E S ->
      wfe_tp E U ->
      wf_tp E (tp_sel p L)
  | wf_tsel_2 : forall E p L U,
      path p ->
      type_label L ->
      E |= p ~mem~ L ~: (decl_tp tp_bot U) ->
      wf_tp E (tp_sel p L)
  | wf_and : forall E T1 T2,
      wfe_tp E T1 ->
      wfe_tp E T2 ->
      wf_tp E (tp_and T1 T2)
  | wf_or : forall E T1 T2,
      wfe_tp E T1 ->
      wfe_tp E T2 ->
      wf_tp E (tp_or T1 T2)
  | wf_bot : forall E,
      wf_tp E tp_bot
  | wf_top : forall E,
      wf_tp E tp_top

with wf_decl : env -> decl -> Prop :=
  | wf_decl_tp : forall E S U,
      wfe_tp E S ->
      wfe_tp E U ->
      wf_decl E (decl_tp S U)
  | wf_decl_tm : forall E T,
      wfe_tp E T ->
      wf_decl E (decl_tm T)

with wfe_tp : env -> tp -> Prop :=
  | wfe_any : forall E T DT,
      wf_tp E T ->
      E |= T ~< DT ->
      wfe_tp E T
.

(* ********************************************************************** *)
(** * #<a name="auto"></a># Automation *)

Scheme same_tp_indm        := Induction for same_tp Sort Prop
  with typing_indm         := Induction for typing Sort Prop
  with mem_indm            := Induction for mem Sort Prop
  with expands_indm        := Induction for expands Sort Prop
  with sub_tp_indm         := Induction for sub_tp Sort Prop
  with sub_decl_indm       := Induction for sub_decl Sort Prop
  with wf_tp_indm          := Induction for wf_tp Sort Prop
  with wf_decl_indm        := Induction for wf_decl Sort Prop
  with wfe_tp_indm         := Induction for wfe_tp Sort Prop
.

Combined Scheme typing_mutind from same_tp_indm, typing_indm, mem_indm, expands_indm, sub_tp_indm, sub_decl_indm, wf_tp_indm, wf_decl_indm, wfe_tp_indm.

Require Import LibTactics_sf.
Ltac mutind_typing P0_ P1_ P2_ P3_ P4_ P5_ P6_ P7_ P8_ :=
  cut ((forall E T T' (H: E |= T ~=: T'), (P0_ E T T' H)) /\
  (forall E t T (H: E |= t ~: T), (P1_ E t T H)) /\
  (forall E t l d (H: E |= t ~mem~ l ~: d), (P2_ E t l d H)) /\
  (forall E T DS (H: E |= T ~< DS), (P3_ E T DS H)) /\
  (forall E T T' (H: E |= T ~<: T'), (P4_  E T T' H))  /\
  (forall (e : env) (d d' : decl) (H : sub_decl e d d'), (P5_ e d d' H)) /\
  (forall (e : env) (t : tp) (H : wf_tp e t), (P6_ e t H)) /\
  (forall (e : env) (d : decl) (H : wf_decl e d), (P7_ e d H)) /\
  (forall (e : env) (t : tp) (H : wfe_tp e t), (P8_ e t H))); [tauto |
    apply (typing_mutind P0_ P1_ P2_ P3_ P4_ P5_ P6_ P7_); try unfold P0_, P1_, P2_, P3_, P4_, P5_, P6_, P7_, P8_ in *; try clear P0_ P1_ P2_ P3_ P4_ P5_ P6_ P7_ P8_; [  (* only try unfolding and clearing in case the PN_ aren't just identifiers *)
      Case "same_tp_any" | Case "typing_var" | Case "typing_ref" | Case "typing_wid" | Case "typing_sel" | Case "typing_msel" | Case "typing_new" | Case "mem_path" | Case "mem_term" | Case "expands_rfn" | Case "expands_tsel" | Case "expands_and" | Case "expands_or" | Case "expands_top" | Case "expands_bot" | Case "sub_tp_refl" | Case "sub_tp_rfn_r" | Case "sub_tp_rfn_l" | Case "sub_tp_tsel_r" | Case "sub_tp_tsel_l" | Case "sub_tp_and_r" | Case "sub_tp_and_l1" | Case "sub_tp_and_l2" | Case "sub_tp_or_r1" | Case "sub_tp_or_r2" | Case "sub_tp_or_l" | Case "sub_tp_top" | Case "sub_tp_bot" | Case "sub_tp_path_red" | Case "sub_decl_tp" | Case "sub_decl_tm" | Case "wf_rfn" | Case "wf_tsel_1" | Case "wf_tsel_2" | Case "wf_and" | Case "wf_or" | Case "wf_bot" | Case "wf_top" | Case "wf_decl_tp" | Case "wf_decl_tm" | Case "wfe_any" ];
      introv; eauto ].

Section TestMutInd.
(* mostly reusable boilerplate for the mutual induction: *)
  Let Psame (E: env) (T: tp) (T': tp) (H: E |=  T ~=: T') := True.
  Let Ptyp (E: env) (t: tm) (T: tp) (H: E |=  t ~: T) := True.
  Let Pmem (E: env) (t: tm) (l: label) (d: decl) (H: E |= t ~mem~ l ~: d) := True.
  Let Pexp (E: env) (T: tp) (DS : decls) (H: E |= T ~< DS) := True.
  Let Psub (E: env) (T T': tp) (H: E |= T ~<: T') := True.
  Let Psbd (E: env) (d d': decl) (H: sub_decl E d d') := True.
  Let Pwft (E: env) (t: tp) (H: wf_tp E t) := True.
  Let Pwfd (E: env) (d: decl) (H: wf_decl E d) := True.
  Let Pwfe (E: env) (t: tp) (H: wfe_tp E t) := True.
Lemma EnsureMutindTypingTacticIsUpToDate : True.
Proof. mutind_typing Psame Ptyp Pmem Pexp Psub Psbd Pwft Pwfd Pwfe; intros; auto. Qed.
End TestMutInd.
