structure ModelProcess : sig

    (* Primary functions to execute optimizations and commands across all classes within a model *)

    (* optimizeModel: algebraic and performance optimizations all occur in this function.  All transformations
      performed here should be independent of back-end.  If the data structure is to be saved prior to writing 
      a particular back-end, the data structure returned from optimizeModel would be a good one to save.  *)
    val optimizeModel : DOF.model -> unit

    (* normalizeModel and normalizeParallelModel: a normalization step for writing into a C back-end.  This 
      function performs transformations that are used solely for fitting within a back-end.  This
      can include renaming symbols to fit within compiler rules or adding code generation flags. *)
    val normalizeModel : DOF.model -> unit
    val normalizeParallelModel : DOF.model -> unit

    (* model2statesizebyiterator: Computes the total state space of the model on a per iterator basis *)
    val model2statesize : DOF.model -> int
    val model2statesizebyiterator : DOF.systemiterator -> DOF.model -> int

    (* createIteratorForkedModels: Creates a structure list of models that are unique by iterator *)
    val createIteratorForkedModels : DOF.model -> {top_class: Symbol.symbol,
						   iter: DOF.systemiterator,
						   model: DOF.model} list

    val duplicateModel : DOF.model -> (Symbol.symbol -> Symbol.symbol) -> DOF.model
    val pruneModel : (DOF.systemiterator option) -> DOF.model -> unit
	
    (* Iterator related functions - these all grab the iterators from CurrentModel *)
    val returnIndependentIterators : unit -> DOF.systemiterator list
    val returnDependentIterators : unit -> DOF.systemiterator list
    val hasUpdateIterator : Symbol.symbol -> bool
    val hasPostProcessIterator : Symbol.symbol -> bool

end = struct


fun isDependentIterator (_, DOF.CONTINUOUS _) = false
  | isDependentIterator (_, DOF.DISCRETE _) = false
  | isDependentIterator _ = true


fun returnIndependentIterators () =
    List.filter (not o isDependentIterator) (CurrentModel.iterators ())

fun returnDependentIterators () =
    List.filter isDependentIterator (CurrentModel.iterators ())

fun hasUpdateIterator iter_sym =
    let
	val iterators = CurrentModel.iterators()
    in
	List.exists (fn(_,iter_type)=>case iter_type of
					  DOF.UPDATE v => v=iter_sym
					| _ => false) iterators
    end
    
fun hasPostProcessIterator iter_sym =
    let
	val iterators = CurrentModel.iterators()
    in
	List.exists (fn(_,iter_type)=>case iter_type of
					  DOF.POSTPROCESS v => v=iter_sym
					| _ => false) iterators
    end
    

fun pruneModel iter_sym_opt model = 
    let
	val prevModel = CurrentModel.getCurrentModel()
	val _ = CurrentModel.setCurrentModel(model)
	val (classes, top_inst, props) = model
	val () = app (ClassProcess.pruneClass iter_sym_opt) classes
    in
	(CurrentModel.setCurrentModel(prevModel))
    end

fun duplicateClasses classes namechangefun = 
    let
	(* create name mapping *)
	val orig_names = map ClassProcess.class2orig_name classes
	val name_mapping = map (fn({name,...},orig_name)=> (name, namechangefun name, orig_name, namechangefun orig_name)) (ListPair.zip(classes, orig_names))

	(* duplicate the classes *)
	val new_classes = 
	    map (fn((c as {name,...},(_,new_name,_,new_orig_name)))=> 
		   let
		       val c' = ClassProcess.duplicateClass c new_name
		       val c'' = ClassProcess.updateRealClassName c' new_orig_name
		   in
		       c''
		   end) (ListPair.zip (classes, name_mapping))

	(* update all the references in instances - this is O(n^2) - check for performance issues... *)
	val _ = app
		    (fn(name, new_name, orig_name, new_orig_name)=> app (fn(c as {name=name',...}) => ClassProcess.renameInsts ((name, new_name),(orig_name,new_orig_name)) c) new_classes)
		    name_mapping
    in
	new_classes
    end

fun duplicateModel model namechangefun = 
    let
	val (classes, top_inst as {name, classname}, props) = model
	val classes' = duplicateClasses classes namechangefun
	val classname' = namechangefun classname
	val top_inst' =  {name=name, classname=classname'}
    in
	(classes', top_inst', props)
    end
	

(* TODO: this should really be called at the end right before code gen so we don't create too many classes.  I still need to add the pruning step... *)

(* duplicate all classes by iterator and then remove the original classes *)
fun duplicateByIterator (model:DOF.model as (orig_classes, top_inst, props)) =
    let
	val iterators = CurrentModel.iterators()

	val new_classes_by_iterator = 
	    Util.flatmap
		(fn(iter_sym, _)=> duplicateClasses orig_classes (fn(name)=> Symbol.symbol ((Symbol.name name) ^ "_" ^ (Symbol.name iter_sym))))
		iterators
    in
	(new_classes_by_iterator, top_inst, props)
    end

fun model2statesize (model:DOF.model) =
    let
	val (_, {name,classname}, _) = model
    in
	ClassProcess.class2statesize (CurrentModel.classname2class classname)
    end

fun model2statesizebyiterator (iter:DOF.systemiterator) (model:DOF.model) =
    let
	val (_, {name,classname}, _) = model
    in
	ClassProcess.class2statesizebyiterator iter (CurrentModel.classname2class classname)
    end

fun pruneIterators (model:DOF.model as (classes, top_inst, properties)) =
    let
	val {iterators, precision, target, num_models, debug, profile} = properties
	val iterators' = List.filter 
			     (fn(iter) => 
				     model2statesizebyiterator iter model > 0) iterators
	val properties' = {iterators=iterators',
			   precision=precision,
			   target=target,
			   num_models=num_models,
			   debug=debug,
			   profile=profile}
	val model' = (classes, top_inst, properties')
    in
	CurrentModel.setCurrentModel(model')
    end
			
fun optimizeModel (model:DOF.model) =
    let
	val _ = DynException.checkToProceed()
	val (classes, _, _) = model

	val _ = map ClassProcess.optimizeClass classes

	val _ = DynException.checkToProceed()
    in
	()
    end

fun normalizeModel (model:DOF.model) =
    let
	val _ = DynException.checkToProceed()

	val (classes, _, _) = model
	(* TODO, write the checks of the model IR as they are needed *)

	(* assign correct scopes for each symbol *)
	val _ = Util.log ("Creating event iterators ...")
	val () = app ClassProcess.createEventIterators (CurrentModel.classes())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
	val _ = DynException.checkToProceed()

	(* add intermediates for update equations if required - they are reading and writing to the same vector so we have to make sure that ordering doesn't matter. *)
	val _ = Util.log ("Adding update intermediates ...")
	val () = app ClassProcess.addUpdateIntermediates (CurrentModel.classes())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
	val _ = DynException.checkToProceed()

	val _ = Util.log ("Assigning correct scope ...")
	val () = app ClassProcess.assignCorrectScope (CurrentModel.classes())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
	val _ = DynException.checkToProceed()

(*	val _ = Util.log ("Propagating temporal iterators ...")
	val () = app ClassProcess.propagatetemporalIterators (CurrentModel.classes())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
*)
	val _ = Util.log ("Propagating spatial iterators ...")
	val () = app ClassProcess.propagateSpatialIterators (CurrentModel.classes())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
	val _ = DynException.checkToProceed()

	val _ = Util.log ("Pruning excess iterators ...")
	val () = pruneIterators (CurrentModel.getCurrentModel())
	val () = DOFPrinter.printModel (CurrentModel.getCurrentModel())
	val _ = DynException.checkToProceed()

	(* generate all offsets for instances *)
	(*val () = app ClassProcess.generateOffsets classes*)

(*
	(* reorder all the statements *)
	val () = app 
		     (fn(class)=> 
			let
			    val eqs' = EqUtil.order_eqs (!(#eqs class))
			in
			    (#eqs class) := eqs'
			end) 
		     classes
	*)
	val _ = Util.log ("Ordering model ...")
	val _ = Ordering.orderModel(CurrentModel.getCurrentModel())

	val _ = DynException.checkToProceed()

	(* remap all names into names that can be written into a back-end *)
	val _ = Util.log ("Fixing symbol names ...")
	val () = (app ClassProcess.fixSymbolNames (CurrentModel.classes()))

	val _ = DynException.checkToProceed()
    in
	() (* all changes are in the model, we don't have to return this model *)
    end
    handle e => DynException.checkpoint "ModelProcess.normalizeModel" e

fun forkModelByIterator model (iter as (iter_sym,_)) = 
    let
	fun namechangefun iter_sym = (fn(name)=> Symbol.symbol ((Symbol.name name) ^ "_" ^ (Symbol.name iter_sym)))
	val model' as (classes',_,_) = duplicateModel model (namechangefun iter_sym)
	val _ = pruneModel (SOME iter) model'
	val _ = map (ClassProcess.updateForkedClassScope iter) classes'
    in
	model'
    end

fun createIteratorForkedModels model =
    let
	val iterators = CurrentModel.iterators()
	fun forkedModel (iter as (iter_sym,_)) = 
	    let 
		val model' as (_, {name,classname},_) = forkModelByIterator model iter
	    in
		{top_class=classname,
		 iter=iter,
		 model=model'}
	    end
    in
	map forkedModel iterators
    end

fun normalizeParallelModel (model:DOF.model) =
    let
	val _ = DynException.checkToProceed()

	val (classes, _, _) = model
	(* TODO, write the checks of the model IR as they are needed *)

	(* generate all offsets for instances *)
	(*val () = app ClassProcess.generateOffsets classes*)

(*
	(* reorder all the statements *)
	val () = app 
		     (fn(class)=> 
			let
			    val eqs' = EqUtil.order_eqs (!(#eqs class))
			in
			    (#eqs class) := eqs'
			end) 
		     classes
	*)
(*	val _ = Ordering.orderModel(model)*)

	val _ = DynException.checkToProceed()

	(* remap all names into names that can be written into a back-end *)
	(*val () = app ClassProcess.fixSymbolNames (CurrentModel.classes())*)
	(* must be put into a different normalizeModel function *)

	val _ = Util.log ("Adding EP index to class ...")
	val () = app (ClassProcess.addEPIndexToClass false) (CurrentModel.classes())
	val top_class = CurrentModel.classname2class (#classname (CurrentModel.top_inst()))
	val () = ClassProcess.addEPIndexToClass true top_class

	(*val () = app ClassProcess.fixStateSymbolNames (CurrentModel.classes())*)

	(* Just some debug code ...*)
	val forkedModels = createIteratorForkedModels model
	val prevModel = CurrentModel.getCurrentModel()
	val _ = app
		    (fn{top_class,iter=(iter_sym,_),model=model'}=>		       
		       (CurrentModel.setCurrentModel(model');
			Util.log("\n==================   Iterator '"^(Symbol.name iter_sym)^"' =====================");
			DOFPrinter.printModel model'))
		    forkedModels
	val _ = CurrentModel.setCurrentModel(prevModel)

	val _ = DynException.checkToProceed()
    in
	()
    end
    handle e => DynException.checkpoint "ModelProcess.normalizeParallelModel" e



end
