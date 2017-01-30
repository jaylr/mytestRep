=begin rdoc 
 * Main program expected to load at the end.  
 * SunDAT class initialize config object, logger , load GCL library, and then initialize Sketchup 
 * If above steps succeeds calls MainView add_menu to initialize Plugin Menu item.
 * If SkpOp is not initialized then loads prototype components . Note : If SkpOp is initialized then 
 * prototype component will be loaded in init_skp
===ToDo
 * Need to finalize what are all steps to be done by the main program
=end
class SunDAT
    include Singleton
	
	#Valid is set to true only when config and log objects are available.
    attr_reader :valid
	
	#Main controller
	attr_reader :mcontroller
	
	#Main View
	attr_reader :mview
	
	#* Initialize config object ( read sundat.ini), if override_ini file present merge that to basic config object.
	#* Initialize logger object.	
	#* Load map.ini file if present.
	def initialize
		@valid = true		
		@mview = defined?(MainView) ? MainView.instance : nil
		@mcontroller = defined?(MainController) ? MainController.instance : nil 		
		
		####### I need to check all required class is present based on that set this flag
		if ( (!SD::Log) || (!SD::CI) ||(!SD::Map)|| (!SD::Ostore) )	      
    		@valid = false
            puts("Required Singleton class(es) missing ")
            puts("Log: #{SD::Log}, CI: #{SD::CI}, Map:  #{SD::Map}, OStore: #{SD::Ostore}")
			return
		end # All Models available		
		
		## We will check controller and MainView is valid only when running inside sketchup.  Is this assumption right ??????
		if ( (defined?(SkpOp)) && ( (!@mview) || (!@mcontroller)) )
		  @valid = false
          puts("MainView and/or MainController instance not available")
		  return
		end  
       

         
		#Set log level, logging file etc.  
		SD::Log.set_maxLevel(SD::CI[:debug_level]) if  (SD::CI[:debug_level] )		
		SD::Log.set_exLevel(SD::CI[:terminate_level]) if (SD::CI[:terminate_level])
        logfn = SD::CI.output(SD::CI[:debug_file])		
		SD::Log.set_logTo("Both", logfn) if (logfn)
	
		#If mapmodel is defined then load the map file		
		if (SD::CI[:map_fname])
		  fname = SD::CI.data(SD::CI[:map_fname])
		  @valid = SD::Map.load(fname)		 
		end  
		
		@valid = check_license

	end #initialize
	
	#Load GCL library 
	def init_gcomp
		return if (!valid)
		res = (defined?(GCompModel)) ? (GCompModel.load_comp) :  false
        return res     		
	  end#init_gcomp
	  	
	#* Temp method for testing purpose, currently unused
	#* Output object name and their valid status from ostore.
	def out_ostore(str)
      SD::Log.msg("Info", "Ostore Entry")
      cat_a = (str=='non_gc') ? SD::Ostore.category_names_non_gc : SD::Ostore.category_names
      cat_a.each { |cat|
        SD::Ostore.each_entry(cat) {|cat,name,comp| 
          SD::Log.msg('Info', "Category, name, valid", [cat,name,comp.param_h['version']]) 
      }
     }
	end#check_ostore  
	
	#* Temp method for testing reading /writing config info
	def config_showAndsave
	  SD::CI.show
	  if (SD::CI.output)
	    fname = SD::CI.output('junk.ini')
	    SD::CI.save(fname)
	 end 	  
	end#check_config  

	def is_internal_user?
		!@is_external
	end

  def check_local_activation
    license_ret_code = nil

    isActivated = Fiddle::Function.new(
          @ta_dll['IsActivated'],
          [Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT
        )	

    wchar_ptr = SD.fiddle_str_to_ptr @guid, 'UTF-16LE'
    license_ret_code = isActivated.call(wchar_ptr)
    ret_code = (license_ret_code == 0)
    ret_code
  end

	def install_extensions
		plugins = [ 	
					{ :name=>'Align Camera', :version=>'1.0', :file => 'AlignCamera-v1-1.rbz' }, 
					{ :name => 'Layer Isolate', :version => '1.0', :file => 'LayerIsolate-v1-0.rbz' } 
					]
		installed_extensions = Sketchup.extensions.keys
		plugins.each { | p | 
			if installed_extensions.include?(p[:name])
				#check version
				ext = Sketchup.extensions[p[:name]]
				if ext.version != p[:version]
					install_extension p[:name], p[:file]
				else
					unless ext.loaded?
						ext.check	#load it
					end
				end
			
			else
				##install it
				install_extension p[:name], p[:file]
			end
		}
	end
	
	def install_extension name, filename
		path = $sundat_root+'/Plugins/'+filename
		begin
			Sketchup.install_from_archive(path)
			ext = Sketchup.extensions[name]
			if ext && !ext.loaded?
				ext.check
			end
		rescue Interrupt
		rescue Exception => error
			UI.messagebox "Error during unzip: "+error.message
		end		
	end
	
  def is_external_user
    field = 'isexternal'
    getFeatureValue = Fiddle::Function.new(
        @ta_dll['GetFeatureValue'],
        [Fiddle::TYPE_VOIDP,  Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
        Fiddle::TYPE_INT
      )
    key_ptr = SD.fiddle_str_to_ptr field, 'UTF-16LE'
    response_ptr = SD.fiddle_ptr 256
    size = 128
    field_value = getFeatureValue.call(key_ptr, response_ptr, size)
    val = '1' # Default external user
    if field_value == 0
      val = SD.fiddle_ptr_to_str response_ptr, 'UTF-16LE', 'UTF-8'
    end
    val == '1'
  end
  
  def is_genuine_check_needed? 
    last_time_elapsed = true
    last_checked_time=Sketchup.read_default("SunDAT","last_checked_time")      
    current_time = Time.now.to_i
    if !last_checked_time.nil?
      #If there is week difference check online. Or check offline
      seconds_per_week = 60*60*24*7
      time_diff = current_time - last_checked_time
      if (time_diff < seconds_per_week)
        last_time_elapsed = false
      end
    end
    last_time_elapsed
  end

	def check_license
		require "fiddle"
		#encode UTF8 string as littel endian to match windows unicode string or windows wchar format
		@guid = '797fa2c054da16e6006852.61018614'
		@dll_path = File.join($sundat_root, "License", "TurboActivate-x64.dll")
    

		ret_code = File.exists?(@dll_path)
		unless ret_code
			UI.messagebox("License file not found") 
		end
		@ta_dll = Fiddle.dlopen(@dll_path)
		license_ret_code = nil

		#Check for local activation
		local_activated = check_local_activation
		unless local_activated
			UI.messagebox("SunDAT license local check error") 
			return false
		end

		is_genuine_check = true
		@is_external = is_external_user
		unless @is_external
			is_genuine_check = is_genuine_check_needed?
		end
		return true unless is_genuine_check
		isGenuine = Fiddle::Function.new(
			@ta_dll['IsGenuine'],
			[Fiddle::TYPE_VOIDP],
			Fiddle::TYPE_INT
		)
		wchar_ptr = SD.fiddle_str_to_ptr @guid, 'UTF-16LE'
		license_ret_code = isGenuine.call(wchar_ptr)
		ret_code = (license_ret_code == 0)	#activated properly
		if ret_code
			#Write only for valid check
			Sketchup.write_default("SunDAT","last_checked_time", Time.now.to_i)
		else
			SKETCHUP_CONSOLE.show
			puts "Invalid license check..."
			puts "Activation error #{license_ret_code}" if license_ret_code
			if license_ret_code == 1
				UI.messagebox("Key deactivated")
			elsif license_ret_code == 3
				UI.messagebox("Key Revoked/Inactive")
			elsif license_ret_code == 4
				UI.messagebox("SunDAT extension requires internet to initialize")
			end
		end
		ret_code
	end #Check_License
	
end #class SunDAT	

def is_external_user
	@is_external
end

### Start of Main Program    
def start_sundat
	sdat = SunDAT.instance

	if (!sdat.valid)
		puts("Error....SunDAT initialization failed, Program terminates....")
		return 
	end	
	SD::Log.msg("Debug1", "SunDAT instance created")	

	sdat.install_extensions
	## Load GCL components
	if (!sdat.init_gcomp)
		SD::Log.msg("Alert", "SunDAT GCL library not loaded, Program terminates...") 
		return 
	end

	#Log current version information
  SD::Log.msg('Info', "Root Directory", SD::CI[:root_dir])
	SD::Log.msg('Info', "Major Version", SD::CI[:major_version])
	SD::Log.msg('Info', "Minor Version", SD::CI[:minor_version])
	SD::Log.msg('Info', "Maintenance Version", SD::CI[:maintenance_version])	
	SD::Log.msg('Debug1', 'ostore length ', SD::Ostore.length)	

	#Initialize Sketchup module and initialized Plugin menu item
	if (defined?(SkpOp))
      skp=SkpModel.instance		
      if (skp.valid)			
				SD::Log.msg('Debug1', "SkpModel initialized")
      end
      #adding external gems to load path	
      # $: << File.join($sundat_root, 'Lib/gems')

    else ## No SkpOp 
      #~ sdat.config_showAndsave
      sdat.out_ostore('non_gc')
      #~ pp SD::Ostore['TrTableModel','_Default_TR']
      #~ pp SD::Ostore['TrTableModel','TR']
      puts("GCompVersion : #{GCompModel.version}")
      ver=SD::Ostore['GCompModel','GCLib']['version']
      puts("From OStore: #{ver}")

    end
######## Main loop initialized	

end

return_value = start_sundat
