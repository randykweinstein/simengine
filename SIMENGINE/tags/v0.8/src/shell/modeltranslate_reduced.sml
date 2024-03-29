signature MODELTRANSLATE =
sig
    (* The string returned by translate is the name of the model *)
    val translate : ((KEC.exp -> KEC.exp) * KEC.exp) -> (DOF.model) option
end

structure ModelTranslate : MODELTRANSLATE=
struct
fun translate (exec, object) =
    let
	(* helper methods *)
	val pretty = PrettyPrint.kecexp2prettystr exec

	val TypeMismatch = DynException.TypeMismatch
	and ValueError = DynException.ValueError

	(* This method assumes the exp has already been exec'd *)
	fun exp2bool (KEC.LITERAL(KEC.CONSTBOOL b)) =
	    b
	  | exp2bool exp =
	    DynException.stdException ("Expected a boolean but received " ^ (PrettyPrint.kecexp2nickname exp) ^ ": " ^ (pretty exp), "ModelTranslate.translate.exp2bool", Logger.INTERNAL)


	(* This method assumes the exp has already been exec'd *)
	fun exp2real (KEC.LITERAL(KEC.CONSTREAL b)) =
	    b
	  | exp2real exp =
	    DynException.stdException ("Expected a number but received " ^ (PrettyPrint.kecexp2nickname exp) ^ ": " ^ (pretty exp), "ModelTranslate.translate.exp2real", Logger.INTERNAL)

	fun exp2realoption (KEC.UNDEFINED) =
	    NONE 
	  | exp2realoption r =
	    SOME (exp2real r)

	fun real2exp r =
	    KEC.LITERAL (KEC.CONSTREAL r)

	fun int2exp i =
	    KEC.LITERAL (KEC.CONSTREAL (Real.fromInt i))


	(* This method assumes the exp has already been exec'd *)
	fun exp2str (KEC.LITERAL (KEC.CONSTSTR s)) = s
	  | exp2str exp =
	    DynException.stdException ("Expected a string but received " ^ (PrettyPrint.kecexp2nickname exp) ^ ": " ^ (pretty exp), "ModelTranslate.translate.exp2str", Logger.INTERNAL)
	    
	(* Returns a SYMBOL expression with the given name. *)
	fun sym s = KEC.SYMBOL (Symbol.symbol s)
		    
	(* Returns an object instance method or attribute. *)
	fun method name object =    
	    exec (KEC.SEND {message=Symbol.symbol name, object=object})

	(* Evaluates a function application. *)
	fun apply (f, a) = exec (KEC.APPLY {func=f, args=KEC.TUPLE a})

	(* Applies an object instance method to the given arguments. *)
	fun send message object args = 
	    case args of
		SOME args' => apply (method message object, args')
	      | NONE => apply (method message object, [])


	fun dslname obj = method "dslname" obj
	fun getInitialValue obj = send "getInitialValue" obj NONE

	(* Indicates whether an object conforms to a type using the DSL typechecker. *)
	fun istype (object, typ) =
	    let
		val checkexp = 
		    KEC.LIBFUN (Symbol.symbol "istype", KEC.TUPLE [KEC.TYPEEXP (KEC.TYPE (Symbol.symbol typ)),
								   object])

		val result = exec checkexp
	    in
		exp2bool result
	    end
	    
	    
	fun vec2list (KEC.VECTOR vec) = KEC.kecvector2list (vec)
	  | vec2list exp =
	    DynException.stdException ("Expected a vector but received " ^ (PrettyPrint.kecexp2nickname exp) ^ ": " ^ (pretty exp), "ModelTranslate.translate.vec2list", Logger.INTERNAL)
	    





	fun model2classname object =
	    Symbol.symbol(exp2str(method "name" object))
(*
	fun obj2param obj =
	    {name=exp2str(method "name" obj),
	     dimensions=map (Real.floor o exp2real) (vec2list (method "dimensions" obj)),
	     initialval=exp2real (getInitialValue obj),
	     properties=SymbolTable.empty}

	fun kecexp2dofexp obj =
	    if istype (obj, "ModelOperation") then
		    let
			val name = case exp2str (method "name" obj) of
				       "branch" => "IF"
				     | n => n
		    in
			DOF.OP {name=Symbol.symbol name,
				args=map kecexp2dofexp (vec2list(method "args" obj))}
		    end
	    else if istype (obj, "SimQuantity") then
		if exp2bool (send "getIsIntermediate" obj NONE) then
		    kecexp2dofexp (send "getExp" (send "getEquation" obj NONE) NONE) (*TODO: make this a read of the name with a notation that its an interm *)
		else if (exp2bool (send "getIsConstant" obj NONE))  then
		    kecexp2dofexp (getInitialValue obj)
		else
		    let
			(*TODO: fixme to be a global name *)
			val name = exp2str (method "name" obj)
		    in
			DOF.SYMBOL (DOF.QUANTITY (Symbol.symbol name), SymbolTable.empty)
		    end
	    else 
		case obj
		 of KEC.LITERAL (KEC.CONSTREAL r) => DOF.REAL r
		  | KEC.LITERAL (KEC.CONSTBOOL b) => DOF.BOOLEAN b
		  (* FIXME: Is this an acceptable way to handle undefined? *)
		  (* 		  | KEC.UNDEFINED => ExpTree.LITERAL (ExpTree.CONSTREAL 0.0) *)
		  | _ => 
		    raise TypeMismatch ("Unexpected type of expression object; received " ^ (pretty obj))

	fun obj2idquant obj =
	    {name=Symbol.symbol(exp2str(method "name" obj)), 
	     initialValue=exp2real(getInitialValue obj),
	     dimensions=map (Real.floor o exp2real) (vec2list (method "dimensions" obj)),
	     properties=SymbolTable.empty,
	     equation=
	     DOF.INTERMEDIATE (kecexp2dofexp (send "getExp" (send "getEquation" obj NONE) NONE))}
	    
	fun obj2sdquant obj =
	    let
		val eq = send "getEquation" obj NONE
	    in
		{name=Symbol.symbol(exp2str(method "name" obj)), 
		 initialValue=exp2real(getInitialValue obj),
		 dimensions=map (Real.floor o exp2real) (vec2list (method "dimensions" obj)),
		 properties=SymbolTable.empty,
		 equation=
		 if (istype (eq, "DifferentialEquation")) then
		     DOF.DIFFERENTIAL {order=Real.floor(exp2real(method "degree" eq)), 
				       exp=kecexp2dofexp (send "getExp" eq NONE)}
		 else
		     DOF.DIFFERENCE {offset=1(*TODO: fixme*), 
				     exp=kecexp2dofexp(send "getExp" eq NONE)}}
	    end

	fun addClass(object, dof) =
	    let
		val name = model2classname object
		val properties = SymbolTable.empty
		val functions = nil
		val tunables = map (obj2param) (vec2list(send "getLocalParameters" object NONE))
		val equations = map (obj2idquant) (vec2list(send "getLocalIntermediates" object NONE))
			      @ map (obj2sdquant) (vec2list(send "getLocalStates" object NONE))
		val submodels = nil
		val outputs = nil

		val class =
		    {name=SOME name,
		     properties=properties,
		     (*	     functions=functions,*)
		     (*tunables=tunables,*)
		     quants=ref equations,
		     submodels=submodels,
		     outputs=outputs,
		     instances=ref []}
	    in 
		class :: dof 
	    end
	    

	fun addInstance(object, dof) =
	    let
		val objectClassName = model2classname object
		val class = 
		    case List.find (fn(c) => case #name c of SOME n => n = objectClassName | NONE => false) dof of
			SOME c => c
		      | NONE => DynException.stdException ("Couldn't find class for " ^ (Symbol.name objectClassName), "ModelTranslate.translate.addInstance", Logger.INTERNAL)

		val instance = ref {position=PosLog.NOPOS,
				    uniqueid= 0, (*TODO: fill in *)
				    instanceName= (Symbol.symbol (exp2str(method "name" object))), 
				    inputvals=[],
				    submodelids=[],
				    dimensions = map (Real.floor o exp2real) (vec2list (method "dimensions" object))}

		val _ = #instances class := instance :: (!(#instances class))
	    in
		(dof, instance)
	    end

	fun model2dof (object, dof) =
	    let
		val objectclass = model2classname object
		val _ = print ("model2dofing " ^ (Symbol.name objectclass) ^ "\n")
		val dof = if not(List.exists (fn(class) => case (#name class) of SOME name => name  = objectclass | NONE => false) dof) then
			      addClass(object, dof)
			  else
			      dof

		val class = case List.find(fn(class) => case (#name class) of SOME name => name = objectclass | NONE => false)
					  dof of
				SOME class => class
			      | NONE => DynException.stdException ("Couldn't find class for " ^ (Symbol.name objectclass), "ModelTranslate.translate.addInstance", Logger.INTERNAL)

		val dof = foldl (fn(object, dof) => #1(model2dof (object, dof))) 
				dof 
				(vec2list(method "submodels" object)) 

		val (dof, instance) = addInstance(object, dof)
			  
	    in
		(dof, (class, instance), SymbolTable.empty, UniqueTable.empty(*FIXME*))
	    end

*)

	fun kecexp2dofexp obj =
	    if istype (obj, "ModelOperation") then
		let
		    val name = case exp2str (method "name" obj) of
				   "branch" => "IF"
				 | n => n
					
		in
		    Exp.FUN (Symbol.symbol name,
			     map kecexp2dofexp (vec2list(method "args" obj)))
		end
	    else if istype (obj, "SimQuantity") orelse istype (obj, "Input") then

(*		if exp2bool (send "getIsIntermediate" obj NONE) then
		    kecexp2dofexp (send "getExp" (send "getEquation" obj NONE) NONE) (*TODO: make this a read of the name with a notation that its an interm *)
		else 
		    if (exp2bool (send "getIsConstant" obj NONE))  then
			kecexp2dofexp (getInitialValue obj)
		    else*)
		let
		    (*TODO: fixme to be a global name *)
		    val sym = 
			if (istype (obj, "OutputBinding")) then		    
			    ExpBuild.tvar((exp2str (method "instanceName" obj)) ^ "." ^ (exp2str (method "name" obj)))
			else if (istype (obj, "Intermediate")) orelse ((istype (obj, "State")) andalso istype (method "eq" obj, "DifferentialEquation"))then
			    ExpBuild.tvar(exp2str (method "name" obj))
			else if istype (obj, "TemporalReference") then
			    ExpBuild.relvar (Symbol.symbol(exp2str(method "name" (method "internalState" obj))),
					     Symbol.symbol(exp2str(method "name" (method "iterator" obj))),
					     Real.floor(exp2real(method "step" obj)))
			else if (istype (obj, "State")) then
			    ExpBuild.var(exp2str (method "name" obj))
			else
			    ExpBuild.var(exp2str (method "name" obj))
		in
		    (*DOF.SYMBOL (DOF.QUANTITY (Symbol.symbol name), SymbolTable.empty)*)
		    sym
		end		    
	    else 
		case obj
		 of KEC.LITERAL (KEC.CONSTREAL r) => ExpBuild.real r
		  | KEC.LITERAL (KEC.CONSTBOOL b) => ExpBuild.bool b
		  (* FIXME: Is this an acceptable way to handle undefined? *)
		  (* 		  | KEC.UNDEFINED => ExpTree.LITERAL (ExpTree.CONSTREAL 0.0) *)
		  | _ => 
		    raise TypeMismatch ("Unexpected type of expression object; received " ^ (pretty obj))

	fun vecIndex (vec, index) =
	    send "at" vec (SOME [int2exp index])

	fun createClass classes object =
	    let
		val name =Symbol.symbol (exp2str (method "name" object))

		fun exp2term (Exp.TERM t) = t
		  | exp2term _ = Exp.NAN

		fun obj2output object =		    
		    (* object = [name, value] *)
		    let
			val name = (*Symbol.symbol (exp2str(vecIndex (object, 1)))*)
			    exp2term (ExpBuild.var (exp2str(vecIndex (object, 1))))
			val value = vecIndex (object, 2)
			val (contents, condition) =
			    if istype (value, "Output") then
				(case method "contents" value of
				     KEC.TUPLE args => map kecexp2dofexp args
				   | exp => [kecexp2dofexp exp],
				 kecexp2dofexp(method "condition" value))
			    else
				([kecexp2dofexp(value)],
				 Exp.TERM(Exp.BOOL true))
		    in
			{name=name,
			 contents=contents,
			 condition=condition}
		    end

		fun obj2input object =
		    {name=exp2term (ExpBuild.var (exp2str (method "name" object))),
		     default=case exp2realoption (method "default" object) of
				 SOME r => SOME (ExpBuild.real r)
			       | NONE => NONE}
(*
		    (Symbol.symbol(exp2str (method "name" object)),
		     {defaultValue= 
		      case exp2realoption (method "default" object) of
			SOME r => SOME (Exp.REAL r)
		      | NONE => NONE,
		      sourcepos=PosLog.NOPOS})
*)

		fun quantity2eq object =
		    if (istype (object, "Intermediate")) then
			[{eq_type=DOF.INTERMEDIATE_EQ,
			  sourcepos=PosLog.NOPOS,
			  lhs=exp2term (ExpBuild.var(exp2str (method "name" object))),
			  rhs=kecexp2dofexp (method "expression" (method "eq" object))}]
		    else if (istype (object, "State")) then
			((*if method "isUndefined" then
			 else*) if istype (method "eq" object, "DifferentialEquation") then
			     [{eq_type=DOF.DERIVATIVE_EQ {offset=0},
			       sourcepos=PosLog.NOPOS,
			       lhs=exp2term (ExpBuild.diff(exp2str (method "name" object))),
			       rhs=kecexp2dofexp (method "expression" (method "eq" object))},
			      {eq_type=DOF.INITIAL_VALUE {offset=0},
			       sourcepos=PosLog.NOPOS,
			       lhs=exp2term (ExpBuild.initvar(exp2str (method "name" object))),
			       rhs=kecexp2dofexp (getInitialValue object)}]
			 else
			     let 
				 val iteratorName = exp2str (method "name" (method "iterator" (method "temporalRef" (method "eq" object))))
			     in
				 [{eq_type=DOF.DIFFERENCE_EQ {offset=0},
				   sourcepos=PosLog.NOPOS,
				   lhs=exp2term (ExpBuild.relvar(Symbol.symbol(exp2str (method "name" object)),
								 Symbol.symbol(iteratorName),
								 Real.floor (exp2real (method "step" (method "temporalRef" (method "eq" object)))))),
				   rhs=kecexp2dofexp (method "expression" (method "eq" object))},
				  {eq_type=DOF.INITIAL_VALUE {offset=0},
				   sourcepos=PosLog.NOPOS,
				   lhs=exp2term (ExpBuild.initavar(exp2str (method "name" object), iteratorName)),
				   rhs=kecexp2dofexp (getInitialValue object)}]
			     end)
		    else
			DynException.stdException ("Unexpected quantity encountered", "ModelTranslate.translate.createClass.quantity2eq", Logger.INTERNAL)			
		    

		fun submodel2eq (object, (submodelclasses, eqs)) =
		    let			
			val classes = submodelclasses (* rkw - added this so that the foldl adds classes *)
			val (class, classes) = getClass (method "modeltemplate" object, classes)

			fun outbinding2name obj = 
			    (exp2str (method "instanceName" obj)) ^ "." ^ (exp2str (method "name" obj))

			val output_names = map outbinding2name
					       (vec2list (method "outputs" object))

			val input_exps = map (fn(inp) => method "inputVal" inp) 
					       (vec2list (method "inputs" object))

			val name = #name class

			val objname = Symbol.symbol (exp2str (method "name" object))

			val lhs = Exp.TUPLE (map (fn(out) => exp2term (ExpBuild.tvar out)) output_names)

			(* check for NaN on inputs *)
			val _ = app (fn(i) => case i of
				    KEC.LITERAL(KEC.CONSTREAL (r)) => if Real.isNan r then
									  (Logger.log_usererror nil (Printer.$("Value NaN detected on input in submodel " ^(Symbol.name objname)^ ".  Possibly input value was not specified."));
									   DynException.setErrored())
								      else ()
				  | _ => ()) 
				    input_exps

			val rhs = Exp.FUN (name,
					   map (fn(i) => kecexp2dofexp i) input_exps)

			val eq = {eq_type=DOF.INSTANCE {name=objname, classname=name, offset=nil},
				  sourcepos=PosLog.NOPOS,
				  lhs=lhs,
				  rhs=rhs}
				  

			val eqs = eq::eqs
		    in
			(classes, eqs)
		    end

		fun flatten x = foldr (op @) nil x

		val quant_eqs = 
		    flatten (map quantity2eq (vec2list (method "quantities" object)))
		    
		val (submodelclasses, submodel_eqs) =
		    (foldl submodel2eq (classes, nil) (vec2list (method "submodels" object)))

		val eqs = quant_eqs @ submodel_eqs

	    in
		({name=name, 
		  properties={sourcepos=PosLog.NOPOS},
		  inputs=ref (map obj2input(vec2list(method "inputs" object))),
		  outputs=ref (map obj2output(vec2list(method "contents" (method "outputs" object)))),
		  eqs=ref eqs},
		 submodelclasses)
	    end


	and getClass (object, classes) =
	    let
		val classname = Symbol.symbol(exp2str (method "name" object))
	    in
		case List.find (fn(c) => #name c = classname) classes of
		    SOME c => (c, classes)
		  | NONE => 
		    let
			val (c, classes) = createClass classes object
		    in
			(c, c :: classes)
		    end
	    end


	fun obj2modelinstance object =
	    let
		val classes = []
		val (class, classes) = getClass (method "modeltemplate" object, classes)
			     
	    in
		(classes, {name=NONE,  (*TODO: tie in*)
			   classname=(#name class)})
	    end

	fun obj2dofmodel object =
	    let
		val (classes, topinstance) = obj2modelinstance (object)
		val solverobj = method "solver" (method "modeltemplate" object)
		val solver = case exp2str(method "name" solverobj) of
				 "forwardeuler" => Solver.FORWARD_EULER {dt = exp2real(method "dt" solverobj)}
			       | "rk4" => Solver.RK4 {dt = exp2real(method "dt" solverobj)}
			      (* | "midpoint" => Solver.MIDPOINT {dt = exp2real(method "dt" solverobj)}
			       | "heun" => Solver.HEUN {dt = exp2real(method "dt" solverobj)}*)
			       | "ode23" => Solver.ODE23 {dt = exp2real(method "dt" solverobj),
							  abs_tolerance = exp2real(method "abstol" solverobj),
							  rel_tolerance = exp2real(method "reltol" solverobj)}
			       | "ode45" => Solver.ODE45 {dt = exp2real(method "dt" solverobj),
							  abs_tolerance = exp2real(method "abstol" solverobj),
							  rel_tolerance = exp2real(method "reltol" solverobj)}
			       | "cvode" => Solver.CVODE {dt = exp2real(method "dt" solverobj),
							  abs_tolerance = exp2real(method "abstol" solverobj),
							  rel_tolerance = exp2real(method "reltol" solverobj)}
			       | name => DynException.stdException ("Invalid solver encountered: " ^ name, "ModelTranslate.translate.obj2dofmodel", Logger.INTERNAL)

		fun eqHasN {eq_type=DOF.INITIAL_VALUE _, lhs, ...} =
		    (case lhs of
			 Exp.SYMBOL (_, props) => 
			 (case Property.getIterator props of
			      SOME iters =>
			     (List.exists (fn(s,p) => s = (Symbol.symbol "n")) iters)
			    | NONE => false)
		       | _ => false)
		  | eqHasN _ = false

		fun classHasN ({eqs, ...}: DOF.class) =
		    List.exists eqHasN (!eqs)

		val discrete_iterators = 
		    if List.exists classHasN classes then
			[(Symbol.symbol "n", DOF.DISCRETE)]
		    else
			[]

		val systemproperties = (*{solver=solver}*){iterators=[(Symbol.symbol "t", DOF.CONTINUOUS solver)] @ discrete_iterators,
							   time=(exp2real (method "min_t" solverobj), exp2real (method "max_t" solverobj))}
	    in
		(classes, topinstance, systemproperties)
	    end

	exception TranslationError

    in
	if (not (istype (object, "ModelInstance"))) then
	    raise TypeMismatch ("Expected a Model instance but received " ^ (pretty object))
	else
	    (SOME (obj2dofmodel object) before DynException.checkToProceed())
	    handle TranslationError => NONE
		 | e => NONE before 
			(app (fn(s) => print(s ^ "\n")) (MLton.Exn.history e);
			 DynException.checkpoint "ModelTranslate.translate" e)
    end
end
