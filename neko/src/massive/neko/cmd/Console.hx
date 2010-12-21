package massive.neko.cmd;

import massive.neko.io.File;
import massive.neko.io.FileError;
import massive.neko.io.FileSys;
import neko.FileSystem;
import neko.vm.Thread;
import neko.Lib;
import massive.haxe.log.Log;
import neko.io.Process;

/**
*  Command Line Interface
*  
*  API for managing command line options passed to a neko program.
*  
*  Currently supports the following usages:
*  
*  foo bar				sequential arguments 'foo' and 'bar'
*  -foo					non-sequential options (value will be set to 'true')
*  -foo bar				non-sequential options with custom value
*  
*  For haxelib applications it automatically detects the final argument as a file path
*  and updates the working directory ('dir') accordingly 
*  
*  */
class Console
{
	public var systemArgs(get_systemArgs, null):Array<String>;
	
	/** directory where tool was called from (defaults to haxelib lib path) **/
	public var originalDir(default, null):File;

	/** 
	* Directory where haxelib was called from (for haxelib tools only)
	* Defaults to same as originalDir if not run from haxelib
	**/
	
	public var dir(default, null):File;
	
	/** Hash of all command line arguments starting with a dash (e.g. '-foo bar') **/
	public var options:Hash<String>;


	/** Array of all command line arguments not starting with a dash **/
	public var args:Array<String>;

	/** current index with the args array. Used to ensure that a single argument is only returned once **/
	private var currentArg:Int;
	
	/** 
	* Neko files launched via haxelib (e.g. haxelib run mcmd) include the original calling directory as the last argument
	* By default Console finds and sets this as the current directory when isHaxelib = true
	*  */
	private var isHaxelib:Bool;
	
	public function new(?isHaxelib:Bool = true):Void
	{
		this.isHaxelib = isHaxelib;
		originalDir = File.current;
		
		systemArgs = neko.Sys.args().concat([]);
		Log.debug("systemArgs: " + systemArgs);
		
		init();
	}
	
	private function init():Void
	{
		dir = null;
		args = [];
		options = new Hash();
		currentArg = 0;
		
		parseArguments(systemArgs);
		
		if(dir != null)
		{
			FileSys.setCwd(dir.nativePath);
		}
	}
	
	
	private function get_systemArgs():Array<String>
	{
		return systemArgs.concat([]);
	}
	/**
	*  Re-initialisises all arguments from the original neko.Sys.args()
	**/
	public function flush(?isHaxelib:Bool = true):Void
	{
		this.isHaxelib = isHaxelib;
		init();
	}

	/**
	*  retrieve a command line option in the format -foo [bar]
	*  @param key - the name of the option (without the "-" infront of it)
	*  @param ?promptMsg - an optional prompt message to request value from user if option doesn't exist
	*  @return the value of the option or null. An option without a value argument will return 'true'
	*  */
	public function getOption(key:String, ?promptMsg:String=null):String
	{
		var str:String = null;
		
		if(key.indexOf("-") == 0) key = key.substr(1);
		
		if(options.exists(key))
		{
			str = options.get(key);
		}
		else if (promptMsg!= null)
		{
			str = prompt(promptMsg);
		}
		return str;
	}
	
	/**
	* Override the existing value of an option (or create a new one)
	* Useful when chaining together commands and pushing new option args to the console.
	* @param key - the name of the option
	* @param value - the value of the key
	*/
	public function setOption(key:String, value:Dynamic):Void
	{
		if(key.indexOf("-") == 0) key = key.substr(1);
		options.set(key, Std.string(value));
	}

	/**
	*  returns the next command line arg that isnt an option
	*  @param promptMsg - optional prompt message to request a value from the user if no arguments remain.
	*  @return the next argument or null (in no arguments remaining)
	*  */
	
	public function getNextArg(?promptMsg:String=null):String
	{
		var str:String = null;
		
		if(args.length > currentArg)
		{
			str = args[currentArg++];
		}
		else if(promptMsg != null)
		{
			str = prompt(promptMsg);
		}
		
		return str;
	}

	/**
	*  prompt the user for input from the command line
	*  @param promptMsg the message to display as a prompt
	*  @param rpad an optional padding value before the ':' character
	*  */
	public function prompt(promptMsg:String, rpad:Int=0):String
	{
		neko.Lib.print(StringTools.rpad(promptMsg + " ", " ", rpad) + ": ");
		var str:String = neko.io.File.stdin().readLine();
		if(str.length == 0)
		{
			str = null;
		}
	
		return str;
	}	

	
	/**
	*  Strips the dir path from the end of the args array.
	*  This is the path from where haxelib was called
	*  */
	private function getCurrentDirectoryPathFromArgs(a:Array<String>):File
	{
		var path:String = a[a.length-1];
		var file:File = null;
	
		try
		{
			file = File.create(path);
		}
		catch(e:FileError)
		{
			//Log.info(e + "\n" + a);
		}
	
		if(file != null)
		{
			Log.debug(file.toDebugString());
		}
		
		
		if(file != null && file.exists && file.isDirectory)
		{
			a.pop();
			return file;
		}
		return null;
	}
	
	
	/**
	*  seperates command line arguments into options (e.g. '-foo') and args (e.g. 'bar' )
	*  An option can have a single optional argument (e.g. -foo blah), otherwise the value will be a string 'true'
	*  
	*  */
	private function parseArguments(a:Array<String>):Void
	{
		args = [];
		
		if(a == null || a.length == 0)
		{
			dir = originalDir;
			return;
		}
		
		if(isHaxelib)
		{
			dir = getCurrentDirectoryPathFromArgs(a);
		}
		
		if(dir == null)
		{
			dir = originalDir;
		}
		
		options = new Hash();
	
		
		var option:String = null;
		var optionArgs:String = "";
		for(arg in a)
		{
			if(option != null)
			{
				if(arg.charAt(0) == "-")
				{
					//this is another -x flag so set existing -x to true
					if(optionArgs == "")
					{
						options.set(option, "true");
					}
					else
					{
						if(optionArgs.indexOf("'") == 0 && optionArgs.lastIndexOf("'") == optionArgs.length-1)
						{
							optionArgs = optionArgs.substr(1, optionArgs.length-2);
						}
						options.set(option, optionArgs);
					}
					option = arg.substr(1);
					optionArgs = "";
				}
				else
				{	
					if(optionArgs.length > 0) optionArgs += " ";
					optionArgs += arg;
					
				}				
			}
			else if(arg.charAt(0) == "-")
			{
				option = arg.substr(1);
				optionArgs = "";
			}
			else
			{
				args.push(arg);
			}
		}

		if(option != null)
		{
			if(optionArgs == "")
			{
				options.set(option, "true");
			}
			else
			{
				if(optionArgs.indexOf("'") == 0 && optionArgs.lastIndexOf("'") == optionArgs.length-1)
				{
					optionArgs = optionArgs.substr(1, optionArgs.length-2);
				}
				options.set(option, optionArgs);
			}
		}
	}
}