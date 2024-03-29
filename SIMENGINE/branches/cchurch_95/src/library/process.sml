structure ProcessLib =
struct

val TypeMismatch = DynException.TypeMismatch
and ValueError = DynException.ValueError
and IncorrectNumberOfArguments = DynException.IncorrectNumberOfArguments

structure Proc = MLton.Process
local open Proc
in
structure Param = Param
structure Child = Child
end

fun error msg =
    Logger.log_usererror [PosLog.NOPOS] (Printer.$ msg)


fun std_popen exec args =
    case args of
	[a as KEC.LITERAL (KEC.CONSTSTR str), b as KEC.VECTOR vec] => 
	let
	     fun kecstr2str (KEC.LITERAL(KEC.CONSTSTR s)) = s
	       | kecstr2str exp = 
		 PrettyPrint.kecexp2prettystr exec exp

	     val args = map kecstr2str (KEC.kecvector2list vec)

	     val file = 
		 case FilePath.find str (!Globals.path)
		  of SOME f => f
		   | NONE => raise ValueError ("Cannot find executable " ^ str)

	     val proc = 
		 Proc.create {args = args,
			      env = SOME (Posix.ProcEnv.environ()),
			      path = file,
			      stderr = Param.pipe,
			      stdin = Param.pipe,
			      stdout = Param.pipe}
		 handle e => raise ValueError ("Error opening process "^str)
	 in
	     KEC.PROCESS (proc, file, args)
	 end
		
      | [a, b] =>
	raise TypeMismatch ("expected a string and a list of strings, but received " ^ (PrettyPrint.kecexp2nickname a) ^ " and " ^ (PrettyPrint.kecexp2nickname b))
      | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)}

fun std_preadline exec args =
    case args of
	[KEC.PROCESS (p, _, _)] =>
	(case TextIO.inputLine (Child.textIn (Proc.getStdout p)) of
	    NONE => KEC.UNIT
	  | SOME s => KEC.LITERAL(KEC.CONSTSTR s))
      | [a] => 
	raise TypeMismatch ("expected a process, but received " ^ (PrettyPrint.kecexp2nickname a))
      | _ => raise IncorrectNumberOfArguments {expected=1, actual=(length args)}

fun std_pwrite exec args =
    case args of
	[KEC.PROCESS (p, _, _), KEC.LITERAL(KEC.CONSTSTR s)] =>
	(TextIO.output (Child.textOut(Proc.getStdin p), s);
	 KEC.UNIT)
      | [a, b] => 
	raise TypeMismatch ("expected a process and string, but received " ^ (PrettyPrint.kecexp2nickname a) ^ " and " ^ (PrettyPrint.kecexp2nickname b))
      | _ => raise IncorrectNumberOfArguments {expected=2, actual=(length args)}

(* See http://mlton.org/pipermail/mlton-user/2009-April/001521.html
 * for an explanation of the return status of MLton.Process.reap. *)
fun std_preap exec args =
    case args of
	[KEC.PROCESS (p, _, _)] =>
	(Proc.reap p;
	 KEC.UNIT)
      | [a] => 
	raise TypeMismatch ("expected a process, but received " ^ (PrettyPrint.kecexp2nickname a))
      | _ => raise IncorrectNumberOfArguments {expected=1, actual=(length args)}


val library = [{name="popen", operation=std_popen},
	       {name="preadline", operation=std_preadline},
	       {name="pwrite", operation=std_pwrite},
	       {name="preap", operation=std_preap}]

end
