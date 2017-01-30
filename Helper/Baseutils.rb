=begin rdoc
===Summary
  * In this file, SD module define helper routine for URL encoding/decoding.
  * Note : This module also contain singletone instances of Log,CI,Map,Ostore.

  * Code as it is taken from previous version for unescape/escape/round_to methods. 
  * mu_2_inch, inch_2_mu : Dependency with Sketchup default unit is removed ( it is given as parameter ) and minor change in the way code is written.
  * This file extends Numeric class for round off, Metric to Inch conversin and vice versa
  * ruby rounding algorithm given in http://www.ruby-forum.com/topic/84482

===ToDo
  * Why round_to extends Numeric, can't we extend only Float?
=end
module SD 
	#URL-decode a string.  
	def self.unescape(string) 
		#leagacy reasons call decodeURIComponent to avoid changes in many files
		decodeURIComponent string
	end

	def self.decodeURIComponent(string)	
		string.gsub(/((?:%[0-9a-fA-F]{2})+)/u) { [$1.delete('%')].pack('H*') }     
	end
	
  #Given string for URL , escape special characters
	def self.escape(string)
		#leagacy reasons call encodeURIComponent to avoid changes in many files
		encodeURIComponent string
	end

	def self.encodeURIComponent(string)	
		# see encodeURIComponent in Mozilla Developer Network MDN
		# needed for proper UTF-8 handling
		# do NOT use Ruby URI.escape as it does not match decodeURIComponent in Javascript
		# also, convert single quotes also (which is not converted in Javascript encodeURIComponent, 
		# as we need to use it in setHTML where the string is enclosed in single quotes
		# also for above 127 in utf it is a 2 byte sequence. so $1.size is wrong. 
		# you need $1.bytes.size to handle single byte and double byte
		string.gsub(/([^a-zA-Z0-9()\-_.!~*()]+)/u) { '%' + $1.unpack('H2' * $1.bytes.size).join('%').upcase }
	end

	def self.number_with_delimiter number
		number.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
	end 
	
	def self.fiddle_str_to_ptr str, target_encoding
		data = str.encode(target_encoding)
		ptr = Fiddle::Pointer.malloc(data.bytes.length+2)	#additional two bytes 
		ptr[0, data.bytes.length] = data
		ptr
	end

	def self.fiddle_ptr size
		Fiddle::Pointer.malloc(size)	#additional two bytes 
	end
		
	def self.fiddle_ptr_to_str ptr, src_encoding, target_encoding
		ptr.to_s(ptr.size).force_encoding(src_encoding).encode(target_encoding).rstrip
	end
	
	def self.fiddle_ptr_to_int ptr
		ptr.to_i
	end
		
	#* Deep merge two nested hashes
	#* <i>Input</i> : first and second hash
	#* <i>Output</i>: Result values in Hash, deep merged first and second hash
	def self.deep_merge(first,second, avoid_null = true)
		if avoid_null
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
		else
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
		end

		first.merge(second, &merger)
	end#deep_merge

	def self.symbolize_keys data
		case data
		when Hash
			data.inject({}) { | h, (k,v) | 
					if k.is_a?(String)  
						h[k.to_sym] = symbolize_keys(v) 
					else
						h[k] = symbolize_keys(v)
					end
					h 
			}
		when Array
			data.inject([]) { | h, v | h << symbolize_keys(v) }
		else
			data
		end 
	end
	
	#* Deep search a hash in another one
	#* <i>Input</i> : main and sub hash
	#* <i>Output</i>: true if sub hash exists in main hash
	def self.deep_search(main_hash,sub_hash)
		sub_hash.keys.all? do |key|
			main_hash.has_key?(key) && if sub_hash[key].is_a?(Hash)
																	 main_hash[key].is_a?(Hash) && deep_search(main_hash[key], sub_hash[key])
																 else
																	 main_hash[key].to_s == sub_hash[key].to_s
																 end
		end
	end#deep_search

  #* Given parameter values as URL string convert into hash
  #* <i>Input</i> : param_str , string  concatenate name=value by &
  #* <i>Output</i>: Result values in Hash, if a parameter occur more than once, then the vlaues are return as array
  #* *Note* : It assumes each parameter value is prefixed with section name underscore, hence remove that part of the string.
  def self.str2hash(str)
    res_h = { }
    str = unescape(str)
    p_arr = str.split("&")	
    p_arr.each {|s| 
               arr=s.split('=')
               arr[1] = (arr[1]) ? arr[1].strip : arr[1]
                if (arr[0])
                   arr[0] = arr[0].strip.downcase 
                   arr[0].sub!(/^[^_]*_/, '')   ## Remove the section name
                   if res_h.include? arr[0]
                        #If the parameter already exist, then add this value
						res_h[arr[0]] = [res_h[arr[0]], arr[1]].flatten 
					else
						res_h[arr[0]] = arr[1]
                end	 
				end	  					  
               }
    return res_h
  end#str2hash
	  
  #Given hash return as html string.  Need to check is it sufficient  
  def self.hash2html(tmp_h, name="")
	res = ""
	return res if ( (!tmp_h) || (!tmp_h.is_a?(Hash)) || (tmp_h.empty?) )
	tmp_h.each { |k,val|  res += "#{name}[#{k}] = #{val}<br>" }
	return res  
  end#hash2html

  #Given ruby array, return a string of comma separate key=value pair
  def self.array2jsarr(tmp_a)
	res=""
	return res if ( (!tmp_a) || (!tmp_a.is_a?(Array)) || (tmp_a.empty?) )
	tmp_a.each { |k,val| res +="#{k}=#{val.to_s};"}
	res.chop!  ## Remove the final comma
	return res
  end#array2jsarr

  
  #Given ruby hash, return a string of comma separate key=value pair
  def self.hash2jsarr(tmp_h)
	res=""
	return res if ( (!tmp_h) || (!tmp_h.is_a?(Hash)) || (tmp_h.empty?) )
	tmp_h.each { |k,val| res +="#{k}=#{val.to_s};"}
	res.chop!  ## Remove the final comma
	return res
  end#hash2jsarr
  
  #Given ruby hash, return a string of comma separate key=value pair
  def self.hash2jsarr_for_lists(tmp_h)
	res=""
	return res if ( (!tmp_h) || (!tmp_h.is_a?(Hash)) || (tmp_h.empty?) )
	tmp_h.each { |key, val| 
		val = val.collect{ |name| "<option>#{name}</option>"}
		res +="#{key}=#{val.join()};"
	}
	res.chop!  ## Remove the final comma
	return res
  end#hash2jsarr_for_lists	

  #* Given hour & minute convert to floating point number
  #* No error checking done
  def self.hour2float(hour,min)
    res=(hour<0)? hour-min/60.0 : hour+min/60.0
    return res
  end

  #* Given floating point number return hour and min as fixnum array
  #* No error checking done
  def self.float2hour(num)
    hour=num.to_i
    min = ((num-hour).abs*60).round
    if min == 60	#due  to round
		min = 0
		hour += 1
	end
    return [hour, min.to_i]
  end
  
  #Given Longitude value, it finds nearest valid timezone value
  def self.calc_tz(lg)
   tz_a=[-12,-11,-10,-9.5,-9,-8.5,-8,-7,-6,-5,-4.5,-4,-3.5,-3,-2.5,-2,-1,0,1,2,3,3.5,4,4.5,5,5.5,5.75,6,6.5,6.75,7,7.5,8,8.75,9,9.5,9.75,10,10.5,11,11.5,12,12.5,12.75,13,13.75,14,15]
   tmp = (lg/15.0)
   pdiff = 30
   tz_a.each_with_index { |t,i|
     cdiff=tmp-t
     return tz_a[i-1].to_f if (cdiff.abs>pdiff.abs)
     pdiff=cdiff  
   }
   return tz_a.last.to_f
  end#calc_tz

  #* Given start time, end_time and increment ( in numeric ) 
  #* returns array of time object from start to end_time 
  def self.get_time_slots(st_time, e_time, incr)
    res_a = []

    return res_a if ( (!st_time.is_a?(Time)) || (!e_time.is_a?(Time)) || (!incr.is_a?(Numeric)) || (incr<0) )
    return res_a if (st_time>e_time)   
    return [st_time] if (incr==0)

    while (st_time<=e_time)
      res_a << st_time
      st_time += incr
    end
    res_a << e_time if ( (st_time-incr)!=e_time)
    return res_a
  end
  #Compare version numbers
  #<i>Input: v1, v2 version number strings ( form  12.1.0 )
  #<i>Output: Result of comparision
  def self.vcompare(v1,v2)
    a1 = a2 = []  
    a1 = v1.split('.').collect { |s| s.to_i } if (v1.is_a?(String))
    a2 = v2.split('.').collect { |s| s.to_i } if (v2.is_a?(String))	 
    a1<=>a2
  end #vcompare  

  #Given Integer gives hash  
  def self.generate_hash_string(num); sprintf("%06d:%06d", num, rand(1000000)); end

  def self.tz_offset_str(tzoffset)
	hour, min = float2hour(tzoffset)
	tzoffset_str = "UTC#{(hour == 0 && min == 0) ? '&plusmn&#48' : ((hour < 0) ? '-' : '+')}"
	tzoffset_str += "#{(hour.abs < 10) ?  ('0'+(hour.abs).to_s) : (hour.abs)}:#{(min < 10) ? ('0'+min.to_s) : min }" if !(hour == 0 && min == 0)
	return tzoffset_str
  end#tz_offset_str
  
  def self.distance_in_km lat1, long1, lat2, long2
	Math.acos(Math.sin(lat1.degrees)*Math.sin(lat2.degrees) + 
                  Math.cos(lat1.degrees)*Math.cos(lat2.degrees) *
                  Math.cos((long2-long1).degrees)) * 6371
  end

	def self.ellipses p_a
		if p_a.length > 10
			'<span title="'+p_a.join(',')+'">'+p_a.slice(0, 10).join(', ')+'...</span>'
		else
			p_a.join(', ')
		end
	end

	def self.to_json obj
		return "null" unless obj
		json_str = nil
		case obj
		when String
			json_str = %Q( "#{obj}")
		when Numeric, FalseClass, TrueClass
			json_str = %Q( #{obj.to_s}) 
		when Hash
			json_str = %Q({ )
			obj.each { | key, value | 
				json_str += %Q( "#{key}": #{to_json(value)}, 	
					)
			}
			json_str.strip!.chop! if obj.length > 0 #remove last crlf and comma
			json_str += %Q( })
		when Array
			json_str = %Q([ )
			obj.each { | value | 
				json_str += %Q( #{to_json(value)}, 	
					)
			}
			json_str.strip!.chop! if obj.length > 0 #remove last crlf and comma
			json_str += %Q( ])
		else
			raise "Unknown type "+obj.class.to_s
		end
		json_str
	end


	# Save given array of objects to given file
	# @param obj_a [ Array<Object> ] -- Array of objects to be saved to file
	#  For ini file type, it assume each entry is of the form of Hash of Hash
	# @param fname [ String ] -- File Name as String, should be writeable
	# @param ftype [ Symbol ] -- One of [: ini :json, :yaml, :marshal] determine
	#   the output file type
	# @param fmode [ w | a ] -- To open the file in write or append mode
	# @param encoding [String] -- Output file encoding method
	# @todo Need to test various encoding method
	# @return [Boolean] -- True on success else false
  # @note For JSON objects, at the end of each object two return characters are
	# added it helps in reading back.  We read one paragraph at a time during
	# load. This is introduced for pretty printing
	def self.save(obj_a, fname, ftype=:json, fmode="w",encoding=nil )

		#~ return false if (!obj_a.is_a?(Array))
		obj_a = Array(obj_a) if (!obj_a.is_a?(Array))
		obj_a.compact!
		return false if (obj_a.empty?)

		return false if ( (!fname.is_a?(String)) || (fname.empty?) )

		return false if ( !([:ini,:json,:marshal,:yaml].include?(ftype)) )
		fmode.downcase!
		return false if ( (fmode!="w") && (fmode!="a") )
		
		if (ftype==:ini)
			res_h = {}
			if (fmode=="a")
				begin
					tmp_ini=IniFile.load(fname,default: 'default')
					res_h=tmp_ini.to_h
				rescue
					res_h={}
				end
			end#append mode
			
			obj_a.each { |obj|
				return false if ( (!obj.is_a?(Hash)) || (!obj.all? { |k,v| v.is_a?(Hash) }) )
				res_h.merge!(obj)
			}
		  begin
				res_ini = IniFile.new(content: res_h, default: 'default')
				res_ini.save(filename: fname, encoding: encoding)
			rescue
			  SD::Log.msg('Err', 'BaseUtils.save to Inifile failed', $! )
				return false
			end
			return true
		end #ini File

		## Process non ini file type
		fmode = fmode+encoding if (encoding)
		begin
			fp = File.open(fname,fmode)
		rescue
			SD::Log.msg('Err','BaseUtils save file open error',$! )
			return false 
		end
		res = true
		begin
			obj_a.each { |obj|
				case ftype
					when :json
						fp << JSON.pretty_generate(obj,allow_nan: true) << "\n\n"
					when :yaml
						fp << YAML.dump(obj)
					when :marshal
						Marshal.dump(obj,fp)
				end
			}
		rescue
			SD::Log.msg('Err','SunDAT.BaseUtils save to file failed',$!)
			res=false
		ensure
			fp.close
		end

		return res
	end#save

	# Read given file and return array of objects corresponds to the data in the file
	# @param fname [ String ] -- File name , should be readable
	# @param ftype [ Symbol ] -- One of [ :ini, :json, :yaml, :marshal ].  Type 
	#   of data in the file
	# @param encoding [ String ] -- File encoding type
	# @todo Need testing on encoding
	# @return [Array<Objects>] -- Read each entry in the file and convert back 
	#  to corresponding data
	# @note For JSON objects it is assumed objects are written pretty print. Each
	# object is expected to be separated by two return characters.  Based on that
	# read one object replace every return character by space to get correct 
	# JSON object
	def self.load(fname, ftype=:json, encoding=nil )
		return nil if !(File.exist?(fname))
		return nil if (![:ini,:json,:marshal,:yaml].include?(ftype))
		
		fmode="r" 
		fmode=fmode+encoding if (encoding)

		if (ftype==:ini)
			res_h = {}
			begin
				tmp_ini=IniFile.load(fname,default: 'default')
				res_h=tmp_ini.to_h
			rescue
			  SD::Log.msg('Err BaseUtils Load from Inifile failed', $! )
				return nil
			end
			return [res_h]
		end#ini File

    ## Process non ini file type
		begin
			fp = File.open(fname,fmode)
		rescue
			SD::Log.msg('Err','BaseUtils Load file open error', $!)
			return nil
		end

		fp.gets("---") if (ftype==:yaml) ## Ignore the first line

		res_a = []
		begin
			while (!fp.eof)
				case ftype
					when :json
						#~ res_a << JSON.load(str) 
						str = fp.gets('')
						str.gsub!('\n',' ')
						res_a << JSON.parse(str,symbolize_names: true, allow_nan: true)
					when :yaml
						str = fp.gets("---")
						res_a << YAML.load(str)
					when :marshal
						res_a << Marshal.load(fp)
				end#case
			end#while
		rescue
			SD::Log.msg('Err','BaseUtils Load from file failed',$!)
			res_a=nil
		ensure
			fp.close
		end
		return res_a
	end#load

	def self.get_actual_gap(gap_val,unit,t_bbox_val,angle=nil)
		res =0.0
		case unit 
			when 'gap'
				res = gap_val
			when "pitch"
				res = gap_val - t_bbox_val
			when "gcr"
				cos_val = (angle) ? Math.cos(angle.degrees) : 1
				actual_val= t_bbox_val/cos_val
				gcr = gap_val / 100.0
				res = ((actual_val - gcr * t_bbox_val)/gcr).round(2) if (gcr>0)
		end
		## Otherwise , Layout algorithm goes into infinite loop
		res=1 if (res<0) ## Check this with Ravi
		return res
	end#get_actual_gap

end#SD Module

#extends Numeric class to convert to inch based on model info units
class Numeric
  #Helps in consolidating conversion factors in one place.
  @@conv_h = { 	 
  "ft" => 12.0,
  "mm" => 0.0393700787401575,
  "cm" => 2.54,
  "m" => 39.3700787401575
  }  
  #Round to given 'num' positions
  def round_to(num)
    places = 10.0**num
	return ((self.to_f*places).round)/places
  end	
	
  #Convert from Metric Unit to inch.  
  #Input: unit -- Specify in which unit self  is represented.
  #Output: Value in inch
  def mu_2_inch(unit)		
    unit.downcase!
	return ( (@@conv_h.key?(unit)) ? self*@@conv_h[unit] : self)
  end	 
	
  #Convert from inch to Metric Unit
  #Input : unit -- Specify in which unit result expected.
  #Output : Value in given unit.
  def inch_2_mu(unit)
    unit.downcase!
	return ( (@@conv_h.key?(unit)) ? (self*1.0)/@@conv_h[unit] : self)
  end	
end

# To Support Deep copy, merge 
class Hash
	def deep_copy
		self.inject({}) { |res,(k,v)| 
			res[k] = (v.respond_to?(:deep_copy)) ? v.deep_copy : v 
			res
		}
	end

	def deep_merge(second, avoid_null = true)
		if avoid_null
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
		else
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
		end

		self.merge(second, &merger)
	end#deep_merge

	def deep_merge!(second, avoid_null = true)
		if avoid_null
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
		else
			merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
		end

		self.merge!(second, &merger)
	end#deep_merge!

	# Convert nested hash all keys to symbol.  Taken from Stockoverflow
	def self.transform_keys_to_symbols(value)
    return value if not value.is_a?(Hash)
    hash = value.inject({}) { |memo,(k,v)| 
			memo[k.to_sym] = Hash.transform_keys_to_symbols(v)
			memo 
		}
    return hash
  end#transform_keys_to_symbols

end

# To Support Deep copy 
class Array
	def deep_copy
		self.collect { |v| (v.respond_to?(:deep_copy)) ? v.deep_copy : v }
	end
end

module Enumerable

    def sum
      self.inject(0){|accum, i| accum + i }
    end

    def mean
      self.sum/self.length.to_f
    end

    def sample_variance
      m = self.mean
      sum = self.inject(0){|accum, i| accum +(i-m)**2 }
      sum/(self.length - 1).to_f
    end

    def std_dev
      return Math.sqrt(self.sample_variance)
    end
    
	def mode
		sort_by {|i| grep(i).length }.last
	end

end 
		
module UI
	class << self
		alias_method :old_msgbox, :messagebox
		#SD::Log.Uimsg will pass the level as second parameter, 
		#where as other UI.msgbox will pass the type of box or will not have it.
		#The level is been processed in case of 'Cli' mode to display 
		#appropriate kind of messages //Error or Info type
		def messagebox(str,option = MB_OK)					
			if !MainController.instance.is_cli
				option = MB_OK if option.is_a?(String)
				return old_msgbox(str,option)	
			else	
				term_dialog = CliView.instance.get_terminal_dialog
				if option.is_a?(String) && option == "Err"
					MainController.instance.mark_and_show_err_msg(SD::escape(str))							
				else
					js_command = "showMessage('#{SD::escape(str)}')"
					term_dialog.execute_script(js_command)
				end
				return 6 #6 is MB_YES in a yes/no prompt box
			end
		end
				
		def breather
			dialog = UI::WebDialog.new "Breather dialog", false, false, 0, 0, 0, 0, false
			timer_id = UI.start_timer(1, false) {
				UI.stop_timer timer_id
				dialog.close
			}
			dialog.show_modal
		end

		
		# need both the fiber and the resume in a timer code 
		# reason is if fiber is constructed in root context and not timer context 
		# and we get out of this proc and resume in timer, it gives a fiber error "fiber called across stack rewinding"
		# however if both are in a timer context it works well
		
		def long_running
			raise "No code block given" unless block_given?
			in_process = false
			timer_id = UI.start_timer(1, false) {
				if !in_process
					in_process = true
					UI.stop_timer timer_id
					yield
					in_process = false
				end
			}
		end
		
		LR_LEVELS = 3
		
		def lr_init
			if @lr_state && @lr_state[0] != :init
				UI.messagebox("Previous long running process did not complete.\n"+
									  "It is recommended to wait a few seconds and then click OK to continue.")
			end
			@block_a = Array.new(LR_LEVELS) { Array.new }
			@lr_state = Array.new(LR_LEVELS, :init)
			@interval_a = Array.new(LR_LEVELS, 1)	
			@interval_a[LR_LEVELS-1] = 0.5	#for last level make it faster
		end
		
		def lr_l1_section &blk
			lr_section 0, false, blk
		end 

		def lr_l1_section_repeat &blk
			lr_section 0, true, blk
		end 

		def lr_l2_section &blk
			lr_section 1, false, blk
		end 

		def lr_l2_section_repeat &blk
			lr_section 1, true, blk
		end 
		
		def lr_l3_section &blk
			lr_section 2, false, blk
		end 
		
		def lr_l3_section_repeat &blk
			lr_section 2, true, blk
		end 
		
		def lr_section_break
			@break_repeat_section = true
		end
		
		def lr_abort
			@block_a.each { | level_a | level_a.clear }	##so that lr winds back
		end
		
		### timer code for easy development of top down long running code into blocks of parallel level based code
		### see shadow controller and layout controller 
		def lr_section level, repeatable, blk
			@block_a[level] << [blk, repeatable]
			if @lr_state[level] == :init
				@lr_state[level] = :started
				#~ puts "level #{level} timer"
				in_process = false
				timer_id = UI.start_timer(@interval_a[level], true) {
					if !in_process 
						in_process = true
						case @lr_state[level]
						when :started, :section_completed
							if @block_a[level].length > 0
								proc, repeatable = @block_a[level].shift
								@break_repeat_section = false if repeatable
								@lr_state[level] = :section_started
								proc.call
								if repeatable && !@break_repeat_section
									##insert at beginning so that next bloc is this. do not use <<
									@block_a[level].unshift [proc, repeatable]
								end
								##if last level or in prev levels there are no next level blocks defined
								@lr_state[level] = :section_completed if level == (LR_LEVELS-1) || @block_a[level+1].length == 0	##no l2 
							else
								#~ puts "*** finally stop level #{level} **"
								UI.stop_timer timer_id
								@lr_state[level] = :init
								##stop 
								@lr_state[level-1] = :section_completed	if level > 0
							end
						end
						in_process = false
					end
				}
			end
		end
						
	end	#end self << class
end	#end UI modile

#Length object does not support json conversion, hence the definition!
class Length
	def to_json(options = {})
		self.to_f.to_s
	end
end
