signature COST=
sig

    (* Compute the costs based on the op props in fun_properties.sml *)
    val exp2cost : Exp.exp -> int
    val class2cost : DOF.class -> int
    val model2cost : DOF.model -> int
    val model2uniquecost : DOF.model -> int

end
structure Cost : COST =
struct

fun exp2generalcost deep exp =
    let 
	val exp2cost = exp2generalcost deep
	val class2cost = class2generalcost deep
    in
	case exp of
	    Exp.TERM t => 0
	  | Exp.FUN (Fun.BUILTIN f, args) => #expcost (FunProps.op2props f) +
					     Util.sum (map exp2cost args)
	  | Exp.FUN (Fun.INST {classname, instname, props}, args) => 
	    let
		val args_size = Util.sum (map exp2cost args)
		val c = CurrentModel.classname2class classname
		val inst_size = class2cost c
	    in
		args_size + inst_size
	    end
	  | Exp.META (Exp.SEQUENCE s) => Util.sum (map exp2cost s)
	  | Exp.META _ => 0
	  | Exp.CONTAINER c => Util.sum (map exp2cost (Container.containerToElements c))
    end
    
and class2generalcost deep (c:DOF.class) = 
    let
	val exp2cost = exp2generalcost deep
	val inputs = !(#inputs c)
	val exps = !(#exps c)
	val outputs = !(#outputs c)
    in
	Util.sum ((map exp2cost (List.mapPartial #default inputs)) @
		  (map exp2cost (map #condition outputs @ (Util.flatmap #contents outputs))) @
		  (map exp2cost exps))
    end

and model2generalcost deep ((classes,{name,classname},_):DOF.model) =
    if deep then
	case List.find (fn{name,...}=>name=classname) classes of
	    SOME c => class2generalcost deep c
	  | NONE => 0
    else
	Util.sum (map (class2generalcost deep) classes)

val exp2cost = exp2generalcost true
val class2cost = class2generalcost true
val model2cost = model2generalcost true

val model2uniquecost = model2generalcost false

end
