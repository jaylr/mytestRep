=begin rdoc
===Summary
  * This extends SD Module, define helper routines for Polygon related operation
  * Assusmes Baseutils.rb is already loaded, because it needs round_to method for Numeric class
  * Most of the Clipper related operation done here
  * Note : 'getxy' method define here, convert given 3D array or Geom::Point3d to 2D array
  * Its inverse method xy2point require Sketchup to find z-axis value for the given x,y value 
  * hence that is defined in SkpOp.
  * get_union method uses getxy to convert given input to 2D array, but it is not used in
  * merge_polygon, poly_contain?, point_intersection methods because it may impact performance.
  * I assume calling methods will convert to 2D array before calling these methods

===ToDo
  * Why round_to extends Numeric, can't we extend only Float?
=end
module SD 
	#* Implement compare operator for floating point numbers
	#* If epsilon is nil then return n1 <=> n2
	#* If epsilon is given then the numbers are consider equal if thir difference 
	#* is less than or equal to epsilon
	#* Return -1,0,1 similar to <=> operator
	def self.compare_numbers(n1,n2,epsilon=nil)
		return n1 <=> n2 if (!epsilon)
		return 0 if ( (n1-n2).abs <= epsilon )
		return n1 <=> n2
	end

  #* Given two points compare them
  #* Input: <i>p1, p2</i> -- Two points ( one dimensional array of 3 entries )
  #*        <i>first_dim</i> -- Which dimension to be used to compare first.
	#* It has to be 'x' or 'y'.  Based on this dimension compare first then
	#* compare the second dimension and then compare 3rd dimension. 
	#* Default : 'x'
  #* Output: One of -1,0,1
  #* Mainly used by wiring algorithm to sort tables/modules 
	#* The floating point numbers are consider same if they are within
	#* epsilon difference ( if epsilon is given )
	def self.compare_points(p1,p2,first_dim='x',epsilon=nil)
	 first_dim.downcase!
	 if (first_dim=='x')
		res = compare_numbers(p1[0],p2[0],epsilon)
		return res if (res!=0)
		res = compare_numbers(p1[1],p2[1],epsilon)
		return res if (res!=0)
		return compare_numbers(p1[2],p2[2])
	 else ## Compare with y-dimension first
		res = compare_numbers(p1[1],p2[1],epsilon)
		return res if (res!=0)
		res = compare_numbers(p1[0],p2[0],epsilon)
		return res if (res!=0)
		return compare_numbers(p1[2],p2[2])
	 end 
	end#compare_points


	#* Sort the array of pointsin snaking pattern (ie) First axis sorted in given order, 
	#* second axis is sorted alternate order. 
	#* @param pt_a [Array<Object>] Array of Array , each innter array is a point
	#* @param first_dim [Symbol] First dimension either :x or :y
	#* @param sdir_a [Array<symbol>] Sorting direction for that axis. First entry 
	#*  for x-cordinates, then y,z .  Allowed values :asc or :des 
	#* @param epsilon_a [Array<Float>]  For each axis what is the epsilon value 
	#*  to consider when comparing.  This contain epsilon values for x,y,z axis
	#*  in that order
	#* @return [Array<Object>] Sorted Array of points.  It sorts input array in-place
	#*  This can sort x followed by y or y followed by x only, 3rd dimension not used
	def sort_points_snake(pt_a,first_dim=:x, sdir_a=[:asc,:asc], epsilon_a=[])
		# Based on first_dim , set order of sorting
		dim_a=(first_dim == :x) ? [0,1] : [1,0]

		tmp_h = pt_a.group_by { |ele| pt_a[dim_a[0]] }

		k_a=tmp_h.keys.sort
		ep=epsilon_a[dim_a[0]]
		# Points within this band is consider as belong same row/col 
		if (ep)
			cur_val=k_a.last
			(k_a.length-2).downto(0) { |i|
				if ( ((cur_val-k_a[i]).abs) <= ep)
					tmp_h[k_a[i]] += tmp_h[k_a[i+1]]
					tmp_h.delete(k_a[i+1])
					k_a[i+1]=nil
				else
					cur_val=k_a[i]
				end
			}
			k_a.compact!
		end

		k_a.reverse! if (sdir_a[dim_a[0]] == :des)

		flag = (sdir_a[dim_a[1]] == :asc) ? 1 : -2 
		ep=epsilon_a[dim_a[1]]
		k_a.each { |k|
			tmp_h[k].sort! { |p1,p2| 
				if ( (!ep) || ((p1[dim_a[1]]-p2[dim_a[1]]).abs > ep ) )
					(flag>0) ? p1[dim_a[1]] <=> p2[dim_a[1]] : p2[dim_a[1]] <=> p1[dim_a[1]]
				else
					0
				end
			}
			flag = ~flag
		}
		res_h={}
		k_a.each { |k| res_h[k]=tmp_h[k] }
		return res_h
	end#sort_points_snake

  #* Given a 3D point array return 2D point array
  #* Input : <i>point_a</i> -- Array ( can be points or numbers)
  #*         <i>tr</i> -- Transformation, Default nil.  
  #* Outut : 2D Array.  Each entry rounded to 2 decimal places.
  #* <i>Note</i> : <i>tr</i> will work only within Sketchup
  def self.getxy(point_a,tr=nil)
    res_a = point_a.map { |pt| 
       tmp_a = (tr) ? (tr*pt).to_a : pt.to_a
       [tmp_a[0], tmp_a[1] ]
     }
    return res_a
  end#getxy

  #* Given point or 3D array, returns 2D array
  #* Both x & y are rounded to 2 decimal places.
  #~ def self.getxy(point_a)
    #~ res_a = point_a.map { |pt| 
       #~ [pt[0].round_to(2), pt[1].round_to(2) ]
     #~ }
    #~ return res_a
  #~ end#getxy
  
  #* Given point array, it returns the entry for which x-axis value is minimum
  #* If x-value is same then compare y-value
  #* Input: <i>pt_a</i> : Array of points either two or three dimension
  #* Output : Point, where x-axis is minimum
  def self.get_min_point(pt_a)
    return nil if (!pt_a.is_a?(Array))
    res= pt_a.min { |a,b|
      (a[1] == b[1]) ? (a[0] <=> b[0]) : (a[1] <=> b[1])
    }
    return res
  end#get_min_point

  #* Given point array, it returns the entry for which x-axis value is maximum
  #* If x-value is same then compare y-value
  #* Input: <i>pt_a</i> : Array of points either two or three dimension
  #* Output : Point, where x-axis is maximum
  def self.get_max_point(pt_a)
    return nil if (!pt_a.is_a?(Array))
    res= pt_a.max { |a,b|
      (a[1] == b[1]) ? (a[0] <=> b[0]) : (a[1] <=> b[1])
    }
    return res
  end#get_max_point

  #* Given point array, it returns the point formed having lowest x & y values 
  #* Input: <i>pt_a</i> : Array of points either two or three dimension
  #* Output : 2D Point, where x is the lowest x and y is the lowest y occur in the array
  def self.get_min_xy_point(pt_a)
    return nil if (!pt_a.is_a?(Array))
    p1 = pt_a.min { |a,b| a[0]<=>b[0] }
    p2 = pt_a.min { |a,b| a[1]<=>b[1] }
    res = [ p1[0], p2[1] ]  
    return res
  end#get_min_point

  #* Given point array, it returns the point formed having highest x & y values 
  #* Input: <i>pt_a</i> : Array of points either two or three dimension
  #* Output : 2D Point, where x is the highest x and y is the highest y occur in the array
  def self.get_max_xy_point(pt_a)
    return nil if (!pt_a.is_a?(Array))
    p1 = pt_a.max { |a,b| a[0]<=>b[0] }
    p2 = pt_a.max { |a,b| a[1]<=>b[1] }
    res = [ p1[0], p2[1] ]  
    return res
  end#get_max_point

  #* Check given two points are equal in all dimension ( x,y,z coordinates)
  #* Input: <i>pt1, pt2</i> -- Point Arrays ( can be Array of Geom::Point3d also)
  #*        <i>rflag -- Whether to round the numeric values
  #* Output : true or false. (ie) Both pt1 & pt2 of same length and pt1[i]==pt2[i] for all i
  def self.point_equal?(pt1,pt2,rflag=true)
    return false if ( (!pt1) || (!pt2) )

    #If given input is Point3d, then convert to array
    pt1_a = Array(pt1)
    pt2_a = Array(pt2)

    return false if (pt1_a.length!=pt2_a.length)

    pt1_a.length.times { |i|
      if (rflag)
        pt1v = (pt1_a[i].is_a?(Numeric)) ? pt1_a[i].round_to(2) : pt1_a[i]
        pt2v = (pt2_a[i].is_a?(Numeric)) ? pt2_a[i].round_to(2) : pt2_a[i]
        return false if (pt1v!=pt2v) 
      else
        return false if (pt1_a[i]!=pt2_a[i])
      end
    }
    return true
  end#point_equal?

  #* Check given two points are equal in x & y coordinates
  #* Input: <i>pt1, pt2</i> -- Point Arrays [x,y,z] ( can be Array of Geom::Point3d also )
  #*        <i>rflag -- Whether to round the numeric values
  #* Output : true or false. (ie) pt1[0]==pt2[0] and pt1[1]==pt2[1]
  #* <i>Note</i> : Input arrays can have length greater than 2, but his method will check first two entry of the both array
  def self.point2d_equal?(pt1, pt2,rflag=true)

    # Round to 2 decimal only if the values are Numeric
    if (rflag)
      pt1v0 = (pt1[0].is_a?(Numeric)) ? pt1[0].round_to(2) : pt1[0]
      pt1v1 = (pt1[1].is_a?(Numeric)) ? pt1[1].round_to(2) : pt1[1]
      pt2v0 = (pt2[0].is_a?(Numeric)) ? pt2[0].round_to(2) : pt2[0]
      pt2v1 = (pt2[1].is_a?(Numeric)) ? pt2[1].round_to(2) : pt2[1]
      return ( (pt1v0==pt2v0) && (pt1v1==pt2v1) )
    else
      return ( (pt1[0]==pt2[0]) && (pt1[1]==pt2[1]) )
    end
  end#point2d_equal?

  #* Compare two points using integer comparision. 
  #* Since clipper is working only with integer numbers, this method is introduced
  #* Input: <i>pt1, pt2</i> -- Two dimensional points.
  #* Output: true if both x & y coordinates of the given points equal in integer part.  
  #* <i>Note</i> : It is not doing any roundoff, just truncates.
  def self.clipper_point_equal?(pt1,pt2)
    return ( (pt1[0].to_i==pt2[0].to_i) && (pt1[1].to_i==pt2[1].to_i) )
  end

  #* Check whether given polygon has got duplicate points check only for two dimensions ( x,y coordinates )
  #* Input : <i>arr</i> -- Array of points
  #*         <i>rflag</i> -- Whether to round of Numeric values
  #* Output : true or false
  def self.has2d_duplicate?(arr,rflag=true)
    tmp_arr = Array(arr)
    if (!rflag)
      return tmp_arr.uniq.length != tmp_arr.length
    end

    len=tmp_arr.length
    (len-1).times { |i|
        return true if ( tmp_arr[i+1..len].find{ |pt2| point2d_equal?(tmp_arr[i],pt2,rflag) } )
    }
    return false
  end#had2d_duplicate?

  #* Check given array got any duplicate points
  #* If rflag is true, then uses point_equal? method to compare two points, so that coordinates are rounded to two decimal places
  def self.has_duplicate?(arr,rflag=true)
    tmp_arr = Array(arr)
    if (!rflag)
      return tmp_arr.uniq.length != tmp_arr.length
    end

    len=tmp_arr.length
    (len-1).times { |i|
        return true if ( tmp_arr[i+1..len].find{ |pt2| point_equal?(tmp_arr[i],pt2,rflag) } )
    }
    return false
  end

  #* Internal method, given two polygon arrays, check both are same
  #* It uses given blk to check two points are equal.
  #* Input: <i>pts1_a, pts2_a</i> -- Polygon arrays (ie) Array of points
  #*        <i>blk</i> -- Block takes two points and return result of comparision as true or false
  #* output : Both polygons are same.  
  #* <i>Note</i> : Points of first and second polygon can be clockwise or counter-clockwise, or one clockwise another counterclockwise as long as same order is maintained it will return true
  #* If either one of the input is not array of array then return false
  #* <b> If any one of the input array contain duplicate entry ( points) then this will return wrong result </b>
  #* Algorithm :
  #* Take first entry of pts1_a , search for this entry in second array. Note this start_index in second array
  #* Take second entry of pts1_a, check whether it is next or previous entry to start_index in second array, from that determine the direction of second array entries.
  #* check all other entries of first array in second array in same direction
  def self.poly_check(pts1_a, pts2_a, &blk)

   #Both Input has to be Array
   #~ return false if ( (!pts1_a.is_a?(Array)) || (!pts2_a.is_a?(Array)) )
   pts1_a = Array(pts1_a)
   pts2_a = Array(pts2_a)

   #Both polygon should of same length
   return false if (pts1_a.length!=pts2_a.length)

   #Both input should be array of array
   return false if ( ( pts1_a.any?{ |a| !a.is_a?(Array)} ) || ( pts2_a.any?{ |a| !a.is_a?(Array)} ) )


   #If both polygon contain only empty arrays (points) then return true
   return true if ( !(pts1_a.find { |a| a.any? }) && !(pts2_a.find { |a| a.any? }) )


   #~ st_index = pts2_a.find_index {|pt2| yield(pts1_a[0], pt2) }
   ### Since Ruby1.8.6 does not support find_index
   st_index = nil
   pts2_a.each_with_index {|pt2,i| 
     res=yield(pts1_a[0], pt2) 
     if (res)
       st_index=i
       break
     end
   }
   return false if (!st_index)


   len = pts1_a.length
   dir = nil
   if (yield(pts2_a[(st_index+1)%len],pts1_a[1])) #points are in ascending order
    dir = 'forward'
    st_index += 1
   elsif (yield(pts2_a[st_index-1],pts1_a[1])) #points are in descending order
    dir = 'backward' 
    st_index -= 1
   else
     return false
   end

   2.upto(len-1) { |i| 
     j = (dir=='forward') ? (st_index+=1) % len : st_index-=1
     return false if (!yield(pts2_a[j], pts1_a[i]))
   }
   return true
  end#poly_check

  #* Check two polygons are equal, check points equality only for 2-Dimension.
  #* Input: <i>poly1, poly2</i> -- Polygons (ie) Array of points
  #*        <i>rflag</i> -- Whether to round off Numeric entries in the array
  #* Output: true or false
  #* <i>Note</i> : Points of first and second polygon can be clockwise or counter-clockwise, or one clockwise another counterclockwise as long as same order is maintained it will return true
  #* If either one of the input is not array of array then return false
  #* <b> If any one of the input array contain duplicate entry ( points) then this will return wrong result </b>
  def self.poly2d_same?(poly1, poly2,rflag=true)
    return poly_check(poly1,poly2) { |p1,p2| point2d_equal?(p1,p2,rflag) }
  end#poly2d_same?

  #* Check two polygons are equal, check points equal in all dimension
  #* Input: <i>poly1, poly2</i> -- Polygons (ie) Array of points
  #*        <i>rflag</i> -- Whether to round off Numeric entries in the array
  #* Output: true or false
  #* <i>Note</i> : Points of first and second polygon can be clockwise or counter-clockwise, or one clockwise another counterclockwise as long as same order is maintained it will return true
  #* If either one of the input is not array of array then return false
  #* All the entries in each of the input array should be of same length
  #* <b> If any one of the input array contain duplicate entry ( points) then this will return wrong result </b>
  def self.poly_same?(poly1,poly2, rflag=true)
    return poly_check(poly1,poly2) {  |p1, p2| point_equal?(p1,p2,rflag) }
  end#poly_same?

  #* Checks given polygons are equal.  It uses clipper_point_equal to do comparision.  Hence only integer part of the coordinates only compared.
  #* Input: <i>poly1, poly2</i> -- Polygons (ie) Array of points
  #*        <i>rflag</i> -- Whether to round off Numeric entries in the array
  #* Output: true or false
  #* <i>Note</i> : Points of first and second polygon can be clockwise or counter-clockwise, or one clockwise another counterclockwise as long as same order is maintained it will return true
  #* If either one of the input is not array of array then return false
  #* <b> If any one of the input array contain duplicate entry ( points) then this will return wrong result </b>
  def self.clipper_poly_same?(poly1, poly2)
    return poly_check(poly1,poly2) { |pt1,pt2| clipper_point_equal?(pt1,pt2) }
  end#clipper_poly_same?

  #* Given two polygons as array of array [ [x1,y1,z1], [x2,y2,z2],...]
  #* Compare both contain same number of array ( or points )
  #* and in each entry check equality of x & y coordinates.
  #* Input : pts1_a, pts2_a : Points array
  #*       : rflag -- Flag whether to round of numbers before compare
  #* Output : true or false
  #* <i>Note</i> : It expects both polygon points are in same direction, but poly_same points can be in either direction
  def self.poly2d_equal?(pts1_a,pts2_a,rflag=true)
    return false if (pts1_a.length!=pts2_a.length)
    0.upto(pts1_a.length-1){ |i| return false if ( !point2d_equal?(pts1_a[i], pts2_a[i],rflag) ) }
    return true
  end#poly2d_equal?

  #* Given two polygons as array of array [ [x1,y1,z1], [x2,y2,z2],....]
  #* Create polygons as shown [pts1_a[0], pts2_a[0], pts1_a[1], pts2_a[1] ]
  #* pair of points taken as (0,1), (1,2).. (n-1,0) 
  #* If both arrays of not of equal length then it will return empty array
  def self.poly_connect(pts1_a, pts2_a)
    res_a = []
    return res_a if ( pts1_a.length!=pts2_a.length)
    len = pts1_a.length
    0.upto(len-1) { |i|
      j= (i+1) % len
      res_a << [pts1_a[i], pts2_a[i], pts2_a[j], pts1_a[j]]
    }
    return res_a
  end

  #* Given a polygon and translation vector it moves the polygon
  #* Input : <i>pts_a</i> -- Array of points, can be 2D or 3D
  #*         <i>tr_a</i>  -- Translation vector, can be 2D or 3D
  #* Output : Array of points translated by the given amount
  def self.poly_move(pts_a, tr_a)
    res_a = pts_a.collect { |pt|
      npt = []
      pt.each_with_index { |val,i| npt<<val+tr_a[i] }
      npt
    }
    return res_a
  end#poly_move

  #* Find union of given Polygon array.
  #* Same logic as used in ShadowOffsetTool, but code slightly modified
  #* Input: <i>poly_a</i> -- Array of polygons (ie) each entry is either 2D or 3D Array.
  #* Output : Array of 2D-polygons
  def self.get_union(poly_a)
    res_poly_a = [[]]
    return res_poly_a if ( (!poly_a.is_a?(Array)) || (poly_a.length==0) )
    return [getxy(poly_a[0])] if (poly_a.length==1)  

    #Input has more than 1 entry
    c = Clipper::Clipper.new
    c.add_subject_polygon(getxy(poly_a[0]))
    c.add_clip_polygon(getxy(poly_a[1]))
    res_poly_a = c.union
    c.clear!

    2.upto(poly_a.length-1) { |i|
      c.add_subject_poly_polygon(res_poly_a)
      c.add_clip_polygon(getxy(poly_a[i]))
      res_poly_a = c.union
      c.clear!
    }
    return res_poly_a
  end#get_union

  #* Input: Each entry is array of array of polygon  
  #* [ [ poly11, poly12, poly13... ], [poly21, poly22, poly23,...]...]
  #* Each poly = [ point1,point2,point3...]
  #* Each point = [ x,y,z ]
  #* Output : Array of Polygon  [ [p11,p12,p13..], [p21,p22,p23...]...]
  def self.merge_polygons(poly_poly_a)
    res_poly_a=[[]]
    return res_poly_a if ( (!poly_poly_a.is_a?(Array)) || (poly_poly_a.empty?))
    return(poly_poly_a[0]) if (poly_poly_a.length==1)

    c = Clipper::Clipper.new
    c.add_subject_poly_polygon(poly_poly_a[0])
    c.add_clip_poly_polygon(poly_poly_a[1])
    res_poly_a = c.union
    c.clear!
    2.upto(poly_poly_a.length-1) { |i|
      c.add_subject_poly_polygon(res_poly_a)
      c.add_clip_poly_polygon(poly_poly_a[i])
      res_poly_a = c.union
      c.clear!
      if(res_poly_a.length == 0)	#possible error
        SD::Log.uimsg('Err',"SkpOp.merge polygons, Something wrong. Possible duplicate objects in same position. Check layout.")
      end
    }
    return res_poly_a
  end#merge_polygon

  #* Given two polygon it returns if first polygon contain the second polygon
  #* Input: <i>poly1, poly2</i> -- 2D-Points array.
  #* Output : true if poly1 contain poly2
  def self.poly_contain?(poly1,poly2)
    c=Clipper::Clipper.new
    c.clear!
    c.add_subject_polygon(poly1)
    c.add_clip_polygon(poly2)
    res_a = c.intersection
    c.clear!
    return((res_a.length==1) && (clipper_poly_same?(poly2,res_a[0])))
  end#poly_contain?

  #* Given set of polygons and current polygon,
  #* checks whether current polygon intersect any one of the polygon in the set
  #* Input: <i>poly_a</i> -- Array of polygon, (ie) Each entry is a Polygon( 2D-Point array)
  #*             [ poly1, poly2...] => [ [p11,p12,p13..], [p21,p22,p23,..]...] , each 'p' is an array of length-2
  #*        <i>poly2</i> -- Polygon of interest .  Array of 2D-Point. [p1,p2,...]
  #* Output: Return true if poly2 touches any one of the polygon in poly_a.            
  def self.poly_intersect?(poly_a, poly2)
    c=Clipper::Clipper.new
    c.clear!
    c.add_subject_poly_polygon(poly_a)
    c.add_clip_polygon(poly2)
    res_a = c.intersection
    c.clear!
    return(!res_a.empty?) 
  end#poly_intersect?

  #* Given set of polygons and clipping polygon
  #* Clips all polygons in the set to clipping polygon's boundary
  #* Input: <i>base_poly_a</i> -- Array of Polygons
  #*  (ie) [ [poly11, poly2...], [poly21,poly22,...], ... ]
  #*        <i>cpoly</i> -- Polygon, Array of Points [p1,p2,..]
  #* Output: Array of Polygons
  def self.clip_to_poly(base_poly_a,cpoly)

    return([[]]) if ( (!base_poly_a.is_a?(Array)) || (!cpoly.is_a?(Array)) )
    c = Clipper::Clipper.new
    c.clear!
    c.add_subject_poly_polygon(base_poly_a)
    c.add_clip_polygon(cpoly)
    result_poly_a=c.intersection
    c.clear!
    return result_poly_a
  end#clip_to_poly

  #* Used to output a array of points (ie) a polygon.
  #* <i>Input</i>
  #*    pts -- Array of points. Each point is an array, either 2D or 3D 
  #*    label -- Any string
  #*  Output Array of points in pretty format with given label.
  #*  (eg) [ [1.23, 3.45, 6.78], [...],...]
  def self.out_point_array(label,pts)
    printf(" #{label}:") if ( (label.is_a?(String)) && (!label.empty?) )
    printf(" [")
      pts.each { |a| 
        if (a[2])
          printf("[%5.2f,%5.2f,%5.2f], ", a[0],a[1],a[2]) 
        else
          printf("[%5.2f,%5.2f], ", a[0],a[1]) 
        end
      }
    printf("]\n")
  end#out_point_array

  #* Used to output a array of polygons.
  #* <i>Input</i>
  #*    poly_a -- Array of polygons. Each entry is array of points. Each point can be either 2D or 3D 
  #*    label -- Any string
  #*  Output Array of points in pretty format with given label.
  #*  (eg) 
  #    [
  #      [ [1.23, 3.45, 6.78], [...],...],
  #      [ [...], [...],...],
  #      ....
  #    ]
  def self.out_poly_array(label,poly_a)
    printf(" #{label}:") if ( (label.is_a?(String)) && (!label.empty?) )
    printf(" [\n")
    poly_a.each { |pt_a|  out_point_array("",pt_a) }
    printf(" ]\n")
  end#out_point_array

end#SD Module
