=begin rdoc
===Summary
  * Load source/library files 
  * Assumes $sundat_root is already set, then reads flist_name from Data directory based on that loads the files
  * It loads the file, which are listed in FLIST_NAME file only 
  * Files are loaded based on runlevel in ascending order. 
=== Program Run Mode
  * This program can be run in any one of the following modes
  *   None    -- No file will be loaded and no work done.  Essentially disable loading SunDAT during sketchup startup.
  *   Normal  -- Normal mode of operation , loads all the file in Sketchup
  *   NoSkp   -- Debug mode, program run outside Sketchup. None of the Sketchup related expected to be loaded.  Note, it will not load sketchup.rb instead load 'pp' and <i>require</i> all the rb files.
  *   SkpTest -- Debug mode, Test Sketchup Module and related code. Only Sketchup specific module SkpOp and required library files will be loaded along with SkpOp_test.rb file.   
===Data Structure
  * $sundat_root :  Root directory of the package installation.  Need not be Google plugin directory.  But it should be read / write by the login user.
  * <i>Opt_h</i> Define program level options.  Currently following options are use
  * pkg_fname -- Package related parameters are expected to be present in this file. 
  *              <b>It should present in Google plugin directory when run inside Sketchup</b>
  *              <b>If the program is run outside Sketchup then it should present in the same directory as that of this loader program. </b>
  * flist_name  -- File containing list of files to be loaded, thier run level and the PROG_MODE in which they will be loaded. 
  * ld_flag   -- Flag to decide whether load the files or just list the file names that will be loaded. It is normally true, only for debugging set to false. 
  * prog_mode -- Define program mode, currently supported options: None, Normal, NoSkp, SkpTest
  * build_version -- SunDAT build version
  * major_version -- SunDAT package major version
  * minor_version -- SunDAT package minor version
  * maintenance_version -- SunDAT package maintenance version
  * execlude_dir  -- Comma separated list of directory names ( relative to root directory ). Any file present in these directory will not be loaded into Sketchup.
  * extension     -- Comma separated list of file extension (with dot),  only files with these extension will be loaded into Sketchup
  * <i>Note</i>: 
  * pkg_fname is hard coded in this file.  Rest of the values read from pkg_fname file. 
  * extension directory list maintain list of extension along with dot (ie) '.rb', '.rbs' ... If this parameter is modfied in sundat_pkg.ini file, then do not use dot, it will be added automatically.
  * extension directory entries order is important.  If two file with same base name but differ only in extension present.  Then file whose extension come first in the extension directory is retained and subsequent entries are ignored.
  * extension, exclude_dir list are case <i>insensitive</i>
  * Debug messages are output using 'puts' and UI.messagebox because this file can be run within or outside Sketchup
===ToDO
  * Only when the files which are listed in file_list.ini are loaded, do I have to load all the files in the given directory ?
  * Will there be any problem having default values for Opt_h
=end
## Useful when run this program as stand-alone and also if root directory is not defined then it will take current directory as root
$sundat_root ||= "."  

module SD
  #* Program Options, default value given here.  This will be updated by read_opt method based 
  #* information present in pkg_fname
  Opt_h = {
    'pkg_fname'     => "sundat_pkg.ini",  ## Do not change this name
    'flist_name'    => 'file_list.ini',
    'ld_flag'       =>  true,
    'prog_mode'     => 'normal',
    'build_version' => '000000000000', 
    'major_version' => 1,
    'minor_version'	=> 0,
    'maintenance_version' => 0,
    'exclude_dir'   => %w[Data Doc Drawings Internal Extern Output Web],
    'extension'		=> %w[.rb .rbs .so]  ## Order is important
  }

  #Read initial data from pkg_fname file and updates Opt_h
  def self.read_opt          

    if ( (!$sundat_root.is_a?(String)) || ( !File.directory?($sundat_root)) )
      puts("SunDAT Loader: Root Directory either not set or not a valid directory, hence terminating")
      UI.messagebox("SunDAT Loader: Root Directory either not set or not a valid directory, hence terminating") if (defined?(UI))
      return false
    end  			

    dirname = File.join($sundat_root, "data")
    fname = File.join(dirname, Opt_h['pkg_fname'])
    
     tmp_h={ }
     begin
      IO.foreach(fname) { |line| 
        next if  ( ( line =~ /\A\s*\z/ ) || ( line =~ /\A\s*#/) )
        k,val = line.split('=')
        next if  ( (!k) || (!val) )
        tmp_h[k.strip] =val.strip
      }
     rescue
       puts("SundatLoader: Error in Reading Package Info: #{$!}")	
       UI.messagebox("SundatLoader: Error Reading Package Info: #{$!}")  if (defined?(UI))
       return false
     end#error processing    

     if (tmp_h['ld_flag'])
      tmp_h['ld_flag']= (tmp_h['ld_flag'].downcase=='true') ? true : false
     end

     tmp_h['prog_mode']=tmp_h['prog_mode'].downcase if (tmp_h['prog_mode'])
     %w[major_version minor_version maintenance_version].each { |fd|
       tmp_h[fd] = tmp_h[fd].to_i if ( tmp_h[fd] )
     }
     %w[exclude_dir extension].each { |fd|
      next if (!tmp_h[fd])
      tmp_h[fd]=tmp_h[fd].split(',') 
      tmp_h[fd].collect!{|e| e.strip.downcase} 
     }
     tmp_h['extension'].collect! {|e| '.'+e } if (tmp_h['extension'])
     Opt_h.merge!(tmp_h)
     return true
  end#read_opt

  #* Check Opt_h if any error output in Console and return
  #* Return true if there is no error.
  def self.check_opt
    
    if ( (!Opt_h['extension']) || (Opt_h['extension'].empty?) )
      puts("SunDAT Loader: Warning File extension to be used is empty*****")
      UI.messagebox("SunDAT Loader: Warning File extension to be used is empty*****") if (defined?(UI))
      return false
    end  

    if (!Opt_h['flist_name']) 
      puts("SunDAT Loader: Warning File List name is empty*****")
      UI.messagebox("SunDAT Loader: Warning File List name is empty*****") if (defined?(UI))
      return false
    end

    res = %w[none normal noskp skptest].include?(Opt_h['prog_mode'])
    if (!res)
      puts("SunDAT Loader: Unsupported program mode, hence terminating")
      UI.messagebox("SunDAT Loader: Unsupported program mode, hence terminating") if (defined?(UI))
      return false
    end
    return true

  end#check_opt

  #* Set run level for each of rb file.
  #* It assumes file name is unique across all directories and file name extension is ignored to determine run-level
  #* Read file names listed in flist_name file in Data directory.
  def self.init_run_level()	
    runinfo_h = { }	 
    flist_name = File.join($sundat_root, 'Data', Opt_h['flist_name'])
    begin
      IO.foreach(flist_name) { |ent|
        next if  ( ( ent =~ /\A\s*\z/ ) || ( ent =~ /\A\s*#/) ) ## Ignore empty line or line starts with #
        fname, mode_str = ent.split("=")
        next if( (!fname) || (!mode_str) )
        fname  = fname.strip.downcase
        runinfo_h[fname] ||= { }
        rmode_a = mode_str.split(',')
        level = rmode_a.shift
        runinfo_h[fname]['level'] = level.to_i
        rmode_a.collect! {|m| m.strip.downcase }
        runinfo_h[fname]['rmode'] = rmode_a
      }
    rescue
      puts("SunDAT Loader: Error in Reading File name list: #{$!}")
      UI.messagebox("SunDAT Loader: Error in Reading File name list: #{$!}") if (defined?(UI))
      return nil
    end	
    return runinfo_h
  end#init_run_level	

  #* Return run level of all Model class as hash.  
  #* Note : Model class name is strip & downcase, and then used as key for the hash.
  #* Return : Hash of model class name => run_level
  #* Expected  to be used by OStore to determine loading objects in ascending run_level value
  def self.get_model_list()	
    result_h = Hash.new(10000)	 
    flist_name = File.join($sundat_root, 'Data', Opt_h['flist_name'])
    begin
      IO.foreach(flist_name) { |ent|
        next if  ( ( ent =~ /\A\s*\z/ ) || ( ent =~ /\A\s*#/) ) ## Ignore empty line or line starts with #
        fname, mode_str = ent.split("=")
        next if( (!fname) || (!mode_str) )
        
        fname  = fname.strip.downcase
        next if ( fname !~ /model$/)
        rmode_a = mode_str.split(',')
        result_h[fname] = rmode_a[0].to_i
      }
    rescue
      puts("Sundat Loader:get_model_list Error in Reading File name list: #{$!}")
      UI.messagebox("Sundat Loader:get_model_list Error in Reading File name list: #{$!}") if (defined?(UI))
    end	
    return result_h
  end#get_model_list


  #* Given starting directory,  recursively collect source files in that directory tree
  #* Input: <i>stDir</i>: Starting Directory, if not a directory then return empty array
  #         <i>runinfo_h</i>: Run level details as read from flist_name file
  #Return: Array contain all the source files name ( path starting from stDir )	
  def self.populate_filelist(stDir,runinfo_h)
     if ( !File.directory?(stDir) )
       puts("SunDAT Loader:populate_filelist Starting path is not directory.....")
       UI.messagebox("SunDAT Loader:populate_filelist Starting path is not directory.....") if (defined?(UI))
       return nil 
     end # stDir not directory

     baselist_a = runinfo_h.keys
     res_a = [ ]
     dir_a = [stDir]     
     while (!dir_a.empty?)
       dirEntry = dir_a.pop  
       Dir.foreach(dirEntry) do |fname|		  
         next if ( (fname==".") || (fname=="..") || (Opt_h['exclude_dir'].include?(fname.strip.downcase)) )
         fname = File.join(dirEntry, fname)   
         if  (File.directory?(fname)) 
             (dir_a << fname) 
             next
         end
         ext  = File.extname(fname).strip.downcase
         next if (!Opt_h['extension'].include?(ext))
         base= File.basename(fname, ext).strip.downcase
         next if (!baselist_a.include?(base))
         if ( Opt_h['prog_mode']=='normal')
          res_a << fname 
         else
          res_a << fname if ( runinfo_h[base]['rmode'].include?(Opt_h['prog_mode']) )
         end #pmode  		
      end # Dir.foreach     
    end #while 	
    ## Incase SunDAT V1 is also running, then do not attempt to load singleton library again
    if (defined?(Singleton))
      res_a.delete_if{|fname| fname=~ /singleton/ }
    end
    return res_a
  end #populate_filelist	  

 #* Assume Opt_h is updated.
 #* <i>Output</i>:  List of files to be loaded sorted based on run level.
 def self.get_flist()	

  runinfo_h = init_run_level
  return nil if (!runinfo_h)

  flist_a = populate_filelist($sundat_root,runinfo_h)
  return flist_a if (flist_a.empty?)
  flist_a.sort! do |fn1, fn2| 
    cfn1 = File.basename(fn1,File.extname(fn1)) #Get file name without extension
    cfn2 = File.basename(fn2,File.extname(fn2)) #Get file name without extension 
    runinfo_h[cfn1.strip.downcase]['level'] <=> runinfo_h[cfn2.strip.downcase]['level']
  end				
  
  return flist_a
 end#get_flist

 #* If a same file with different extension present in the given list, it removes the file
 #* whose extension comes later in the Opt_h['extension'] array
 #* Example : if sundat.rb and sundat.rbs both file present and "rb" come before "rbs" in Opt_h['extension'] array then
 #* sundat.rb will be maintained and sundat.rbs will be removed
 #* Input: <i>flist_a</i> -- File name list assume to include full path name
 #* Outut : Updated file list
 def self.remove_dup_files(flist_a)
  return flist_a if ( (!flist_a.is_a?(Array)) || (flist_a.empty?) )
  del_a = []
  (flist_a.length-1).times { |index|
    curr_fname = flist_a[index]
    succ_fname = flist_a[index+1]
    ext1 = File.extname(curr_fname)
    ext2 = File.extname(succ_fname)
    next if (File.basename(curr_fname,ext1).strip.downcase!=File.basename(succ_fname,ext2).strip.downcase)
    curr_ind = Opt_h['extension'].index(File.extname(curr_fname))
    if (!curr_ind)
      puts("remove_dup_files: index of curr file name is nil... Cannot happen")
      next
    end
    succ_ind = Opt_h['extension'].index(File.extname(succ_fname))
    if (!succ_ind)
      puts("remove_dup_files: index of succ file name is nil... Cannot happen")
      next
    end
    fname = (curr_ind>succ_ind) ? curr_fname :  succ_fname
    del_a << fname
  }
  flist_a = flist_a-del_a
  return flist_a
 end#remove_dup_files

 def self.build_model_list(runinfo_h)
   tmp_h = runinfo_h.clone
   #~ puts(tmp_h)
   #~ res_a = flist_a.collect { |str| str if (str=~/Model/) }
   tmp_h.delete_if { |k,val| k !~ /model$/ }
   #~ puts(tmp_h)

   $sundat_model_list = tmp_h
 end

end#SD

res = SD.read_opt
exit(-1) if (!res)

res = SD.check_opt
exit(-2) if (!res)

if (SD::Opt_h['prog_mode']!='none')
  flist_a = SD.get_flist()
  flist_a = SD.remove_dup_files(flist_a)
  exit(-3) if ( (!flist_a) || (flist_a.empty?) )

  version = Sketchup.version.to_i
  if (SD::Opt_h['ld_flag']==true)		 
    case SD::Opt_h['prog_mode']			  
      when 'normal'			  
        require('sketchup.rb')
        if version >= 14
					require ('singleton') 		#ruby 20 singleton
					require ('json/ext')
					require ('fiddle')
					require ('set')
					require ('fileutils')
					require ('tempfile')
					$: << File.join($sundat_root, 'Lib/gems')
                    require ('ffi')
		else
			require(File.join($sundat_root, 'Lib/singleton')) 		#ruby 18 singleton		
		end
        flist_a.each { |fn| 
          puts(fn)
          Sketchup.load(fn) 
        }
      when 'noskp'
        require('pp')
        flist_a.each { |fn| require(fn) }
      when 'skptest'
        require('sketchup.rb')
        Sketchup.send_action("showRubyPanel:")
        UI.messagebox("Start Loading SkpTest")
        flist_a.each { |fn| Sketchup.load(fn) }			 
        fn = File.join($sundat_root, "Extern/Test/SkpOp_Test.rb")
        Sketchup.load(fn)
      else
        puts("SundatLoader: Unknown PROG_MODE: #{SD::Opt_h['prog_mode']}")
        UI.messagebox("SundatLoader: Unknown PROG_MODE: #{SD::Opt_h['prog_mode']}")
    end#prog_mode
  else#ld_flag
    puts("Model List")
    SD.get_model_list.each { |k, val| puts("#{k}:\t#{val}") }
    puts("All File List")
    flist_a.each { |fn| puts(fn) }
    
  end
end#prog_mode
##########End of Load########################################




	
