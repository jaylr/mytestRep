=begin rdoc
Singleton class to help Logging messages. 
The log messages can be based on different levels ( similar to syslog definition ).  
We can set indent which will be prfixed to all messages 
==Note
* Message Levels:: <tt>[ "Emerg", "Alert", "Crit", "Err", "Warn", "Notice", "Info", "Debug1", "Debug2", "Debug3" ]</tt>
* Messages can be logged onto : <tt>"Std" (standard Error), "File" ( Name to be given ) or "Both" ( file name to be given)</tt>
* If messages are logged to File, then get appended to the file, already existing info is not deleted.
* We can set Level above which ( "Emer" is highest ) messaged will be logged. And also separately set Level above which program will be terminated. See set_maxLevel, set_exLevel
* <b>Assume that level for termination is equal or above logging level</b>.
* To log a message:<tt>msg(level,str,obj)</tt>
* level:: Message level
* str:: Actual message
* obj:: Any object to be output. <i>If we want to output multiple object, we can use array or hash.</i>
* By default this file, sets the log level to 'Info' and output to STDOUT.
* Log file management is not part of this code (eg) Deleting / rotating existing log file etc are not implemented
==Example
===Following code will set various parameters of the logger
* <tt>log=Logger.instance</tt>
* <tt>log.set_indent(__FILE__)</tt> <i>This string will be prefix to all message, Default: nothing </i>
* <tt>log.set_maxLevel("Warn")</tt> <i>Message with severity greater or equal to this will be logged</i>
* <tt>log.set_exLevel("Alert")</tt> <i>Message with severity greater or equal to this will terminate the program</i>
* <tt>log.set_logTo("File", fname)</tt> <i>Can specify whether log to Standard I/O or file</i>
===Following code will be used in various class to log the message
* <tt>log.msg("Err","My Error Message", myobj)</tt> 
* <tt>log.uimsg("Err", "My Error Message", myobj)</tt>  
==ToDo
* Within Sketchup, terminate will not work because Sketchup catches <i>SystemExit</i> exception.
=end
module SD
class Logger
	include Singleton 
	
    #Define logging level
    attr_reader :level_a
	
	#Define logging method
	attr_reader :log_a
	
	#Level above which message will be logged
	attr_reader :mlevel
	
	#Level above which program will terminate
	attr_reader :exlevel
	
	#Where to log
	attr_reader :logTo
	
	#Common indent string to prepend the message
	attr_reader :indent
   
   def initialize
	  
	  #Define logging Levels
	  @level_a = [    
	   "Emerg",   # System is unusable    
	   "Alert",   # Action must be taken immediately  
	   "Crit",    #  critical condition
	   "Err",     # Error condition
	   "Warn",    # Warning condition
	   "Notice", # Normal, but significant condition 
	   "Info",  # Informational message 
	   "Debug1" , # Debug level-1 message
	   "Debug2",  #Debug level-2 message
	   "Debug3" # Debug level-3 message
	   ]  
	 #Define where all we can log the message
	  @log_a = [ "Std", "File", "Both" ]
	  @mlevel = "Err"
	  @exlevel = "Alert"  #Any message of Alert and above will terminate the program
	  @logTo = "Std"
	  @fp = nil
	  @indent =""  #Prefix to be added to all the message 
   end#initialize
  
  #Check given level is valid level defined .
  def valid_level?(lev)
	  return( level_a.include?(lev) )
  end	  
  
  #Used to set the maximum level above which message will be logged ( Default: "Err" )
  def set_maxLevel(nlev = "Err")
    @mlevel = nlev if ( level_a.include?(nlev))    
    @mlevel
  end#set_maxLevel  
  
  #Set the severity level , if any message logged at or above this level will terminate the program
  def set_exLevel(nlev="Alert")
	@exlevel = nlev if ( level_a.include?(nlev))
    @exlevel
  end#se_exLevel	
  

	#Used to set the logging to Stdard Error, File or Both.
	#* <i>Std</i> : Standard Error ( Default )
	#* <i>File</i> : File ( file name to be given )
	#* <i>Both</i> : Both Standard Error and Fil ( file name to be given )  
	#* When this function is called, if anyfile aready open it will be closed.
  def set_logTo(ntype="Std", fname=nil)    
    fclose(@fp) if  (@fp)
    @logTo = ntype if ( log_a.include?(ntype) )   	
    begin	
    @fp = File.new(fname,"a")    if ( ( (logTo=="File") or  (logTo=="Both") ) and (fname.is_a?(String)) )    
	rescue
	  puts("Logger not able to open file: #{fname}\n")
	end
	@logTo = "Std" if (!@fp)
  end#sel_logType  
  

  #This string will be prepend to all the log message
  def set_indent(str)
    @indent=str if ( (str.is_a?(String)) && (!str.empty?) )
  end#set_indent        
  
  def terminate?(level)	
	 #~ exit -1 if ( level_a.index(level)<=level_a.index(@exlevel))	 
	 #~ raise "Runtime Error"  if ( level_a.index(level)<=level_a.index(@exlevel))
  end	
  
  #Returns true if message of this level will be output.
  def can_log?(level)
    return false if ( !level_a.include?(level) )
    return ( level_a.index(level)<=level_a.index(@mlevel) )
  end  
  

   #* Main function to output message.
   #* <tt>level</tt>: What is the level of current message
   #* <tt>str</tt>: Logging message
   #* <tt>obj</tt>: This object will be output using pretty_print (if 'pp' is available)
   #* If both str and obj is nil, then it assumes the first string is message string and output it as  _Info_ message
  def msg(level, str=nil, obj=nil)
	#One string, so assume Info level
	if ( (!str) && (!obj) )
	  str=level
	  level='Info'	  
	end  
	level=level.strip.capitalize
    return if  ( !can_log?(level) ) 
    ct = Time.now().strftime("%d-%b-%Y::%H:%M:%S")    
    if ( (logTo=="Std") or (logTo=="Both") )
      print("#{indent}::")   if ( !indent.empty? )
	  print("#{ct}::#{level}::")
      print("#{str}::")  if (str.is_a?(String))
	  if (obj)
		  (defined?(pretty_inspect)) ? print("#{obj.pretty_inspect}") : print("#{obj.inspect}\n") 
	  else
	    print("\n")           
	  end # if obj	
    end
    if ( (logTo=="File") or (logTo=="Both") )
      printf(@fp, "#{indent}::") if (!indent.empty?)
	  printf(@fp,"#{ct}::#{level}::") 
      printf(@fp, "#{str}::") if (str.is_a?(String)) 
	  if (obj)
		  (defined?(pretty_inspect)) ? printf(@fp,"#{obj.pretty_inspect}") : printf(@fp,"#{obj.inspect}\n") 
	  else
	    printf(@fp,"\n")           
	  end # if obj	      
    end    
    terminate?(level)	
  end#log_msg
  

	#* Method to output message in UI messagebox, when running inside Sketchup.
	#* <tt>level</tt>: What is the level of current message
	#* <tt>str</tt>: Logging message
	#* <tt>obj</tt>: This object will be output as string
	#* If both str and obj is nil, then it assumes the first string is message string and output it as  _Info_ message
  def uimsg(level, str=nil, obj=nil)	  
	  #One string, so assume Info level
	  if ( (!str) && (!obj) )
		str=level
		level='Info'	  
	  end  
	  return if (!can_log?(level)) 	  
	  if (defined?(UI))         
	    mstr = (str) ? str : ""
	    mstr += obj.inspect if (obj)	    
		UI.messagebox(mstr, level)				
	  end
	  terminate?(level)
  end #uimsg	  
  
   #Since ruby doesn't have destructor, I am not sure how to make sure open file is closed
  def close
    @fp.close if (@fp)
  end#close    

  
end ##end class Logger

end 	##module SD

module SD
  Log = Logger.instance
end#module

# Set default value, so that errors can be logged during file loading
 SD::Log.set_maxLevel("Info")
 SD::Log.set_logTo()
