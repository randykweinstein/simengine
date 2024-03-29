namespace Archive

  namespace Simlib
    function makeObjectFromFile(objectName, filename) = LF makeObjectFromFile(objectName, filename)
    function makeObjectFromContents(objectName, data) = LF makeObjectFromContents(objectName, data)
    function getFileFromArchive(archive, objectName, filename) = LF getFileFromArchive(archive, objectName, filename)
    function getContentsFromArchive(archive, objectName) = LF getContentsFromArchive(archive, objectName)
  end

  constant VERSION = 0

  class Archive
    var dirty
    var filename
    var manifest
    var workingPath

    constructor (isDirty, aFilename, aWorkingPath, aManifest)
      dirty = isDirty
      filename = aFilename
      workingPath = aWorkingPath
      manifest = aManifest
    end
  end

  // Opens an existing archive with a given filename.
  // Returns () if a file with that name doesn't exist or
  // if the file is not a valid archive.
  function openArchive (filename)
    var manifest = Simlib.getContentsFromArchive (filename, "MANIFEST.json")
    if () == manifest then ()
    else
      Archive.new (false, filename, Path.join (FileSystem.pwd (), ".simatra"), JSON.decode manifest)
    end
  end

  function createManifest (dolFilename, dslFilenames, environment, executables)
    {creationDate = Time.timestampInSeconds (),
     dolFilename = dolFilename,
     dslFilenames = dslFilenames,
     environment = environment,
     executables = executables,
     version = VERSION}
  end

  // Creates a new archive with a given filename. 
  // It is an error to attempt to create an archive if a file with that name already exists.
  function createArchive (filename, dolFilename, dslFilenames, target, compiler_settings)
    var environment = {FIXME="needs environment"}

    var manifest = createManifest (dolFilename, dslFilenames, environment, [compiler_settings])

    Archive.new (true, filename, Path.join (FileSystem.pwd (), ".simatra"), manifest)

    var manifest_o = Simlib.makeObjectFromContents ("MANIFEST.json", JSON.encode (manifest))

    var cfile = compiler_settings.cSourceFilename
    var cfile_o = Simlib.makeObjectFromFile (Path.file cfile, cfile)
    var ofile = (Path.base (Path.file cfile)) + ".o"

    var main = dslFilenames.first ()
    var imports = dslFilenames.rest ()
    var dir = Path.dir (main)
    var main_o = Simlib.makeObjectFromFile (Path.file main, main)
    var import_os = []
    foreach i in imports do
      var path = Path.join (dir, i)
      import_os.push_back (Simlib.makeObjectFromFile (i, path))
    end

    var cc = target.compile (ofile, [cfile])
    compile (cc(1), cc(2))

    var objects = [ofile, manifest_o, cfile_o, main_o] + import_os
    var ld = target.link (Path.file filename, filename, objects)
    link (ld(1), ld(2))

    if compiler_settings.debug == false then
      FileSystem.rmfile (cfile)
    end
    foreach o in objects do
      FileSystem.rmfile (o)
    end

    filename
  end

  hidden function compile (cc, ccflags)
    var ccp = Process.run(cc,ccflags)
    var ccallout = Process.readAll(ccp)
    var ccstat = Process.reap(ccp)
    var ccout = ccallout(1)
    var ccerr = ccallout(2)
    if 0 <> ccstat then
      println ("STDOUT:" + join("", ccout))
      println ("STDERR:" + join("", ccerr))
      error ("OOPS! Compiler returned non-zero exit status " + ccstat)
    end
  end

  hidden function link (ld, ldflags)
    var ldp = Process.run(ld, ldflags)
    var ldallout = Process.readAll(ldp) 
    var ldstat = Process.reap(ldp)
    var ldout = ldallout(1)
    var lderr = ldallout(2)
    if 0 <> ldstat then
      println (join("", ldout))
      println (join("", lderr))
      error ("OOPS! Linker returned non-zero exit status " + ldstat)
    end
  end

  function destroy (archive)
    if archive.dirty then
      // FIXME delete working files
    end
    FileSystem.rmfile (archive.filename)
  end

  // Returns the version id of the archive. 
  // Archives with differing versions are not ensured to be compatible.
  function version (archive) = archive.version
  // Returns the time at which the archive was created.
  function creationDate (archive) = archive.manifest.creationDate

  // Returns the pathname of the DOL settings file used when compiling.
  function dolFilename (archive) = archive.manifest.dolFilename

  // Returns the vector of pathnames for all files making up this model.
  // The first element will be an absolute path to the main DSL file.
  // Other elements are relative paths of imported files. 
  function dslFilenames (archive) = archive.manifest.dslFilenames

  // Applies a predicate function to each executable in the manifest,
  // until the predicate is satisfied or all executables have been
  // evaluated.
  // Returns the executable satisfying the predicate or 
  // () if the predicate could not be satisfied.
  function findExecutable (archive, predicate)
    function recur (executables)
      if executables.isempty () then ()
      else 
	var car = executables.first ()
	if predicate car then car
	else recur (executables.rest ())
	end
      end
    end
    recur (archive.manifest.executables)
  end
end
