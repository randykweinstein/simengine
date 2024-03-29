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

signature LICENSE =
sig
    (* license info data types*)
    datatype product = SIMENGINE
    datatype version = TRIAL | BASIC | STANDARD | PROFESSIONAL | DEVELOPMENT

    datatype restriction = USERNAME of string
			 | HOSTID of string
			 | LICENSESERVER of string
			 | SITE of string

    type enhancements = {}

    type license

    (* default license *)
    val default : license

    (* constructor *)
    val make: {product: product,
	       customerID: int,
	       customerName: string,
	       customerOrganization: string,
	       restriction: restriction,
	       serialNumber: int,
	       maxMajorVersion: int,
	       maxMinorVersion: int,
	       expirationDate: Date.date option,
	       version: version,
	       enhancements: enhancements} -> license

    (* accessor methods *)
    val product: license -> product
    val customerID: license -> int
    val customerName: license -> string
    val customerOrganization: license -> string
    val restriction: license -> restriction
    val serialNumber: license -> int
    val maxMinorVersion: license -> int
    val maxMajorVersion: license -> int
    val expirationDate: license -> Date.date option
    val version: license -> version

    (* low level routines to convert Licenses to/from internal SML structure and external string format *)
    val licenseFromData : string -> license option
    (*val licenseToData : license -> string*)

    val toJSON: license -> JSON.json
    val verifyLicenseToJSONCallback : (license -> JSON.json) -> unit
end

structure License: LICENSE =
struct

exception InvalidLicenseFile

(* the various forms of base packages we offer *)
datatype product = SIMENGINE
datatype version = TRIAL | BASIC | STANDARD | PROFESSIONAL | DEVELOPMENT

datatype restriction = USERNAME of string
		     | HOSTID of string
		     | LICENSESERVER of string
		     | SITE of string

type enhancements = {} (* Container for add-on features, i.e. Penguin target *)

datatype license = LICENSE of
	 {product: product,
	  customerID: int,
	  customerName: string,
	  customerOrganization: string,
	  restriction: restriction,
	  serialNumber: int,
	  maxMajorVersion: int,
	  maxMinorVersion: int,
	  expirationDate: Date.date option,
	  version: version,
	  enhancements: enhancements}

val make = LICENSE

local fun acc f (LICENSE x) = f x
in
val product = acc #product
val customerID = acc #customerID
val customerName = acc #customerName
val customerOrganization = acc #customerOrganization
val restriction = acc #restriction
val serialNumber = acc #serialNumber
val maxMinorVersion = acc #maxMinorVersion
val maxMajorVersion = acc #maxMajorVersion
val expirationDate = acc #expirationDate
val version = acc #version
val enhancements = acc #enhancements
end


(* This is set in current-license.sml and will validate a given license, returning an error message if applicable in JSON format *)
val verifyToJSONFunRef = ref (fn(_)=>JSON.null)
fun verifyLicenseToJSONCallback (verifyToJSONFun) = 
    verifyToJSONFunRef := verifyToJSONFun

local 
    open JSON
    val int = int o IntInf.fromInt
    val date = string o (*Date.toString*) Date.fmt "%B %d, %Y" 
in
fun toJSON license =
    object [("customerID", int (customerID license)),
	    ("customerName", string (customerName license)),
	    ("customerOrganization", string (customerOrganization license)),
	    ("serialNumber", int (serialNumber license)),
	    ("maxMinorVersion", int (maxMinorVersion license)),
	    ("maxMajorVersion", int (maxMajorVersion license)),
	    ("expirationDate", case expirationDate license
				of SOME d => date d
				 | NONE => null),
	    ("product", string (case product license 
				 of SIMENGINE => "SIMENGINE")),
	    ("version", string (case version license 
				 of TRIAL => "TRIAL"
				  | BASIC => "BASIC"
				  | STANDARD => "STANDARD"
				  | PROFESSIONAL => "PROFESSIONAL"
				  | DEVELOPMENT => "DEVELOPMENT")),
	    ("restriction", object (case restriction license
				     of USERNAME user => [("USERNAME", string user)]
				      | HOSTID host => [("HOSTID", string host)]
				      | LICENSESERVER server => [("LICENSESERVER", string server)]
				      | SITE name => [("SITE", string name)])),
	    ("enhancements", null),
	    ("status", (!verifyToJSONFunRef) license)]
end

(* Default to a basic license *)
val default =
    make {product=SIMENGINE,
	  customerID=0,
	  customerName="OSS User",
	  customerOrganization="",
	  restriction=SITE "Open Source License",
	  serialNumber=0,
	  maxMajorVersion=9999,
	  maxMinorVersion=9999,
	  expirationDate=NONE,
	  version=DEVELOPMENT,
	  enhancements={}}


(* Sanity check to identify a decoded license as valid data *)
val currentLicenseHeader = 0x00cafe00

val secondsPerDay = 60 * 60 * 24

(* Unencrypted license keys are limited to a total of ~240 bytes (2048 bit RSA key minus space used
   to encode length of encrypted data) 
   This value limits the total size of the three encoded strings to a total of 180 bytes accounting
   for the 13 integer fields plus some wiggle room for future changes. *)
val maxKeyStringLength = 180

(* Fuctions that provide composed RSA encryption/decrytion and base64 encoding/decoding *)
(*
val licenseDecode' = 
    _import "license_Decode": (Int32.int * string) -> Int32.int;

val licenseEncode' =
    _import "license_Encode": (Int32.int * string) -> Int32.int;

fun licenseDecode cipher =
    case licenseDecode' (String.size cipher, cipher)
     of 0 => SOME (FFIExports.getTheString ())
      | n => NONE (*raise Fail ("Failed to decode license; error " ^ (Int.toString n))*)

fun licenseEncode licenseData =
    case licenseEncode' (String.size licenseData, licenseData)
     of 0 => FFIExports.getTheString () 
      | n => raise Fail ("Failed to encode license; error " ^ (Int.toString n))
*)
(* add dummy routines to allow the type checker to work fine even if the licensing is removed *)
val licenseDecode = fn(cipher) => NONE
val licenseEncode = fn(data) => ""

(* Serialization/deserialization functions for packing/unpacking integers and strings together to/from a string of bytes *)
fun bytesToInt bytes =
    LargeWord.toInt (PackWord32Little.subVec (bytes, 0))

fun intToBytes int =
    let val bytes = Word8Array.array (4, 0w0)
    in PackWord32Little.update (bytes, 0, Word64.fromInt int)
     ; Word8Array.vector bytes
    end

fun deqInt str =
    (String.extract (str, 4, NONE),
     bytesToInt (Byte.stringToBytes (String.substring (str, 0, 4))))

fun enqInt (str, int) =
    String.concat [str, Byte.bytesToString (intToBytes int)]

fun deqStr (str, len) = (String.extract(str, len, NONE), String.extract(str, 0, SOME len))

fun enqStr (str, s) = String.concat [str, s]


(* Decomposes a packed string license format into the SML license type *)
fun licenseFromData data = 
    let
	val licenseData = case licenseDecode data of
			      SOME d => d
			    | NONE => raise InvalidLicenseFile
	val (licenseData, licenseHeader) = deqInt(licenseData)
	val _ = if (licenseHeader <> currentLicenseHeader) then
		    raise InvalidLicenseFile
		else
		    ()
	val (licenseData, productCode) = deqInt(licenseData)
	val product : product = case productCode of
				    0 => SIMENGINE
				  | _ => raise InvalidLicenseFile
	val (licenseData, serialNumber) = deqInt(licenseData)
	val (licenseData, productVersionCode) = deqInt(licenseData)
	val productVersion : version = case productVersionCode of
					   0 => BASIC
					 | 1 => STANDARD
					 | 2 => PROFESSIONAL
					 | 3 => DEVELOPMENT
					 | 4 => TRIAL
					 | _ => raise InvalidLicenseFile
	val (licenseData, majorVersion) = deqInt(licenseData)
	val (licenseData, minorVersion) = deqInt(licenseData)
	val (licenseData, customerID) = deqInt(licenseData)
	val (licenseData, restrictionCode) = deqInt(licenseData)
	val (licenseData, expiration) = deqInt(licenseData)
	(* expiration is stored as days inside the format *)
	val expirationDate = case expiration of
				 0 => NONE
			       | _ => SOME (Date.fromTimeLocal(Time.fromSeconds(IntInf.fromInt(expiration * secondsPerDay))))
	val (licenseData, enhancements) = deqInt(licenseData)
	val (licenseData, customerNameLen) = deqInt(licenseData)
	val (licenseData, customerOrgLen) = deqInt(licenseData)
	val (licenseData, restrictionLen) = deqInt(licenseData)
	val (licenseData, customerName) = deqStr(licenseData, customerNameLen)
	val (licenseData, customerOrg) = deqStr(licenseData, customerOrgLen)
	val (licenseData, restriction) = deqStr(licenseData, restrictionLen)
	val restriction = case restrictionCode of
			      0 => USERNAME restriction
			    | 1 => HOSTID restriction
			    | 2 => LICENSESERVER restriction
			    | 3 => SITE restriction
			    | _ => raise InvalidLicenseFile
	val lic =
	    LICENSE {product=product,
		     customerID=customerID,
		     customerName=customerName,
		     customerOrganization=customerOrg,
		     restriction=restriction,
		     serialNumber=serialNumber,
		     maxMajorVersion=majorVersion,
		     maxMinorVersion=minorVersion,
		     expirationDate=expirationDate,
		     version=productVersion,
		     enhancements={}}
    in
	SOME lic
    end
    handle InvalidLicenseFile => NONE

(* Composes a packed string license format from the SML license type *)
fun licenseToData (LICENSE
		       {product, customerID, customerName, customerOrganization, restriction, serialNumber,
			maxMajorVersion, maxMinorVersion, expirationDate, version, enhancements}) = 
    let
	val (restrictionCode, restriction) = case restriction of
						 USERNAME s => (0, s)
					       | HOSTID s => (1, s)
					       | LICENSESERVER s => (2, s)
					       | SITE s => (3, s)
	val _ = if (String.size(customerName) + String.size(customerOrganization) + String.size(restriction)) > maxKeyStringLength then
		    raise Fail "Total length of Name, Organization and Restriction Value strings exceeds limit."
		else
		    ()

	val licenseData = ""
	val licenseData = enqInt(licenseData, currentLicenseHeader)
	val product = case product of
			  SIMENGINE => 0
	val licenseData = enqInt(licenseData, product)
	val licenseData = enqInt(licenseData, serialNumber)
	val productVersion = case version of
				 BASIC => 0
			       | STANDARD => 1
			       | PROFESSIONAL => 2
			       | DEVELOPMENT => 3
			       | TRIAL => 4
	val licenseData = enqInt(licenseData, productVersion)
	val licenseData = enqInt(licenseData, maxMajorVersion)
	val licenseData = enqInt(licenseData, maxMinorVersion)
	val licenseData = enqInt(licenseData, customerID)
	val licenseData = enqInt(licenseData, restrictionCode)
	val expiration = case expirationDate of
			     NONE => 0
			   | SOME dt => Int.div (IntInf.toInt(Time.toSeconds (Date.toTime(dt))), secondsPerDay)
	val licenseData = enqInt(licenseData, expiration)
	val enhancements = 0
	val licenseData = enqInt(licenseData, enhancements)
	val licenseData = enqInt(licenseData, String.size(customerName))
	val licenseData = enqInt(licenseData, String.size(customerOrganization))
	val licenseData = enqInt(licenseData, String.size(restriction))
	val licenseData = enqStr(licenseData, customerName)
	val licenseData = enqStr(licenseData, customerOrganization)
	val licenseData = enqStr(licenseData, restriction)
    in
	licenseEncode licenseData
    end

end
