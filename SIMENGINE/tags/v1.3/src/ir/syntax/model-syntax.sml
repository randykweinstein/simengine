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

(* Copyright (C) 2010 by Simatra Modeling Technologies, L.L.C. *)

structure ModelSyntax: sig
(* Serialization and deserialization for DOF model data. *)

val toJSON: DOF.model -> JSON.json
val iteratorToJSON: DOF.systemiterator -> JSON.json
val propertiesToJSON: DOF.systemproperties -> JSON.json
(* TODO implement fromJSON *)

end = struct

open JSON
open JSONExtensions

val int = int o IntInf.fromInt
fun symbol s = JSON.object [("$symbol", JSON.string (Symbol.name s))]

fun toJSON (classes, instance as {name, classname}, properties) =
    object [("classes", array (map ClassSyntax.toJSON classes)),
	    ("instance", object [("name", JSONOption (symbol, name)),
				 ("classname", symbol classname)]),
	    ("properties", propertiesToJSON properties)]

and propertiesToJSON {debug, iterators, parallel_models, precision, profile, target} =
    object [("debug", bool debug),
	    ("iterators", array (map iteratorToJSON iterators)),
	    ("parallelModels", int parallel_models),
	    ("precision", JSONType (case precision of DOF.SINGLE => "DOF.SINGLE" | DOF.DOUBLE => "DOF.DOUBLE")),
	    ("profile", bool profile),
	    ("target", targetToJSON target)]

and iteratorToJSON (name, domain) =
    object [("name", symbol name),
	    ("domain", (case domain
			 of DOF.CONTINUOUS solver => 
			    JSONTypedObject ("DOF.CONTINUOUS", 
					     string (Solver.solver2name solver))
			  | DOF.DISCRETE {sample_period} => 
			    JSONTypedObject ("DOF.DISCRETE",
					     object [("samplePeriod", real sample_period)])
			  | DOF.UPDATE parent => 
			    JSONTypedObject ("DOF.UPDATE", symbol parent)
			  | DOF.ALGEBRAIC (DOF.PREPROCESS, parent) => 
			    JSONTypedObject ("DOF.PREPROCESS", symbol parent)
			  | DOF.ALGEBRAIC (DOF.INPROCESS, parent) => 
			    JSONTypedObject ("DOF.INPROCESS", symbol parent)
			  | DOF.ALGEBRAIC (DOF.POSTPROCESS, parent) => 
			    JSONTypedObject ("DOF.POSTPROCESS", symbol parent)
			  | DOF.IMMEDIATE => 
			    JSONType ("DOF.IMMEDIATE")))]

and targetToJSON (Target.CPU) = JSONType ("Target.CPU")
  | targetToJSON (Target.OPENMP) = JSONType ("Target.OPENMP")
  | targetToJSON (Target.CUDA) = JSONType ("Target.CUDA")

end
