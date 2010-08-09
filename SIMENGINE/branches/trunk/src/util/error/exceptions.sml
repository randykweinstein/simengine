(* Dynamo Exceptions library
 * 
 *   This module provides support for standardized exception raising, handling, and logging.
 *   See the wiki for more information.
 *)

structure DynException =
struct

exception InternalError of {message: string,
			    severity: Logger.message_type,
			    characterization: Logger.characterization,
			    location: string}
exception TooManyErrors

(* Raised when an error occurs within an action and the repl should restart. *)
exception RestartRepl

(* Raised when an error occurs with the settings structure. *)
exception SettingsError

(* Raised when there is an internal failure *)
exception InternalFailure

(* Raised when an operation or function is applied to an object of an inappropriate type.
   The associated string is a message giving details about the type mismatch. *)
exception TypeMismatch of string

(* Raised when an operation or function is applied to an object of the correct type but an inappropriate value.
   The associated string is a message giving details about the value mismatch. *)
exception ValueError of string

(* Raised when an operation or function is applied to too many or too few arguments.
   The associated record comprises the expected number of arguments and 
   the actual number of received arguments. *)
exception IncorrectNumberOfArguments of {expected: int, actual: int}

(* Raised when an unknown identifier is encountered.
   The associated string is the symbolic name. *)
exception NameError of string

(* Raised when an identifier conflicts with a previously-bound name.
 * The associated string is the symbolic name. *)
exception NameConflictError of string

(* Raised when import cannot find a file.
   The associated string is the file name.
   The associated list of strings contains the search paths. *)
exception ImportError of string * string list

(* Raised when an error is unknown at this time *)
exception UnknownError of string * exn

(* Exceptions for Current Model *)
exception NoClassFound of (Symbol.symbol * Symbol.symbol list)
exception NoIteratorFound of (Symbol.symbol)

val showStackTrace = ref false

fun setShowStackTrace(bool) =
    showStackTrace := bool

open Printer

fun log_stack e () =
(*    if (!showStackTrace) then*)
	[$"Stack trace:",
	 (SUB (map (fn(s) => $s) (MLton.Exn.history e)))]
(*    else
	[]
*)				  

fun log handlelocation (e as InternalError {message, severity, characterization, location}) =
    (Logger.log_exception characterization severity 
    		(SUB (($("Exception caught at " ^ handlelocation 
			   ^ " and raised at " ^ location ^ " - (" ^ message ^ ")")) ::
                      (*(log_stack e ())*)nil)))
  | log handlelocation (e as TooManyErrors) =
    ()

  | log handlelocation e = 
    let val message =
	    (* Formats builtin basis exceptions. *)
	    case e of Bind => "Bind exception at " ^ handlelocation
		    | Chr => "Chr exception at " ^ handlelocation
		    | Div => "Div exception at " ^ handlelocation
		    | Domain => "Domain exception at " ^ handlelocation
		    | Empty => "Empty exception at " ^ handlelocation
		    | Fail reason => "Failed at " ^ handlelocation ^ " because " ^ reason
		    | Match => "Match exception at " ^ handlelocation
		    | Option => "Option exception at " ^ handlelocation
		    | Overflow => "Overflow exception at " ^ handlelocation
		    | Size => "Size exception at " ^ handlelocation
		    | Span => "Span exception at " ^ handlelocation
		    | Subscript => "Subscript exception at " ^ handlelocation
		    | Date.Date => "Date exception at " ^ handlelocation
		    | IEEEReal.Unordered => "IEEEReal.Unordered exception at " ^ handlelocation
		    | IO.Io {name, function, cause} => 
		      "IO.Io exception at " ^ handlelocation
		    | IO.BlockingNotSupported => "IO.BlockingNotSupported at " ^ handlelocation
		    | IO.NonblockingNotSupported => "IO.NonblockingNotSupported at " ^ handlelocation
		    | IO.RandomAccessNotSupported => "IO.RandomAccessNotSupported at " ^ handlelocation
		    | IO.ClosedStream => "IO.ClosedStream exception at " ^ handlelocation
		    | ListPair.UnequalLengths => "ListPair.UnequalLengths exception at " ^ handlelocation
		    | OS.SysErr (message, err) => "OS.SysErr at " ^ handlelocation ^ " because " ^ message
		    | OS.IO.Poll => "OS.IO.Poll exception at " ^ handlelocation
		    | OS.Path.Path => "Path exception at " ^ handlelocation
		    | OS.Path.InvalidArc => "Path.InvalidArc exception at " ^ handlelocation
		    | Time.Time => "Time exception at " ^ handlelocation
		    (* Custom exceptions *)
		    | RestartRepl => "Restart Repl exception at " ^ handlelocation
		    | SettingsError => "Settings exception at " ^ handlelocation
		    | TypeMismatch str => "Type mismatch exception at " ^ handlelocation ^ ": " ^ str
		    | ValueError str => "Value error exception at " ^ handlelocation ^ ": " ^ str
		    | NameError str => "Name error exception at " ^ handlelocation ^ ": " ^ str
		    | NameConflictError str => "Name conflict error exception at " ^ handlelocation ^ ": " ^ str
		    | ImportError (file, paths) => "Import error exception at " ^ handlelocation ^ " for file " ^ file
		    | IncorrectNumberOfArguments {expected, actual} => "Incorrect number of arguments exception at " ^ handlelocation
		    | NoClassFound (classname, classlist) => ("No class with name '"^(Symbol.name classname)^"' found, options are: " ^ (GeneralUtil.symlist2s classlist))
		    | NoIteratorFound (itername) => "No iterator with name '"^(Symbol.name itername)^"' found"
		    | _ => raise UnknownError (handlelocation, e)
    in
	Logger.log_exception Logger.OTHER Logger.FAILURE ($(message))
    end
    handle UnknownError (handlelocation, e) => 
	   let
	       val message = "Unknown exception caught at " ^ handlelocation
	   in
	       (Logger.log_exception Logger.OTHER Logger.FAILURE ($(message));
		Logger.log_error (Printer.SUB(log_stack e ())))
	   end

fun checkpoint handlelocation e =
    (log handlelocation e;
     raise e)


fun stdException (message, location, characterization) =
    raise InternalError {message=message,
			 severity=Logger.ERROR,
			 characterization=characterization,
			 location=location}

fun exit () =
    stdException ("Premature exit", "DynException.exit", Logger.INTERNAL)

val terminal_errors = ref false

fun setErrored() =
    terminal_errors := true

fun resetErrored() =
    terminal_errors := false

fun checkToProceed() =
    if (!terminal_errors) then
	raise TooManyErrors
    else
	()

fun isErrored() = !terminal_errors

fun assert flag message =
    if not flag then
	(Logger.log_exception Logger.ASSERTION Logger.FAILURE message;
	 setErrored())
    else
	()
		

end
