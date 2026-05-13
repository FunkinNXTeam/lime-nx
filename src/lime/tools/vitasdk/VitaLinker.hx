package lime.tools.vitasdk;

import hxp.System;
import hxp.Path;
import hxp.Log;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef VitaCMakeArgs = {
	var vitaExportPath:String;
	var projectName:String;
	var projectTitle:String;
	var projectAuthor:String;
	var projectVersion:String;
	var projectTitleId:String;
	var mainLibPath:String;
	var dataPath:String;
	var outputDir:String;
	var limePath:String;
	var hxcppPath:String;
	var cmakeTemplate:String;
	var maxJobs:Int;
	@:optional var additionalLibs:Array<String>;
}

class VitaLinker
{
	public static function finalBuild(args:VitaCMakeArgs):Void
	{
		var basePath = Sys.getCwd().replace("\\", "/");

		var exportPath = args.vitaExportPath;
		if (Path.isRelative(exportPath))
		{
			exportPath = Path.combine(basePath, exportPath);
		}

		var objDir = Path.combine(exportPath, "obj");
		var binDir = Path.combine(exportPath, "bin");

		if (!FileSystem.exists(objDir)) FileSystem.createDirectory(objDir);
		if (!FileSystem.exists(binDir)) FileSystem.createDirectory(binDir);

		args.vitaExportPath = exportPath;

		createCMake(args);
		compileCMake(args);
	}

	private static function createCMake(args:VitaCMakeArgs):Void
	{
		var sdk = Sys.getEnv("VITASDK");
		if (sdk == null || sdk == "")
		{
			Log.error("VITASDK environment variable is not set.");
			return;
		}

		var cmake = args.cmakeTemplate;
		var exportPath = args.vitaExportPath;
		var objDir = Path.combine(exportPath, "obj");
		cmake = cmake.replace("[LIME_PROJECT_FILENAME]", args.projectName);
		cmake = cmake.replace("[LIME_PROJECT_TITLE]", args.projectTitle);
		cmake = cmake.replace("[LIME_PROJECT_AUTHOR]", args.projectAuthor);
		cmake = cmake.replace("[LIME_PROJECT_VERSION]", args.projectVersion);
		cmake = cmake.replace("[LIME_PROJECT_TITLEID]", args.projectTitleId);
		cmake = cmake.replace("[LIME_MAIN_SRC_DIR]", objDir);
		var libFileName = Path.withoutDirectory(args.mainLibPath);
		cmake = cmake.replace("[HAXE_MAIN_LIB]", Path.combine(exportPath, "obj/" + libFileName));
		cmake = cmake.replace("[LIME_MAIN_DIR]", Path.combine(exportPath, "obj/LIME_LIB"));
		var absoluteOutDir = Path.combine(exportPath, "bin");
		cmake = cmake.replace("[OUT_DIR]", absoluteOutDir);
		cmake = cmake.replace("[VITA_DATA_DIR]", args.dataPath);
		cmake = cmake.replace("$ENV{VITASDK}", sdk);
		cmake = cmake.replace("${VITASDK}", sdk);

		var additionalLibsStr = "";
		if (args.additionalLibs != null && args.additionalLibs.length > 0)
		{
			var validLibs = args.additionalLibs.filter(lib -> lib != null && lib != "");
			if (validLibs.length > 0)
			{
				additionalLibsStr = "\n    " + validLibs.map(lib -> lib.startsWith("-l") ? lib : "-l" + lib).join("\n    ");
			}
		}
		cmake = cmake.replace("[ADDITIONAL_LIBS]", additionalLibsStr);

		var cmakePath = Path.combine(exportPath, "obj/CMakeLists.txt");
		File.saveContent(cmakePath, cmake);

		var stubPath = Path.combine(exportPath, "obj/_stub.c");
		if (!FileSystem.exists(stubPath))
		{
			File.saveContent(stubPath,
				"/* lime-vita stub — entry point is inside libApplicationMain.a */\n" +
				"void _lime_vita_stub(void) {}\n"
			);
		}
		Log.info("CMakeLists.txt created at: " + cmakePath);
		Log.info("VITASDK resolved to: " + sdk);
		if (args.additionalLibs != null && args.additionalLibs.length > 0)
		{
			var validLibs = args.additionalLibs.filter(lib -> lib != null && lib != "");
			if (validLibs.length > 0)
			{
				Log.info("Additional libraries: " + validLibs.join(", "));
			}
		}
	}

	private static function compileCMake(args:VitaCMakeArgs):Void
	{
		var sdk = Sys.getEnv("VITASDK");
		if (sdk == null || sdk == "")
		{
			Log.error("VITASDK environment variable is not set.");
			return;
		}

		var toolchainFile = Path.combine(sdk, "share/vita.toolchain.cmake");

		if (!FileSystem.exists(toolchainFile))
		{
			Log.error("VitaSDK toolchain file not found at: " + toolchainFile);
			return;
		}

		var objDir = Path.combine(args.vitaExportPath, "obj");
		var originalDir = Sys.getCwd();

		var cacheFile = Path.combine(objDir, "CMakeCache.txt");
		if (FileSystem.exists(cacheFile))
		{
			FileSystem.deleteFile(cacheFile);
			Log.info("Deleted stale CMakeCache.txt");
		}
		var cmakeFilesDir = Path.combine(objDir, "CMakeFiles");
		if (FileSystem.exists(cmakeFilesDir))
		{
			System.removeDirectory(cmakeFilesDir);
			Log.info("Deleted stale CMakeFiles/");
		}

		Sys.setCwd(objDir);

		// config
		var cmakeResult = System.runCommand("", "cmake", [
			"-DCMAKE_TOOLCHAIN_FILE=" + toolchainFile,
			"-DCMAKE_BUILD_TYPE=Release",
			"."
		]);

		if (cmakeResult != 0)
		{
			Sys.setCwd(originalDir);
			Log.error("CMake configuration failed for PS Vita!");
			return;
		}

		// build
		var makeResult = System.runCommand("", "make", ["-j" + args.maxJobs]);

		Sys.setCwd(originalDir);

		if (makeResult != 0)
		{
			Log.error("PS Vita compilation failed!");
		}
	}
}
