Require Export language.

(** * Run Time Checks *)
(** a subset of run time checks to be verified *)
(**
     - Division Check
       
       Check that the second operand of the the division, mod or rem 
       operation is different from zero.

     - Overflow Check

       Check that the result of the given arithmetic operation is within 
       the bounds of the base type.

     - Range Check
       
       Check that the given value is within the bounds of the expected scalar 
       subtype.
*)

(*   the following check is not included now

     - Index Check
       
       Check that the given index is within the bounds of the array.
*)

(** 
   reference: sinfo.ads
   --  Do_Range_Check (Flag9-Sem)
   --    This flag is set on an expression which appears in a context where a
   --    range check is required. The target type is clear from the context.
   --    The contexts in which this flag can appear are the following:

   --      Right side of an assignment. In this case the target type is
   --      taken from the left side of the assignment, which is referenced
   --      by the Name of the N_Assignment_Statement node.

   --      Subscript expressions in an indexed component. In this case the
   --      target type is determined from the type of the array, which is
   --      referenced by the Prefix of the N_Indexed_Component node.

   --      Argument expression for a parameter, appearing either directly in
   --      the Parameter_Associations list of a call or as the Expression of an
   --      N_Parameter_Association node that appears in this list. In either
   --      case, the check is against the type of the formal. Note that the
   --      flag is relevant only in IN and IN OUT parameters, and will be
   --      ignored for OUT parameters, where no check is required in the call,
   --      and if a check is required on the return, it is generated explicitly
   --      with a type conversion.

   --      Initialization expression for the initial value in an object
   --      declaration. In this case the Do_Range_Check flag is set on
   --      the initialization expression, and the check is against the
   --      range of the type of the object being declared. This includes the
   --      cases of expressions providing default discriminant values, and
   --      expressions used to initialize record components.

   --      The expression of a type conversion. In this case the range check is
   --      against the target type of the conversion. See also the use of
   --      Do_Overflow_Check on a type conversion. The distinction is that the
   --      overflow check protects against a value that is outside the range of
   --      the target base type, whereas a range check checks that the
   --      resulting value (which is a value of the base type of the target
   --      type), satisfies the range constraint of the target type.
*)


(** ** Run Time Check Flags *)
(** checks that are needed to be verified at run time *)
Inductive check_flag: Type := 
    | Do_Division_Check: check_flag
    | Do_Overflow_Check: check_flag
    | Do_Range_Check:    check_flag
    | Undefined_Check:   check_flag.


(** For an expression or statement, there may exists a list of checks 
    enforced on it, for example, for division expression, both
    division by zero and overflow checks are needed to be performed;
*)
Definition check_flags := list check_flag.

(** * Check Flags Comparison Functions *)

Function beq_check_flag (ck1 ck2: check_flag): bool :=
  match ck1, ck2 with
  | Do_Division_Check, Do_Division_Check => true
  | Do_Overflow_Check, Do_Overflow_Check => true
  | Do_Range_Check,    Do_Range_Check => true
  | _, _ => false
  end.

Function element_of (a: check_flag) (ls: list check_flag): bool :=
  match ls with
  | nil => false
  | (a' :: ls') => 
      if beq_check_flag a a' then
        true
      else
        element_of a ls'
  end.

Function subset_of (cks1 cks2: check_flags): bool :=
  match cks1 with
  | nil => true
  | ck :: cks1' => 
      if element_of ck cks2 then
        subset_of cks1' cks2 
      else
        false
  end.

Function beq_check_flags (cks1 cks2: check_flags): bool :=
  (subset_of cks1 cks2) && (subset_of cks2 cks1).

(** produce check flags for expressions according to the checking rules; 
    it is a mapping from one ast node to a set of run time checks;
*)

(** ** Run Time Check Flags Generator *)

(*
Inductive gen_exp_check_flags: expression -> check_flags -> Prop :=
    | GCF_Literal_Int: forall ast_num n,
        gen_exp_check_flags (E_Literal ast_num (Integer_Literal n)) nil
    | GCF_Literal_Bool: forall ast_num b,
        gen_exp_check_flags (E_Literal ast_num (Boolean_Literal b)) nil
    | GCF_Name: forall ast_num n,
        gen_exp_check_flags (E_Name ast_num n) nil
    | GCF_Binary_Operation_Plus: forall ast_num e1 e2,
        gen_exp_check_flags (E_Binary_Operation ast_num Plus e1 e2) (Do_Overflow_Check :: nil)
    | GCF_Binary_Operation_Minus: forall ast_num e1 e2,
        gen_exp_check_flags (E_Binary_Operation ast_num Minus e1 e2) (Do_Overflow_Check :: nil)
    | GCF_Binary_Operation_Multiply: forall ast_num e1 e2,
        gen_exp_check_flags (E_Binary_Operation ast_num Multiply e1 e2) (Do_Overflow_Check :: nil)
    | GCF_Binary_Operation_Div: forall ast_num e1 e2,
        gen_exp_check_flags (E_Binary_Operation ast_num Divide e1 e2) (Do_Division_Check :: Do_Overflow_Check :: nil)
    | GCF_Binary_Operation_Others: forall ast_num op e1 e2,
        op <> Plus ->
        op <> Minus ->
        op <> Multiply ->
        op <> Divide ->
        gen_exp_check_flags (E_Binary_Operation ast_num op e1 e2) nil
    | GCF_Unary_Operation_Minus: forall ast_num e,
        gen_exp_check_flags (E_Unary_Operation ast_num Unary_Minus e) (Do_Overflow_Check :: nil)
    | GCF_Unary_Operation_Others: forall ast_num op e,
        op <> Unary_Minus ->
        gen_exp_check_flags (E_Unary_Operation ast_num op e) nil.

Inductive gen_name_check_flags: name -> check_flags -> Prop :=
    | GNCF_Identifier: forall ast_num x,
        gen_name_check_flags (E_Identifier ast_num x) nil
    | GNCF_Indexed_Component: forall ast_num x_ast_num x e,
        gen_name_check_flags (E_Indexed_Component ast_num x_ast_num x e) (Do_Index_Check :: nil)
    | GNCF_Selected_Component: forall ast_num x_ast_num x f,
        gen_name_check_flags (E_Selected_Component ast_num x_ast_num x f) nil.


(** ** Run Time Check Flags Generator Function *)

Function gen_exp_check_flags_f (e: expression): check_flags :=
  match e with
  | E_Literal ast_num (Integer_Literal n) => nil
  | E_Literal ast_num (Boolean_Literal b) => nil
  | E_Name ast_num n => nil
  | E_Binary_Operation ast_num Plus e1 e2 => (Do_Overflow_Check :: nil)
  | E_Binary_Operation ast_num Minus e1 e2 => (Do_Overflow_Check :: nil)
  | E_Binary_Operation ast_num Multiply e1 e2 => (Do_Overflow_Check :: nil)
  | E_Binary_Operation ast_num Divide e1 e2 => (Do_Division_Check :: Do_Overflow_Check :: nil)
  | E_Unary_Operation ast_num Unary_Minus e => (Do_Overflow_Check :: nil)
  | _ => nil
  end.

Function gen_name_check_flags_f (n: name): check_flags :=
  match n with
  | E_Identifier ast_num x => nil
  | E_Indexed_Component ast_num x_ast_num x e => (Do_Index_Check :: nil)
  | E_Selected_Component ast_num x_ast_num x f => nil
  end.

(** ** Semantics Equivalence Proof *)

Lemma gen_exp_check_flags_f_correctness: forall e flags,
  gen_exp_check_flags_f e = flags ->
    gen_exp_check_flags e flags.
Proof.
  intros; destruct e.
- destruct l; smack; constructor.
- smack; constructor.
- smack; destruct b; constructor; smack. 
- smack; destruct u; constructor; smack.
Qed.

Lemma gen_name_check_flags_f_correctness: forall n flags,
  gen_name_check_flags_f n = flags ->
    gen_name_check_flags n flags.
Proof.
  intros; destruct n;
  smack; constructor.
Qed.
*)
