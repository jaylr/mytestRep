#* This file contain classes to support file operation specifically to 
#* read/write result information. All these files assumes data is written
#* as Marshal.dump. We can write data multiple time.  Each entry can be
#* accessed separately.
#* Contain following 3 classes
#* BaseResultFile -- Base class for other two classes
#* ResultFile -- Read / Write result information with Disk file
#* TempResultFile -- Read / Write result information with Temp.File
#*                   This file will get deleted when the program exit
#*

#* Base class to read/write result information in File
#* This class assumes File pointer is opened by the derived class
#* During initialization if 'fpath' is not given by default
#* file path is assumed to be SD::CI.output directory
#* All the method in this class assume file pointer open/close
#* is handled by derived class
#* ResultFile open file to access Disk file and TempResultFile
#* do the same for TempFile
class BaseResultFile

	# File pointer
	attr_reader :fp
	# File Name with fullpath 
	attr_reader :fname
	# Full path of the file
	attr_reader :fpath

	# @param fname [String] File name without path 
	# @param fpath [String] Full path of the File
	# @note If path is not given then SD::CI.output directory is taken
	def initialize(fname,fpath=nil)
		@fname=nil
		@fp=nil
		@fpath = SD::CI.output if (!fpath)
	end#initialize

	# Close file.  
	def close; @fp.close if (@fp); @fp=nil; end

	# Read result at given index. Starts from 1. 
	# If index is 1, then 0th entry in the file is read
	# @param index [Integer] Read data at the given index
	# @return [Object] Marshal.load data at the given index
	def read_result(index=nil)
		index=0 if (!index)
		res=nil
		begin
			0.upto(index-1) { |i| Marshal.load(@fp) }
			res=Marshal.load(@fp)
		rescue
			SD::Log.msg('Err',
			 "BaseResultFile.read_result file reading error for index: #{index}", $!)
			res=nil
		end
		return res
	end#read_result

	# Marshal.dump the given data into file
	# @param append [Boolean] Not used in this classes.  Used by derived classes
	# @return [Boolean] true on success
	def write_result(data,append=true)
		res=false
		begin
			Marshal.dump(data,@fp)
			res=true
		rescue
			SD::Log.msg('Err', "BaseResultFile.write_result file writing error", $!)
			res=false
		end
		return res
	end#write_result

	# Copy result data from one ResultFile object to another
	# Used by LayoutModel to copy data from Temp file to final output file
	# @param rf_obj [ResultFile] Input Data file
	# @param ind_a [Array<Integer>] Copy data at the given indeces only to output 
	# @result [Boolean] True on Success 
	def copy_result(rf_obj,ind_a=[],append=false)
		res=true
		begin
			ind_a.each { |i| 
				data=rf_obj.read_result(i) 
				if (!data)
					SD::Log.uimsg('Err', 
					  "BaseResultFile.copy_result reading data from file failed, index: #{i}", $!)
					res=false
					next
				end
				Marshal.dump(data,@fp)
			}
		rescue
			SD::Log.msg('Err', "BaseResultFile.copy_result file copy error", $!)
			res=false
		end
		return res
	end#copy_result

	# Used to iterate over the results
	# @yield [Object] Data read from file
	# @return [Object] Return self
	def each
		return self if (!@fp)
		yield Marshal.load(@fp) while (!@fp.eof)
		return self 
	end#each


	# Find the number of entries in the file.
	# @note reads the line one by one .  So costly operation
	def length
		return 0 if (!@fp)
		res=0
		while (!@fp.eof)
			Marshal.load(@fp)
			res +=1
		end
		return res
	end#length

	# Check file exists
	def exist; File.exist?(@fname); end
	alias exist? exist

end#BaseResultFile

# Used to store result in Disk file
class ResultFile < BaseResultFile

	# Setup both path and full filename. Calls base class to determine path
	# If fpath is not given then SD::CI.output directory is taken
	# @param fname [String] Fill name without path
	# @param fpath [String] File full path 
	def initialize(fname,fpath=nil)
		super
		@fname=File.join(@fpath,fname)
	end#initialize

	# Used to copy one file to another. Donot read file entries
	# uses OS call to copy file.  This method used by LayoutModel
	# to copy result file from previous version naming convention to current
	# naming convention
	# @param prev_fname [String] Filename (without path) to copy data from
	# @param cur_fname [String] File (without path) to copy data to
	# @param fpath [String] File path for both input an output file
	# @return Result of copy opeation
	def self.copy(prev_fname,cur_fname,fpath=nil)
		res=true
		fpath = SD::CI.output if (!fpath)
	  prev_fname = File.join(fpath,prev_fname)
		cur_fname = File.join(fpath, cur_fname)
		begin
			FileUtils.cp(prev_fname,cur_fname) if (File.exist?(prev_fname))
		rescue
			SD::Log.msg('Err',"ResultFile file copy failed", $!)
			res=false
		end
		return res
	end#copy

	# File open. Helper method.
	# @param fmode [String] File open mode
	def open(fmode)
		res=true
		begin
			@fp = File.open(@fname,fmode) 
		rescue
			SD::Log.msg('Err',"ResultFile file open failed", $!)
			@fp=nil
			res=false
		end
		return res
	end#open

	# Read result at given index. Start from 1
	# @index [Integer] Read result at this index
	# @return [Object] Data read from file.
	def read_result(index=nil)
		return nil if (!open('r'))
		res = super
		close
		return res
	end#result

	# Write given data to file
	# @param append [Boolean] If true append to file else overwrite existing data
	# @return [String] Result of file write
	def write_result(data,append=true)
		fmode = (append) ? 'w+' : 'w'
		return false if (!open(fmode))
		res=super
		close
		return res
	end#write_result

	# Copy result data from one ResultFile object to another
	# Used by LayoutModel to copy data from Temp file to final output file
	# @param rf_obj [ResultFile] Input Data file
	# @param ind_a [Array<Integer>] Copy data at the given indeces only to output 
	# @param append [Boolean] If true, data to append to output file, else overwrite
	# @result [Boolean] True on Success 
	def copy_result(rf_obj,ind_a=[],append=false)
		return false if ( (!rf_obj) || (!ind_a) )
		fmode = (append) ? 'w+' : 'w'
		return false if (!open(fmode))
		res=super
		close
		return res
	end#copy_result

	# Used to iterate over the results
	# @yield [Object] Data read from file
	# @return [Object] Return self
	def each 
		return nil if (!open('r'))
		res=super
		close
		return res
	end#each

	# Find the number of entries in the file.
	# @note reads the line one by one .  So costly operation
	def length
		return 0 if (!open('r'))
		res=super
		close
		return res
	end

	# Delete the file
	def delete
		@fp.close if (@fp)
		res=true
		begin
			File.delete(@fname) if (File.exist?(@fname))
		rescue
			SD::Log.msg('Err', "ResultFile.delete error in deleting file", "#{$!}")
			res= false
		end
		return res
	end#delete
	

end#ResultFile

# Manipulate Tempfile.  This temp file won't close
# during program working, but get deleted end of the program
# @note This class don't implement copy ( method to copy file as it is)
#		since it doesn't make sense to copy temp file
class TempResultFile < BaseResultFile

	# Open temp file
	# @param  fname [String] used as prefix to Tempfile
	#  It uses fname as prefix and _tmp for end of the file name
	# @param fpath [String] File path used to read/write Temp file
	def initialize(fname,fpath=nil)
		super
		begin
			@fp=Tempfile.new([fname,'_tmp'],@fpath) 
		rescue
			SD::Log.msg('Err',"TempResultFile.Initialize failed, #{fname}", $!)
			@fp=nil
		end
		@fname=@fp.path
	end#initialize

  
	# Read result at given index. Start from 1
	# @index [Integer] Read result at this index
	# @return [Object] Data read from file.
	def read_result(index=nil)
		return nil if (!@fp)
		@fp.rewind
		super
	end#read_result

	# Write given data to file
	# @param append [Boolean] If true append to file else overwrite existing data
	# @return [String] Result of file write
	def write_result(data,append=true)
		return false if (!@fp)
		@fp.rewind if (!append)
		super
	end#write_result

	# Copy result data from one ResultFile object to another
	# Used by LayoutModel to copy data from Temp file to final output file
	# @param rf_obj [ResultFile] Input Data file
	# @param ind_a [Array<Integer>] Copy data at the given indeces only to output 
	# @param append [Boolean] If true, data to append to output file, else overwrite
	# @result [Boolean] True on Success 
	def copy_result(rf_obj,ind_a=[],append=false)
		return false if ( (!rf_obj) || (!ind_a) || (!@fp))
		@fp.rewind if (!append)
		super
	end#copy_result

	# Used to iterate over the results
	# @yield [Object] Data read from file
	# @return [Object] Return self
	def each 
		return nil if (!@fp)
		@fp.rewind
		super
	end#each

	# Find the number of entries in the file.
	# @note reads the line one by one .  So costly operation
	def length
		return 0 if (!@fp)
		@fp.rewind
		super
	end

	# Delete file
	def delete; close; end

end#TempResultFile
