package;

import lime.tools.HashlinkHelper;
import hxp.Haxelib;
import hxp.HXML;
import hxp.Path;
import hxp.Log;
import hxp.NDLL;
import hxp.System;
import lime.tools.Architecture;
import lime.tools.AssetHelper;
import lime.tools.AssetType;
import lime.tools.CPPHelper;
import lime.tools.DeploymentHelper;
import lime.tools.HXProject;
import lime.tools.JavaHelper;
import lime.tools.NekoHelper;
import lime.tools.NodeJSHelper;
import lime.tools.Orientation;
import lime.tools.Platform;
import lime.tools.PlatformTarget;
import lime.tools.ProjectHelper;
import lime.tools.vitasdk.VitaLinker;
import lime.tools.Icon;
import lime.tools.IconHelper;
import lime.graphics.Image;
import lime.graphics.ImageFileFormat;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import haxe.Resource;
import haxe.io.Eof;

using StringTools;

class VitaPlatform extends PlatformTarget
{
	private var applicationDirectory:String;
	private var executablePath:String;
	private var targetType:String;
	private var sceDirPath:String;

	public function new(command:String, _project:HXProject, targetFlags:Map<String, String>)
	{
		super(command, _project, targetFlags);

		var defaults = new HXProject();

		defaults.meta =
			{
				title: "MyApplication",
				description: "",
				packageName: "com.example.myapp",
				version: "1.0.0",
				company: "",
				companyUrl: "",
				buildNumber: null,
				companyId: ""
			};

		defaults.app =
			{
				main: "Main",
				file: "MyApplication",
				path: "export",
				preloader: "",
				swfVersion: 17,
				url: "",
				init: null
			};

		defaults.window =
			{
				width: 960,
				height: 544,
				parameters: "{}",
				background: 0xFFFFFF,
				fps: 60,
				hardware: true,
				display: 0,
				resizable: false,
				borderless: false,
				orientation: Orientation.AUTO,
				vsync: false,
				fullscreen: false,
				allowHighDPI: false,
				alwaysOnTop: false,
				antialiasing: 0,
				allowShaders: true,
				requireShaders: false,
				depthBuffer: true,
				stencilBuffer: true,
				colorDepth: 32,
				maximized: false,
				minimized: false,
				hidden: false,
				title: ""
			};

		defaults.architectures = [ARMV7];

		for (i in 1...project.windows.length)
		{
			defaults.windows.push(defaults.window);
		}

		defaults.merge(project);
		project = defaults;

		for (excludeArchitecture in project.excludeArchitectures)
		{
			project.architectures.remove(excludeArchitecture);
		}

		targetType = "cpp";

		var defaultTargetDirectory = "vita";
		var relativeTarget = Path.combine(project.app.path, project.config.getString("vita.output-directory", defaultTargetDirectory));
		targetDirectory = Path.combine(Sys.getCwd(), relativeTarget).replace("\\", "/");
		applicationDirectory = targetDirectory + "/bin/";
		executablePath = Path.combine(applicationDirectory, project.app.file);
	}

	private function getLimePath():String
	{
		return Haxelib.getPath(new Haxelib("lime"));
	}

	private function resolveSceDirPath():String
	{
		var value:String = null;

		if (project.defines != null && project.defines.exists("SCE_DIR"))
		{
			value = Std.string(project.defines.get("SCE_DIR"));
		}

		if ((value == null || value.trim() == "") && project.projectFilePath != null && project.projectFilePath.endsWith(".hxp"))
		{
			try
			{
				var content = File.getContent(project.projectFilePath);
				var re = ~/static\s+final\s+SCE_DIR\s*:\s*String\s*=\s*"([^"]+)"\s*;/m;
				if (re.match(content))
				{
					value = re.matched(1);
				}
			}
			catch (e:Dynamic) {}
		}

		if (value == null || value.trim() == "")
		{
			Log.error("Missing required PSVita SCE assets directory. Define SCE_DIR in project.xml (e.g. <define name=\"SCE_DIR\" value=\"sce_sys\" />) or in project.hxp (static final SCE_DIR:String = \"sce_sys\";).");
			return null;
		}

		value = value.trim();

		var baseDir = (project.projectFilePath != null) ? Path.directory(project.projectFilePath) : Sys.getCwd();
		var resolved = Path.isRelative(value) ? Path.combine(baseDir, value) : value;
		resolved = Path.standardize(resolved).replace("\\", "/");

		if (!FileSystem.exists(resolved) || !FileSystem.isDirectory(resolved))
		{
			Log.error("SCE_DIR does not exist or is not a directory: " + resolved);
			return null;
		}

		return resolved;
	}

	public override function build():Void
	{
		var hxml = targetDirectory + "/haxe/" + buildType + ".hxml";

		System.mkdir(targetDirectory);

		if (targetType == "cpp")
		{
			var haxeArgs = [hxml];
			var flags = [];

			var sdk = Sys.getEnv("VITASDK");
			if (sdk == null || sdk == "")
			{
				Log.error("Environment variable VITASDK is not defined.");
				return;
			}

			var limePath = getLimePath();

			var haxeArgs = [hxml];
			var flags = [];

			haxeArgs.push("-D"); haxeArgs.push("vita");
			haxeArgs.push("-D"); haxeArgs.push("HX_VITA");
			haxeArgs.push("-D"); haxeArgs.push("static_link");
			haxeArgs.push("-D"); haxeArgs.push("HXCPP_ARMV7");
			haxeArgs.push("-D"); haxeArgs.push("xcompile");
			haxeArgs.push("-D"); haxeArgs.push("vita");
			haxeArgs.push("-D"); haxeArgs.push("LIME_VITA_PURE_VITAGL");
			haxeArgs.push("-D"); haxeArgs.push('VITASDK=$sdk');
			haxeArgs.push("-D"); haxeArgs.push("BINDIR=Vita");
			haxeArgs.push("-D"); haxeArgs.push('HXCPP_XLINUX32_CXX=$sdk/bin/arm-vita-eabi-g++');
			haxeArgs.push("-D"); haxeArgs.push('HXCPP_XLINUX32_AR=$sdk/bin/arm-vita-eabi-ar');
			haxeArgs.push("-D"); haxeArgs.push('HXCPP_XLINUX32_RANLIB=$sdk/bin/arm-vita-eabi-ranlib');
			haxeArgs.push("-D"); haxeArgs.push('HXCPP_XLINUX32_STRIP=$sdk/bin/arm-vita-eabi-strip');
			var optFlags = project.debug ? "-O0 -g" : "-O3 -DNDEBUG";
			var ldExtra = project.debug ? " -g" : "";
			haxeArgs.push("-D"); haxeArgs.push("HXCPP_CPPFLAGS=-marm -mthumb-interwork " + optFlags);
			haxeArgs.push("-D"); haxeArgs.push("HXCPP_CFLAGS=-mthumb-interwork " + optFlags);
			haxeArgs.push("-D"); haxeArgs.push("HXCPP_CXXFLAGS=-mthumb-interwork " + optFlags);
			haxeArgs.push("-D"); haxeArgs.push("HXCPP_LDFLAGS=-mthumb-interwork -Wl,--fix-cortex-a8 -Wl,-q" + ldExtra);

			flags.push("-Dvita=1");
			flags.push("-DHX_VITA=1");
			flags.push("-D__PSVITA__");
			flags.push("-DHXCPP_ARMV7");
			flags.push("-Dxcompile");
			flags.push("-DLIME_VITA_PURE_VITAGL");
			flags.push('-DVITASDK=$sdk');
			flags.push("-DBINDIR=Vita");
			flags.push('-DHXCPP_XLINUX32_CXX=$sdk/bin/arm-vita-eabi-g++');
			flags.push('-DHXCPP_XLINUX32_AR=$sdk/bin/arm-vita-eabi-ar');
			flags.push('-DHXCPP_XLINUX32_RANLIB=$sdk/bin/arm-vita-eabi-ranlib');
			flags.push('-DHXCPP_XLINUX32_STRIP=$sdk/bin/arm-vita-eabi-strip');
			flags.push("-DHXCPP_CPPFLAGS=-marm -mthumb-interwork " + optFlags);
			flags.push("-DHXCPP_CFLAGS=-mthumb-interwork " + optFlags);
			flags.push("-DHXCPP_CXXFLAGS=-mthumb-interwork " + optFlags);
			flags.push("-DHXCPP_LDFLAGS=-mthumb-interwork -Wl,--fix-cortex-a8 -Wl,-q" + ldExtra);

			System.runCommand("", "haxe", haxeArgs);

			if (noOutput) return;

			CPPHelper.compile(project, targetDirectory + "/obj", flags);

			var libName = project.debug ? "libApplicationMain-debug.a" : "libApplicationMain.a";
			var staticLib = targetDirectory + "/obj/" + libName;
			Log.info("Static library created: " + staticLib);

			var limePath = getLimePath();
			var path = Path.combine(limePath, "templates/vita/CMakeLists.txt");

			if (!FileSystem.exists(path))
			{
				Log.error("Could not find CMake template at: " + path);
				return;
			}

			var cmakeTemplate = File.getContent(path);

			var additionalLibs = [];
			var libsStr = project.config.getString("vita.libs");
			if (libsStr == null || libsStr == "") libsStr = "";
			additionalLibs = libsStr.split(",").map(s -> s.trim());

			var titleId = project.config.getString("vita.titleid", "LMEVITA01");

			var hxcppPath = Haxelib.getPath(new Haxelib("hxcpp"));
			if (hxcppPath == null || hxcppPath == "")
			{
				Log.error("Could not resolve hxcpp path via haxelib. Is hxcpp installed?");
				return;
			}
			hxcppPath = hxcppPath.replace("\\", "/");
			while (hxcppPath.endsWith("/"))
				hxcppPath = hxcppPath.substr(0, hxcppPath.length - 1);
			Log.info("hxcpp path: " + hxcppPath);

			if (sceDirPath == null || sceDirPath == "")
			{
				sceDirPath = resolveSceDirPath();
				if (sceDirPath == null) return;
			}

			VitaLinker.finalBuild({
				vitaExportPath: targetDirectory,
				projectName: project.app.file,
				projectTitle: project.meta.title,
				projectAuthor: project.meta.company,
				projectVersion: project.meta.version,
				projectTitleId: titleId,
				mainLibPath: staticLib,
				dataPath: sceDirPath,
				outputDir: "bin",
				limePath: limePath,
				hxcppPath: hxcppPath,
				cmakeTemplate: cmakeTemplate,
				maxJobs: 4,
				additionalLibs: additionalLibs
			});
		}
	}

	public override function clean():Void
	{
		if (FileSystem.exists(targetDirectory))
		{
			System.removeDirectory(targetDirectory);
		}
	}

	public override function deploy():Void
	{
		DeploymentHelper.deploy(project, targetFlags, targetDirectory, "PlayStation Vita");
	}

	public override function display():Void
	{
		if (project.targetFlags.exists("output-file"))
		{
			Sys.println(executablePath);
		}
		else
		{
			Sys.println(getDisplayHXML().toString());
		}
	}

	private function generateContext():Dynamic
	{
		var context = project.templateContext;
		context.CPP_DIR = targetDirectory + "/obj/";
		context.BUILD_DIR = project.app.path + "/vita";
		return context;
	}

	private function getDisplayHXML():HXML
	{
		var path = targetDirectory + "/haxe/" + buildType + ".hxml";

		if (FileSystem.exists(path))
		{
			return File.getContent(path);
		}
		else
		{
			var context = project.templateContext;
			var hxml = HXML.fromString(context.HAXE_FLAGS);
			hxml.addClassName(context.APP_MAIN);
			hxml.cpp = "_";
			hxml.noOutput = true;
			return hxml;
		}
	}

	public override function rebuild():Void
	{
		var sdk = Sys.getEnv("VITASDK");
		if (sdk == null || sdk == "")
		{
			Log.error("Environment variable VITASDK is not defined.");
			return;
		}

		var commands = [];

		commands.push([
			"-Dvita=1",
			"-DHX_VITA=1",
			"-Dstatic",
			"-Dstatic_link",
			"-DBINDIR=Vita",
			"-DHXCPP_ARMV7",
			"-Dxcompile",
			"-Dvita",
			"-DVITASDK=" + sdk,
			"-DHXCPP_XLINUX32_CXX=" + sdk + "/bin/arm-vita-eabi-g++",
			"-DHXCPP_XLINUX32_AR=" + sdk + "/bin/arm-vita-eabi-ar",
			"-DHXCPP_XLINUX32_RANLIB=" + sdk + "/bin/arm-vita-eabi-ranlib",
			"-DHXCPP_XLINUX32_STRIP=" + sdk + "/bin/arm-vita-eabi-strip",
			"-DHXCPP_LDFLAGS=-Wl,-q"
		]);

		CPPHelper.rebuild(project, commands);
	}

	public override function run():Void
	{
		var vpkPath = Path.combine(applicationDirectory, project.app.file + ".vpk");

		var consoleIP = project.config.getString("vita.ip");
		if (targetFlags.exists("ip")) consoleIP = targetFlags.get("ip");

		if (consoleIP == null || consoleIP == "")
		{
			Log.warn("Console IP not set. Set vita.ip in your project config or pass -ip <address>.");
		}

		if (!FileSystem.exists(vpkPath))
		{
			Log.error("VPK file not found at: " + vpkPath);
			return;
		}

		var stat = FileSystem.stat(vpkPath);
		var fileSizeMB:Float = Math.round((stat.size / 1024.0 / 1024.0) * 100) / 100;
		final finalIP:String = (consoleIP == null || consoleIP == "") ? "to console" : consoleIP;

		Log.info("Sending: [" + project.app.file + ".vpk] (" + fileSizeMB + " MB) to " + finalIP);

		var curlProgram = "curl";
		var ftpUrl = "ftp://" + consoleIP + ":1337/ux0:/data/" + project.app.file + ".vpk";

		var arguments = ["-T", vpkPath, ftpUrl, "--ftp-pasv"];

		var exitCode = System.runCommand("", curlProgram, arguments);
		if (exitCode != 0)
		{
			Log.error("FTP transfer failed with code " + exitCode);
		}
	}

	public override function update():Void
	{
		AssetHelper.processLibraries(project, targetDirectory);

		var context = generateContext();
		context.OUTPUT_DIR = targetDirectory;

		System.mkdir(targetDirectory);
		System.mkdir(targetDirectory + "/obj");
		System.mkdir(targetDirectory + "/haxe");
		System.mkdir(applicationDirectory);

		var limePath = getLimePath();

		var limeLibDest = Path.combine(targetDirectory, "obj/LIME_LIB/lib");
		System.mkdir(limeLibDest);

		var limeSource = Path.combine(limePath, "ndll/Vita/liblime.a");
		if (FileSystem.exists(limeSource))
		{
			File.copy(limeSource, Path.combine(limeLibDest, "liblime.a"));
		}

		sceDirPath = resolveSceDirPath();
		if (sceDirPath == null) return;

		var assetsDirectory = Path.combine(applicationDirectory, "VITA_ASSETS");
		System.mkdir(assetsDirectory);

		var manifestDest = Path.combine(applicationDirectory, "manifest");
		System.mkdir(manifestDest);
 
		ProjectHelper.recursiveSmartCopyTemplate(project, "haxe", targetDirectory + "/haxe", context);
		ProjectHelper.recursiveSmartCopyTemplate(project, targetType + "/hxml", targetDirectory + "/haxe", context);

		if (targetType == "cpp")
		{
			ProjectHelper.recursiveSmartCopyTemplate(project, "cpp/static", targetDirectory + "/obj", context);
		}

		AssetHelper.createManifests(project, manifestDest);

		for (asset in project.assets)
		{
			var targetPath = asset.targetPath;
			if (targetPath != null && StringTools.startsWith(targetPath, "VITA_ASSETS/"))
			{
				targetPath = targetPath.substr("VITA_ASSETS/".length);
			}

			var rootDirectory = assetsDirectory;
			if (targetPath != null && StringTools.startsWith(targetPath, "manifest/"))
			{
				rootDirectory = manifestDest;
				targetPath = targetPath.substr("manifest/".length);
			}

			var path = Path.combine(rootDirectory, targetPath);
			if (asset.embed != true)
			{
				System.mkdir(Path.directory(path));
				if (asset.type != AssetType.TEMPLATE)
					AssetHelper.copyAssetIfNewer(asset, path);
				else
					AssetHelper.copyAsset(asset, path, context);
			}
		}
	}

	public override function watch():Void
	{
		var hxml = getDisplayHXML();
		var dirs = hxml.getClassPaths(true);
		var command = ProjectHelper.getCurrentCommand();
		System.watch(command, dirs);
	}

	@ignore public override function install():Void {}
	@ignore public override function trace():Void {}
	@ignore public override function uninstall():Void {}
}
