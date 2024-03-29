structure CompilerLib =
struct

val TypeMismatch = DynException.TypeMismatch
and IncorrectNumberOfArguments = DynException.IncorrectNumberOfArguments

exception Aborted

fun std_compile exec args =
    (case args of
	 [object] => 
	 (let
	      val _ = if DynException.isErrored() then
			  raise Aborted
		      else
			  ()

	      val forest = case ModelTranslate.translate(exec, object) of
				       SOME f => f
				     | NONE => raise Aborted
						  

	      val (classes, _, _) = forest

	      val _ = DOFPrinter.printModel forest   

	      val _ = CurrentModel.setCurrentModel forest

	      val () = 
		  let val model = CurrentModel.getCurrentModel ()
		      val filename = "dof.json"
		      fun output outstream = mlJS.output (outstream, ModelProcess.to_json model)
		  in 
		      Printer.withOpenOut filename output
		  end

		      
	      val _ = if DynamoOptions.isFlagSet "optimize" then
			  (Util.log ("Optimizing model ...");
			   ModelProcess.optimizeModel (CurrentModel.getCurrentModel()))
		      else
			  ()

	      val _ = Util.log("Normalizing model ...")
	      val _ = ModelProcess.normalizeModel (CurrentModel.getCurrentModel())

	      val _ = Util.log("Normalizing parallel model ...")
	      val _ = ModelProcess.normalizeParallelModel (CurrentModel.getCurrentModel())

(*	      val _ = Util.log("Ready to build the following DOF ...")*)
	      val _ = Util.log("Ready to build ...")
(*	      val _ = DOFPrinter.printModel (CurrentModel.getCurrentModel())*)

	      val () = 
		  let val model = CurrentModel.getCurrentModel ()
		      val filename = "dof-final.json"
		      fun output outstream = mlJS.output (outstream, ModelProcess.to_json model)
		  in 
		      Printer.withOpenOut filename output
		  end



	      val () 
		= let val model = CurrentModel.getCurrentModel ()
		      val system = ModelProcess.createIteratorForkedModels model

		      fun sysmod_to_json {top_class, iter, model} =
			  let val (iter_name, iter_typ) = iter
			  in mlJS.js_object [("top_class", mlJS.js_string (Symbol.name top_class)),
					     ("iterator", mlJS.js_string (Symbol.name iter_name)),
					     ("model", ModelProcess.to_json model)]
			  end

		      fun writeJSON outstream =
			  mlJS.output (outstream, mlJS.js_array (map sysmod_to_json system))
		      fun writeC outstream =
			  (TextIO.output (outstream, "// NEW C WRITER\n// ===\n");
			   CWriter.withTextIOStream outstream (fn pps => CWriter.Emit.modelEmit pps model);
			   TextIO.output (outstream, "\n// --- NEW C WRITER\n"));
		  in
		      Printer.withOpenOut "dof-system.json" writeJSON
		      before Printer.withOpenOut "new-c-writer.c" writeC
		  end
		  
	      val code = CParallelWriter.buildC (CurrentModel.getCurrentModel())
(*	      val code = CWriter.buildC(CurrentModel.getCurrentModel())*)


	      val _ = DynException.checkToProceed()
	  in 
	      case code of
		  CParallelWriter.SUCCESS => KEC.LITERAL(KEC.CONSTSTR "\nCompilation Finished Successfully\n")
		| CParallelWriter.FAILURE f => KEC.LITERAL(KEC.CONSTSTR ("\nFailure: " ^ f ^ "\n"))
	  end 
	  handle Aborted => KEC.LITERAL(KEC.CONSTSTR ("\nFailure: Compilation stopped due to errors\n"))
	       | TooManyErrors => KEC.LITERAL(KEC.CONSTSTR ("\nFailure: Compilation stopped due to too many errors\n")))
       | _ => raise IncorrectNumberOfArguments {expected=1, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_compile" e

fun std_transExp exec args =
    (case args of
	 [object] => valOf(ModelTranslate.reverseExp (exec, valOf (ModelTranslate.translateExp(exec, object))))

       | _ => raise IncorrectNumberOfArguments {expected=1, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_transExp" e

fun std_applyRewriteExp exec args =
    (case args of
	 [rewrite, exp] => valOf(ModelTranslate.reverseExp (exec, Match.applyRewriteExp (valOf (ModelTranslate.rule2rewriterule (exec, rewrite)))
											(valOf (ModelTranslate.translateExp(exec, exp)))))

       | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_applyRewriteExp" e

fun std_applyRewritesExp exec args =
    (case args of
	 [rewrite, exp] => valOf(ModelTranslate.reverseExp (exec, Match.applyRewritesExp (valOf (ModelTranslate.rules2rewriterules (exec, rewrite)))
											 (valOf (ModelTranslate.translateExp(exec, exp)))))

       | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_applyRewritesExp" e

fun std_repeatApplyRewriteExp exec args =
    (case args of
	 [rewrite, exp] => valOf(ModelTranslate.reverseExp (exec, Match.repeatApplyRewriteExp (valOf (ModelTranslate.rule2rewriterule (exec, rewrite)))
											(valOf (ModelTranslate.translateExp(exec, exp)))))

       | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_repeatApplyRewriteExp" e

fun std_repeatApplyRewritesExp exec args =
    (case args of
	 [rewrite, exp] => valOf(ModelTranslate.reverseExp (exec, Match.repeatApplyRewritesExp (valOf (ModelTranslate.rules2rewriterules (exec, rewrite)))
											 (valOf (ModelTranslate.translateExp(exec, exp)))))

       | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_repeatApplyRewritesExp" e

fun std_exp2str exec args =
    let
	val _ = print ("in exp2str\n")
    in
    (case args of
	 [object] => KEC.LITERAL(KEC.CONSTSTR (ExpPrinter.exp2str (valOf (ModelTranslate.translateExp(exec, object)))))

       | _ => raise IncorrectNumberOfArguments {expected=1, actual=(length args)})
    handle e => DynException.checkpoint "CompilerLib.std_exp2str" e 
    end
    before print ("out of exp2str\n")
    

val library = [{name="compile", operation=std_compile},
	       {name="transexp", operation=std_transExp},
	       {name="exp2str", operation=std_exp2str},
	       {name="applyRewriteExp", operation=std_applyRewriteExp},
	       {name="applyRewritesExp", operation=std_applyRewritesExp},
	       {name="repeatApplyRewriteExp", operation=std_repeatApplyRewriteExp},
	       {name="repeatApplyRewritesExp", operation=std_repeatApplyRewritesExp}]

end
