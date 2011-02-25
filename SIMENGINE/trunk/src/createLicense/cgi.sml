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

signature CGI =
sig
    exception NoCgiInterface of string
    datatype method = GET | POST

    val keyValues: unit -> (string * string) list
    val method: unit -> method
end

structure Cgi: CGI =
struct

exception NoCgiInterface of string

datatype method = GET | POST

fun method () = case (OS.Process.getEnv("REQUEST_METHOD")) of
		    SOME m => if m = "GET" then GET else POST
		  | NONE => raise NoCgiInterface "Request method not set."

fun rawCgiData ()= case method () of
		       GET => (valOf (OS.Process.getEnv("QUERY_STRING"))
			       handle _ => raise NoCgiInterface "Could not retrieve GET CGI data!")
		     | POST => 
		       let
			   val contentLength = valOf ((StringCvt.scanString (Int.scan StringCvt.DEC))(valOf (OS.Process.getEnv ("CONTENT_LENGTH"))))
			   val content = TextIO.inputN (TextIO.stdIn, contentLength)
		       in
			   content
		       end
		       handle _ => raise NoCgiInterface "Could not retrieve POST CGI data!"

fun kvPairDelim c = (c = #"&" orelse c = #";")
fun kvDelim c = (c = #"=")

fun decodeURL s =
    let
	val noSpaces = String.translate (fn c => if c = #"+" then " " else Char.toString c) s
	fun decode s =
	    if s = "" then
		""
	    else
		let
		    val first = String.substring (s, 0, 1)
		in
		    if first <> "%" then
			 first ^ decode (String.extract (s, 1, NONE))
		    else
			let
			    val hexCodeChar = Char.chr (valOf ((StringCvt.scanString (Int.scan StringCvt.HEX))(String.substring (s, 1, 2))))
			in
			    (String.str hexCodeChar) ^ decode (String.extract (s, 3, NONE))
			end
		end
    in
	decode noSpaces
    end

fun kvPairStrings () = String.fields kvPairDelim (rawCgiData ())

val keyValueData : (string * string ) list option ref = ref NONE

fun keyValues () = 
    case !keyValueData of
	NONE =>
	(keyValueData := SOME (List.map  (fn s =>
					     let
						 val keyValList = String.fields kvDelim s
						 val key = decodeURL (hd keyValList)
						 val value = decodeURL (List.last keyValList)
					     in
						 (key, value)
					     end)
					 (kvPairStrings ()))
       ; valOf (!keyValueData))
      | SOME keyVals => keyVals

end
