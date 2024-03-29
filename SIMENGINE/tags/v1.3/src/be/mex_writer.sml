(*
Copyright (C) 2011 by Simatra Modeling Technologies

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*)

structure MexWriter =
struct

open Printer

val i2s = Util.i2s
val r2s = Util.r2s
val l2s = Util.l2s
val e2s = ExpPrinter.exp2str

fun outputstruct_code (class: DOF.class) =
    let
	val {outputs, ...} = class
	val output_names = map (fn{name,...}=> ClassProcess.removePrefix (CWriterUtil.exp2c_str (Exp.TERM name))) (!outputs)
    in
	[$(""),
	 $("void generate_struct(mxArray **structptr) {"),
	 SUB([$("const char *field_names[] = {" ^ (String.concatWith ", " (map (fn(out)=>"\"" ^ out ^ "\"") output_names)) ^ "};"),
	      $("double *memptr;"),
	      $("*structptr = mxCreateStructMatrix(1, 1, "^(i2s (length (!outputs)))^", field_names);")] @
	     (Util.flatmap
		  (fn({name=term, contents, ...},i)=>
		     let
			 val name = CWriterUtil.exp2c_str (Exp.TERM term)
			 val var = "outputdata_" ^ name
			 val count = length contents + 1 (* add one for time *)
			 val iter = TermProcess.symbol2temporaliterator term
		     in
			 [$("if ("^var^".length > 0) {"),
			  SUB[$("memptr = MALLOCFUN("^var^".length*"^(i2s count)^"*sizeof(double));"),
			      $("if (NULL == memptr) {"),
			      SUB[$("ERRORFUN(Simatra:outOfMemory, \"Ran out of memory allocating output buffer of %d bytes\", "^var^".length*"^(i2s count)^"*sizeof(double));"),
				  $("return;")],
			      $("}"),
			      $("else {"),
			      SUB((case iter of 
				       SOME _ => $("memcpy(memptr, "^var^".time, "^var^".length*sizeof(CDATAFORMAT));") |  
				       NONE => $("// no time included")) ::
				  (map
				      (fn(c, j)=> $("memcpy(memptr+("^(i2s (j+1))^"*"^var^".length), "^var^".vals"^(i2s j)^", "^var^".length*sizeof(CDATAFORMAT));"))
				      (Util.addCount contents))),
			      $("}"),
			      $("mwSize dims[2];"),
			      $("dims[0] = "^var^".length; dims[1] = "^(i2s count)^";"),
			      $("mxArray *"^name^"_array = mxCreateNumericArray(2, dims, mxDOUBLE_CLASS, mxREAL);"),
			      $("mxSetData("^name^"_array, memptr);"),
			      $("mxSetFieldByNumber(*structptr, 0, "^(i2s i)^", "^name^"_array);")
			     ],			  
			  $("}")]
		     end)
		  (Util.addCount (!outputs)))
	    ),	 
	 $("}")]
    end

fun stateoverride_code () =
    let
	val model as (classes, inst_class, props) = CurrentModel.getCurrentModel()
	val iterators = CurrentModel.iterators()
	val statesizes = map (fn(sym,_)=>ModelProcess.model2statesizebyiterator sym model) iterators
	val statespace = StdFun.sum statesizes
	val cumsum = foldl 
			 (fn(size,sumlist)=>if List.length sumlist = 0 then [size] else (size+Util.hd(sumlist))::sumlist)
			 []
			 statesizes
    in
	[$(""),
	 $("int parseStateInits(const mxArray *arraydata) {"),
	 SUB([$("int m_size = mxGetM(arraydata);"),
	     $("int n_size = mxGetN(arraydata);"),
	     $(""),
	     $("if (m_size != 1 || n_size != "^(i2s statespace)^") {"),
	     SUB[$("ERRORFUN(Simatra:inputTypeError, \"The input state array should have dimensions of 1x%d, not %dx%d.\", STATESPACE, m_size, n_size);"),
		 $("return 1;")],	     
	     $("}"),
	     $(""),
	     $("double *ptr = mxGetData(arraydata);"),
	     $("int i=0, j=0;")] @
	     (Util.flatmap (fn((sym,_),size,sum)=> 
			      [$("j=0;"),
			       $("for (i=i; i < "^(i2s sum)^"; i++) {"),
			       SUB[$("model_states_"^(Symbol.name sym)^"[j] = ptr[i];"),
				   $("j++;")],
			       $("}")]
			   ) 
		  (StdFun.zip3 iterators statesizes cumsum)) @
(*	     $("for (i = STATESPACE-1; i>=0; i--) {"),
	     SUB[$("model_states[i] = ptr[i];")],
	     $("}"),*)
	     [$(""),
	     $("return 0;")]),
	 $("}")]
    end

fun inputstruct_code (class: DOF.class) =
    let
	val {inputs, ...} = class
	val input_names = map (fn{name,...}=> ExpProcess.exp2str (Exp.TERM name)) (!inputs)
    in
	[$(""),
	 $("int validate_inputs(CDATAFORMAT *inputs) {"),
	 SUB(foldl 
		 (fn((name, i),progs)=> [$("if (mxIsNaN(inputs["^(i2s i)^"])) {"),
					 SUB[$("ERRORFUN(Simatra:undefinedInputError, \"The input "^name^" has not been defined or has been set to NaN\");"),
					     $("return 1;")],
					 $("} else {"),
					 SUB(progs),
					 $("}")])
		 [$("return 0;")]
		 (Util.addCount input_names)),
	 $("}"),
	 $(""),
	 $("int parseInputs(const mxArray *inpstruct, CDATAFORMAT *inputs) {"),
	 SUB[$("if (mxIsStruct(inpstruct)) {"),
	     SUB[$("int numfields = mxGetNumberOfFields(inpstruct);"),
		 $("int i;"),
		 $("const char *fieldname;"),
		 $("mxArray *field;"),
		 $("for (i=0;i<numfields;i++) {"),
		 SUB([$("fieldname = mxGetFieldNameByNumber(inpstruct, i);"),
		      $("field = mxGetFieldByNumber(inpstruct, 0, i);"),
		      $("if (1 != mxGetM(field) || 1 != mxGetN(field)) {"),
		      SUB[$("ERRORFUN(Simatra:inputTypeError, \"The value for field %s must be a scalar\", fieldname);"),
			  $("return 1;")],
		      $("}")] @
		     (foldl 
			  (fn((name, i),progs)=>[$("if (0 == strcmp(fieldname, \""^name^"\")) {"),
						 SUB[$("inputs["^(i2s i)^"] = mxGetScalar(field);"),
						     $("if (mxIsNaN(inputs["^(i2s i)^"])) {"),
						     SUB[$("ERRORFUN(Simatra:undefinedInputError, \"The input %s has not been defined or has been set to NaN\", fieldname);"),
							 $("return 1;")],
						     $("}")],
						 $("}"),
						 $("else {"),
						 SUB(progs),
						 $("}")])
			  ([$("ERRORFUN(Simatra:undefinedInputError, \"The input %s specified does not exist\", fieldname);"),
			    $("return 1;")])
			  (Util.addCount input_names))),
		 $("}")],
	     $("}"),
	     $("else {"),
	     SUB[$("ERRORFUN(Simatra:argumentError, \"The second argument must be a parameter structure\");"),
		 $("return 1;")],
	 $("}"),
	     $(""),
	     $("return 0;")],
	 $("}")]
    end


fun main_code class = 
    let
	val name = Symbol.name (#name class)
	val orig_name = Symbol.name (ClassProcess.class2orig_name class)
	val model = CurrentModel.getCurrentModel()
	val iterators = CurrentModel.iterators()
	val statesizes = map (fn(sym,_)=>ModelProcess.model2statesizebyiterator sym model) iterators
	val statespace = StdFun.sum statesizes
	val cumsum = foldl 
			 (fn(size,sumlist)=>if List.length sumlist = 0 then [size] else (size+Util.hd(sumlist))::sumlist)
			 []
			 statesizes
    in
	[$(""),
	 $("void mexFunction(int nlhs, mxArray *plhs[ ],int nrhs, const mxArray *prhs[ ]) {"),
	 SUB[$("int errno;"),
	     $("CDATAFORMAT t = 0;"),
	     $("CDATAFORMAT t1;"),
	     $("double *data;"),
	     $(""),
	     $("// Parse right-hand side arguments"),	     
	     $("if (nrhs >= 1) {"),
	     SUB[$("switch (mxGetNumberOfElements(prhs[0])) {"),
		 SUB[$("case 1:"),
		     SUB[$("t = 0;"),
			 $("t1 = mxGetScalar(prhs[0]);"),
			 $("break;")]],
		 SUB[$("case 2:"),
		     SUB[$("data = mxGetPr(prhs[0]);"),
			 $("t = data[0];"),
			 $("t1 = data[1];"),
			 $("break;")]],		     
		 SUB[$("default:"),
		     SUB[$("mexErrMsgIdAndTxt(\"Simatra:argumentError\", \"Time input must have length of 1 or 2.\");"),
			 $("return;")]],
		 $("}")],
	     $("} else {"),
	     SUB[$("ERRORFUN(Simatra:argumentError, \"At least one argument is required.  Type 'help "^name^"' for more information.\");"),
		 $("return;")],
	     $("}"),
	     $(""),
	     $("// model processing"),
	     $("output_init(); // initialize the outputs"),
	     $("outputsave_init(); // initialize temporary memory used for outputs"),
	     $("init_states(); // initialize the states"),
	     $("CDATAFORMAT inputs[INPUTSPACE];"),
	     $(""),
	     $("init_inputs(inputs);"),
	     $(""),
	     $("// Check if there is an input argument"),
	     $("if (nrhs >= 2) {"),
	     SUB[$("if (mxIsStruct(prhs[1])) {"),
		 SUB[$("if (parseInputs(prhs[1], inputs) != 0) {"),
		     SUB[$("return;")],
		     $("}")],
		 $("} else if (mxIsNumeric(prhs[1])) {"),
		 SUB[$("if (parseStateInits(prhs[1]) != 0) {"),
		     SUB[$("return;")],
		     $("}")],
		 $("} else {"),
		 SUB[$("ERRORFUN(Simatra:argumentError, \"Unknown second argument passed to function.   Type 'help "^name^"' for more information.\");"),
		     $("return;")],
		 $("}"),
		 $("if (nrhs >= 3) {"),
		 SUB[$("if (mxIsStruct(prhs[2])) {"),
		     SUB[$("if (parseInputs(prhs[2], inputs) != 0) {"),
			 SUB[$("return;")],
			 $("}")],
		     $("} else if (mxIsNumeric(prhs[2])) {"),
		     SUB[$("if (parseStateInits(prhs[2]) != 0) {"),
			 SUB[$("return;")],
			 $("}")],
		     $("} else {"),
		     SUB[$("ERRORFUN(Simatra:argumentError, \"Unknown third argument passed to function.   Type 'help "^name^"' for more information.\");"),
			 $("return;")],
		     $("}")],
		 $("}"),
		 $("if (nrhs >= 4) {"),
		 SUB[$("ERRORFUN(Simatra:argumentError, \"More than three arguments passed to function.   Type 'help "^name^"' for more information.\");"),
		     $("return;")],		 
		 $("}")],
	     $("}"),
  	     $(""),
  	     $("if (validate_inputs(inputs) != 0) {;"),
	     SUB[$("return;")],
	     $("}"),
  	     $(""),
	     $("exec_loop(&t, t1, inputs);"),
	     $(""),
	     $("generate_struct(&plhs[0]);"),
	     $("if (nlhs > 1) {"),
	     SUB([$("mwSize dims[2];"),
		  $("dims[0] = 1; dims[1] = STATESPACE;"),
		  $("plhs[1] = mxCreateNumericArray(2, dims, mxDOUBLE_CLASS, mxREAL);"),
		  $("double *state_ptr = MALLOCFUN(STATESPACE*sizeof(double));"),
		  $("int i=0, j=0;")] @
		 (Util.flatmap (fn((sym,_),size,sum)=> 
				  [$("j=0;"),
				   $("for (i=i; i < "^(i2s sum)^"; i++) {"),
				   SUB[$("state_ptr[i] = model_states_"^(Symbol.name sym)^"[j];"),
				       $("j++;")],
				   $("}")]
			       ) 
			       (StdFun.zip3 iterators statesizes cumsum)) @		 
		 (*$("for (i=STATESPACE-1;i>=0;i--) {"),
		 SUB[$("state_ptr[i] = model_states[i];")],
		 $("}"),*)
		 [$("mxSetData(plhs[1], state_ptr);"),
		  $("if (nlhs > 2) {"),
		  SUB[$("dims[0] = 1; dims[1] = 1;"),
		      $("plhs[2] = mxCreateNumericArray(2, dims, mxDOUBLE_CLASS, mxREAL);"),
		      $("double *t_ptr = MALLOCFUN(sizeof(double)); // add more iterators as needed here"),
		      $("*t_ptr = t;"),
		      $("mxSetData(plhs[2], t_ptr);")],
		  $("}")]),
	     $("}"),
	     $("")],
	 $("}")]
    end

fun createExternalStructure props (class: DOF.class) = 
    let

	val {inputs,outputs,...} = class

	val time = Symbol.symbol "t"

	val {precision,...} = props

	fun findStatesInitValues basestr (iter as (itersym, itertype)) (class:DOF.class) = 
	    let
		val classname = ClassProcess.class2orig_name class
		val exps = #exps class
		val state_eqs_symbols = map ExpProcess.lhs (List.filter (ExpProcess.isStateEqOfIter iter) (!exps))
		(*val _ = Util.log ("in findStatesInitValues: " ^ (l2s (map e2s state_eqs_symbols)))*)
		val init_conditions = List.filter ExpProcess.isInitialConditionEq (!exps)
		fun exp2name exp = 
		    Term.sym2curname (ExpProcess.exp2term exp)
		    handle e => DynException.checkpoint ("MexWriter.createExternalStructure.findStatesInitValues.exp2name ["^(ExpProcess.exp2str exp)^"]") e
				      
		val sorted_init_conditions = 
		    map 
			(fn(exp)=>
			   let
			       val name = exp2name exp
			   in
			       case List.find (fn(exp')=> 
						 name = exp2name (ExpProcess.lhs exp')) init_conditions of
				   SOME v => v
				 | NONE => DynException.stdException(("No initial condition found for differential equation: " ^ (ExpProcess.exp2str exp)), "MexWriter.createExternalStructure.findStatesInitValues", Logger.INTERNAL)
			   end)
			state_eqs_symbols
			
		(*val _ = Util.log("Sorted initial conditions: " ^ (l2s (map e2s sorted_init_conditions)))*)
		val instances = List.filter ExpProcess.isInstanceEq (!exps)
		val class_inst_pairs = ClassProcess.class2instnames class
	    in
		(StdFun.flatmap (fn(exp)=>
				   let
				       val term = ExpProcess.exp2term (ExpProcess.lhs exp)
				       val rhs = ExpProcess.rhs exp
				   in
				       if Term.isInitialValue term itersym then
					   [((if basestr = "" then "" else basestr ^ "." ) ^ (Term.sym2name term), CWriterUtil.exp2c_str rhs)]
				       else 
					   []
				   end) sorted_init_conditions)
		@ (StdFun.flatmap
		       (fn(classname, instname)=>
			  let
			      val basestr' = Symbol.name instname
			  in
			      findStatesInitValues basestr' iter (CurrentModel.classname2class classname)
			  end)
		       class_inst_pairs)
	    end
	    handle e => DynException.checkpoint "MexWriter.createExternalStructure.findStatesInitValues" e
	val states = List.concat (map (fn(iter)=> findStatesInitValues "" iter class) (CurrentModel.iterators()))
		     
    in
	[$("% Generated output data structure for Matlab"),
	 $("% " ^ Globals.copyright),
	 $(""),
	 $("dif = struct();"),
	 $("dif.precision = "^(case precision of DOF.SINGLE => "'float'" | DOF.DOUBLE => "'double'")^";"),
	 $("dif.inputs = struct();")] @
	(map
	     (fn{name,default}=> 
		$("dif.inputs." ^ (Term.sym2name name) ^ 
		  " = "^(case default of SOME v => CWriterUtil.exp2c_str v | NONE => "nan")^";")
		(*$("dif.inputs." ^ (CWriterUtil.exp2c_str (Exp.TERM name)) ^ 
		  " = struct('name', '"^(ExpProcess.exp2str (Exp.TERM name))^
		  "', 'value', "^(case default of SOME v => CWriterUtil.exp2c_str v | NONE => "nan")^");")*))
	     (!inputs)) @
	($("dif.states = [];")::
	 (map 
	     (fn((name, init), i)=> $((if i = 0 then "dif.states" else ("dif.states("^(i2s (i+1))^")"))
				      ^" = struct('name', '"^name^"', 'init', "^init^");"))
	     (Util.addCount states)))
	 
    end
    handle e => DynException.checkpoint "MexWriter.createExternalStructure" e

fun buildMexHelp name = 
    let
	fun write_help (filename, block) =
	    let
		val _ = Logger.log_notice ($("Generating Matlab MEX help file '"^ filename ^"'"))
		val file = TextIO.openOut (filename)
	    in
		Printer.printtexts (file, block, 0)
		before TextIO.closeOut file
	    end

	val upper = StdFun.toUpper name

	val progs = 
	    [$("%"^upper^" Executes a high-performance simulation engine"),
	     $("%producing a simulation data structure of outputs."),
	     $("% "),
	     $("% OUT = "^upper^"(STOPTIME) executes the simulation from time=0"),
	     $("% to time=STOPTIME.  The output structure OUT includes each output"),
	     $("% organized in the output groups specified in the DSL model. Each"),
	     $("% output group is a matrix where the first column is a time vector."),
	     $("% "),
	     $("% OUT = "^upper^"([STARTTIME STOPTIME]) executes the simulation from"),
	     $("% time=STARTTIME to time=STOPTIME."),
	     $("% "),
	     $("% OUT = "^upper^"([STARTTIME STOPTIME], INPUTS) sets all scalar inputs"),
	     $("% to the values specified in the INPUTS structure.  The default input"),
	     $("% can be found in the inputs field of the data structure returned by"),
	     $("% buildEngine."),
	     $("% "),
	     $("% OUT = "^upper^"([STARTTIME STOPTIME], STATE_INITS) sets all state values"),
	     $("% to the values specified in the STATE_INITS array.  The default state init"),
	     $("% can be found in the state_init field of the data structure returned by"),
	     $("% buildEngine."),	  
	     $("% "),
	     $("% OUT = "^upper^"([STARTTIME STOPTIME], INPUTS, STATE_INITS) sets both the"),
	     $("% inputs and the state initial values."),
	     $("% "),
	     $("% [OUT FINAL_STATE] = "^upper^"([STARTTIME STOPTIME], INPUTS, STATE_INITS) returns"),
	     $("% the final state vector as the second return argument.  That vector can be passed in"),
	     $("% as an initial state vector on a subsequent execution of the simulation engine."),
	     $("% "),
	     $("% [OUT FINAL_STATE FINAL_TIME] = "^upper^"([STARTTIME STOPTIME], INPUTS, STATE_INITS) returns"),
	     $("% the final simulation time as an optional third return argument."),
	     $("% "),
	     $("%   m = buildEngine('myModel.dsl');"),
	     $("%   [out final_state tf] = myModel(100, m.inputs, m.state_inits);"),
	     $("% ")
	    ]
    in
	write_help(name ^ ".m", progs)
    end


fun buildMex (model: DOF.model as (classes, inst, props)) =
    let
	val {name=inst_name, classname=class_name} = inst
	val inst_class = CurrentModel.classname2class class_name
	val class_name = Symbol.name (#name inst_class)

	val statespace = ClassProcess.class2statesize inst_class

	val {iterators,precision,...} = props
	val iter_solver_list = CWriter.props2solvers props

	val c_data_format = case precision 
			     of DOF.SINGLE => "float" 
			      | DOF.DOUBLE => "double"

	val header_progs = CWriter.header (model, 
					   ["<mex.h>"],
					   ("ITERSPACE", i2s (length iterators))::			   
					   ("STATESPACE", i2s statespace)::
					   ("CDATAFORMAT", c_data_format)::
					   ("INPUTSPACE", i2s (length (!(#inputs inst_class))))::nil @
					   (map (fn(sym, solver)=>("INTEGRATION_METHOD_"^(Symbol.name sym)^"(m)", (Solver.solver2name solver) ^ "_ ## m")) iter_solver_list) @
					   ("START_SIZE", "1000")::
					   ("MAX_ALLOC_SIZE", "65536000")::
					   ("MALLOCFUN", "mxMalloc")::
					   ("REALLOCFUN", "mxRealloc")::
					   ("PRINTFUN", "//")::
					   ("FPRINTFUN", "fprintf")::
					   (*("ERRORFUN(id,txt)", "(mexErrMsgIdAndText(#id, txt))")*)
					   ("ERRORFUN(ID, MESSAGE, ...)", "(mexErrMsgIdAndTxt(#ID, MESSAGE, ## __VA_ARGS__))")::
					   nil,
					   iterators)

(*
#define ERRORFUN(ID, MESSAGE, ARGS...) (fprintf(stderr, "Error (%s): " message "\n", #ID, ARGS...))
#define ERRORFUN(ID, MESSAGE, ARGS...) (mexErrMsgIdAndText(#ID, MESSAGE, ARGS...))
*)

	val input_progs = CWriter.input_code inst_class
	val outputdatastruct_progs = CWriter.outputdatastruct_code inst_class
	val outputstatestruct_progs = CWriter.outputstatestruct_code iterators classes
	val outputinit_progs = CWriter.outputinit_code inst_class
	val init_progs = CWriter.init_code (classes, inst_class, iterators)
	val flow_progs = CWriter.flow_code model
	val exec_progs = CWriter.exec_code (inst_class, props, statespace)
	val outputstruct_progs = outputstruct_code inst_class
	val inputstruct_progs = inputstruct_code inst_class
	val statestruct_progs = stateoverride_code()
	val main_progs = main_code inst_class
	val logoutput_progs = CWriter.logoutput_code inst_class

	(* write the code *)
	val _ = CWriter.output_code(class_name ^ "_mex", ".", (header_progs @ 
							       outputdatastruct_progs @ 
							       outputstatestruct_progs @
							       outputinit_progs @ 
							       input_progs @ 
							       init_progs @ 
							       flow_progs @ 
							       logoutput_progs @
							       exec_progs @
							       statestruct_progs @
							       outputstruct_progs @
							       inputstruct_progs @
							       main_progs))

	val externalstruct_progs = createExternalStructure props inst_class

	fun write_struct (filename, block) =
	    let
		val _ = Logger.log_notice ($("Generating Matlab structure file '"^ filename ^"'"))
		val file = TextIO.openOut (filename)
	    in
		Printer.printtexts (file, block, 0)
		before TextIO.closeOut file
	    end

	val _ = write_struct(class_name ^ "_struct.m", externalstruct_progs)

	val _ = buildMexHelp class_name
		
    in
	System.SUCCESS
    end
    handle e => DynException.checkpoint "MexWriter.buildMex" e


end
