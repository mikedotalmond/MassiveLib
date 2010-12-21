package massive.mlib.cmd;

import massive.neko.haxelib.HaxelibTools;
import massive.neko.io.File;
import massive.haxe.log.Log;

class InstallToHaxelibCommand extends MlibCommand
{
	private var bin:File;
	private var zip:File;
	
	public function new():Void
	{
		super();
		beforeCommands.push(PackageForHaxelibCommand);
	}
	
	override public function initialise():Void
	{
		bin = settings.bin.resolveDirectory(haxelib.name);
		
		var zipPath:String = console.getOption("zip");
		
		if(zipPath == null) zipPath = haxelib.name + ".zip";
		
		zip = bin.resolveFile(zipPath);
		
	}

	override public function execute():Void
	{
		if(!zip.exists)
		{
			error("Zipped haxelib package doesn't exist " + zip);
		}
		
		try
		{	
			HaxelibTools.install(zip);
		}
		catch(e:Dynamic)
		{
			error(e);
		}
	}
	

}