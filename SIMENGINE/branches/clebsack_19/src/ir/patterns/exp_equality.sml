structure ExpEquality =
struct

(* two helper functions that operate the same way as andalso and orelse, 
 just with an extra output argument *)
fun andcond ((pat1, bool1), (pat2, bool2)) =
    if bool1 then
	(pat2, bool2)
    else
	(pat1, bool1)
infix andcond

fun orcond ((pat1, bool1), (pat2, bool2)) =
    if bool1 then
	(pat1, bool1)
    else
	(pat2, bool2)
infix orcond

(* helper function for All *)
fun allEquiv comparefun assigned_patterns (nil, nil) = (assigned_patterns, true)
  | allEquiv comparefun assigned_patterns (term1::rest1, term2::rest2) =
    let
	val (assigned_patterns', result) = comparefun assigned_patterns (term1, term2)
    in
	if result then
	    allEquiv comparefun assigned_patterns' (rest1, rest2)
	else
	    (assigned_patterns, result)
    end
  | allEquiv comparefun assigned_patterns _ = (assigned_patterns, false)


(* Check if terms are equivalent *)
fun terms_equivalent assigned_patterns (term1, term2) = 
    case (term1, term2) of 

	(* Start off on the simple cases *)
	(Exp.RATIONAL (a1,b1), Exp.RATIONAL (a2,b2)) => 
	(assigned_patterns, 
	 (a1=a2 andalso b1=b2) (* general case *)
	 orelse (* otherwise, if they are multiples*)
	 (Real.==((Real.fromInt(a1))/(Real.fromInt(a2)),(Real.fromInt(a1))/(Real.fromInt(a2))))
	)
      | (Exp.INT a1, Exp.INT a2) => 
	(assigned_patterns,
	 a1 = a2
	)
      | (Exp.REAL a1, Exp.REAL a2) => 
	(assigned_patterns,
	 Real.==(a1, a2)
	)
      | (Exp.COMPLEX (r1, i1), Exp.COMPLEX (r2, i2)) => 

	allEquiv terms_equivalent assigned_patterns ([r1, i1], [r2, i2])
      | (Exp.LIST (l1, d1), Exp.LIST (l2, d2)) => 
	(* first check the list sizes *)
	(assigned_patterns, 
	 (List.length l1) = (List.length l2) 
	)
	    andcond (* check the number of dimensions *)
	    (assigned_patterns,
	     (List.length d1) = (List.length l2)
	    )
	    andcond (* check that the dimensions are organized in the same way *)
	    (assigned_patterns, 
	     (List.all (fn(s1, s2)=> s1=s2) (ListPair.zip (d1, d2)))
	    )
	    andcond (* check that all the terms are the same *)
	    (allEquiv terms_equivalent assigned_patterns (l1, l2))
      | (Exp.TUPLE l1, Exp.TUPLE l2) =>
	(* first check the list sizes *)
	(assigned_patterns, 
	 (List.length l1) = (List.length l2) 
	)
	    andcond (* check that all the terms are the same *)
	    (allEquiv terms_equivalent assigned_patterns (l1, l2))
      | (Exp.SYMBOL (s1, p1), Exp.SYMBOL (s2, p2)) =>
	(* symbol names must be the same *)
	(assigned_patterns,
	 s1 = s2
	)
	    andcond (* check the properties are the same *)
	    (* start with diff *)
	    (case (Property.getDerivative p1, Property.getDerivative p2)
	      of (NONE, NONE) => (assigned_patterns, true)
	       | (SOME (o1, l1), SOME (o2, l2)) => 
		 (* check the order *)
		 (assigned_patterns, 
		  o1 = o2
		 )
		     andcond (* check the list of iterators *)
		     (* check the size *)
		     (assigned_patterns,
		      length l1 = length l2)
		     andcond
		     (assigned_patterns,
		      List.all (fn(a,b)=>a=b) (ListPair.zip (l1, l2)))
		 
	       | _ => (assigned_patterns, false))
	    andcond
	    (* check the iterator lists *)
	    (case (Property.getIterator p1, Property.getIterator p2)
	      of (NONE, NONE) => (assigned_patterns, true)
	       | (SOME l1, SOME l2) => 
		 (* check the size *)
		 (assigned_patterns,
		  length l1 = length l2
		 )
		     andcond
		     (assigned_patterns,
		      List.all Iterator.iter_equiv (ListPair.zip (l1, l2)))
	       | _ => (assigned_patterns, false))
      | (Exp.INFINITY, Exp.INFINITY) => (assigned_patterns, true)
      | (Exp.NAN, Exp.NAN) => (assigned_patterns, true)
      | (Exp.DONTCARE, _) => (assigned_patterns, true)
      | (_, Exp.DONTCARE) => (assigned_patterns, true)
      (* now handle some of the other cases *)
      | (t1, Exp.PATTERN p2) => pattern_equivalent assigned_patterns (p2, Exp.TERM t1)
      | (Exp.PATTERN p1, t2) => pattern_equivalent assigned_patterns (p1, Exp.TERM t2)
      | _ => (*if (isNumeric term1) andalso (isNumeric term2) then
		   if (termCount term1) = (termCount term2) then*)
	(assigned_patterns, false)

and pattern_equivalent assigned_patterns (pat as (sym, (_,pred), patcount), exp) =
    case List.find (fn(s, e)=> s=sym) assigned_patterns of
	SOME (s, e) => (exp_equivalent assigned_patterns (exp, e))
      | NONE => if pred exp then 
		  ((sym, exp)::assigned_patterns, true)
		else
		    (assigned_patterns, false)
	
(* Check if two expressions are equivalent *)
and exp_equivalent assigned_patterns (exp1, exp2) = 
    case (exp1, exp2) of
	(Exp.TERM t1, Exp.TERM t2) => terms_equivalent assigned_patterns (t1, t2)
      | (Exp.FUN (Fun.BUILTIN fun1, args1), Exp.FUN (Fun.BUILTIN fun2, args2)) => 
	if fun1 = fun2 then
	    allEquiv exp_equivalent assigned_patterns (args1, args2)
	else
	    (assigned_patterns, false)
      | (Exp.FUN (Fun.INST {classname=classname1,...},args1),
	 Exp.FUN (Fun.INST {classname=classname2,...},args2)) =>
	if classname1=classname2 then
	    allEquiv exp_equivalent assigned_patterns (args1, args2)
	else
	    (assigned_patterns, false)
      | (Exp.FUN _, Exp.FUN _) => (assigned_patterns, false)
      (* need to handle patterns *)
      | (exp1, Exp.TERM (Exp.PATTERN p)) => pattern_equivalent assigned_patterns (p, exp1)
      | (Exp.TERM (Exp.PATTERN p), exp2) => pattern_equivalent assigned_patterns (p, exp2)
      | _ => (assigned_patterns, false)

(* Perform equivalency check on expressions *)
and equiv (exp1, exp2) = 
    let
	val (assigned_patterns, result) = exp_equivalent [] (exp1, exp2)
    in
	result
    end

fun findMatches (exp1, exp2) =
    let
	val (assigned_patterns, result) = exp_equivalent [] (exp1, exp2)
    in
	assigned_patterns
    end

end
