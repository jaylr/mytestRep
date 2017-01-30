=begin rdoc
 File to store library of functions related to Excel.
 Require utilLogger to log messages
 If included in some other main program, then $excelapp need to be defined in the main program
=end

require 'pp'
require 'win32ole'

=begin
  Given  workbook name, open the file and return a reference.
  wbname: Name of the workbook
  cflag: Create flag, if true and file not exists it will create a new file.
  blk : If block given, reference to the work book is given to the block.  After the block execusion
        the workbook is closed and return nil.
        If block not given, then return reference to the workbook
=end
def wbref(wbname,cflag=false, &blk)

  if (  !(wbname.is_a?(String)) )
    Logger.msg("Err","wbref:wbname is not a valid string", wbname)
    return nil
  end

  $excelapp = WIN32OLE::new('excel.Application')

  if (File.exist?(wbname))
    wb=$excelapp.workbooks.open(wbname)
  elsif(cflag==true)
    wb = $excelapp.workbooks.add
    wb.saveas(wbname)
  else
    Logger.msg("Err" ,"get_wbref:Workbook not exist ", wbname)
    return nil
  end

  if (blk)
    yield(wb)
    wb.close()
    wb=nil
  end
  return(wb)
end
=begin
 Utility function, to check given reference to workbook and worksheet name ( wsname ) ,
 it will check whether given sheet is part of this workbook
 wb : Reference to the workbook
 wsname : Name of the worksheet to be checked
=end
def sheet?(wb,wsname)

  result=false
  return result if (!wb.is_a?(WIN32OLE))

  if (wsname.is_a?(String))
    result=false
    wb.worksheets().each { |ws| break if (result=(ws.name==wsname))  }
  elsif (wsname.is_a?(Integer))
    nosh = wb.worksheets().count
    result = ((wsname>=1) and (wsname<=nosh) )
  end
  return result
end
=begin
 Given ref.to workbook and worksheet name, return a reference to the sheet
 wb : Ref.to workbook
 wsname : Sheet name or number. It can be String or Integer. If Integet it is assumed to be sheet number
 Default : First sheet ( sheet number:1 )
 cflag : Create the sheet if it is not exist.
 Example : wsre("wb"=>wbref, "wsname"=>1, "cflag"=>true)
=end
def wsref(fnarg_h)

  wb=fnarg_h["wb"]
  cflag=fnarg_h["cflag"] || false
  wsname=fnarg_h["wsname"] || 1

  ws=nil
  if (!wb.is_a?(WIN32OLE))
    Logger.msg("Err", "wsref: Workbook reference is nil ....")
    return ws
  end

  if ( (!wsname.is_a?(String)) and (!wsname.is_a?(Integer)))
    Logger.msg("Err", "wsref: Worksheet name neither string nor integer: ", [wb.name, wsname])
    return ws
  end

  if (sheet?(wb,wsname))
    ws = wb.worksheets(wsname)
  elsif(cflag)
    wb.worksheets.add
    (wsname.is_a?(String)) ? wb.worksheets(1).name = wsname : wsname=1
    wb.save()
    ws=wb.worksheets(wsname)
  else
    Logger.msg("Err","get_wsref: Worksheet is not exist ", [wb, wsname])
  end
  return ws
end
=begin
  Utility function to get names of all the sheets in workbook
  wb : Reference to workbook
  Return value : Array contain all the sheet name
=end
def snames(wb)
  return nil if (!wb.is_a?(WIN32OLE))
  result_a = Array.new
  wb.worksheets().each { |ws| result_a << ws.name }
  return result_a
end

=begin
  Read data from worksheet
  ws : Reference to worksheet
  all : True, then read the whole worksheet.
  r1,c1,r2,c2 : Starting row, column and Ending row and column
   If Starting row /column not given 1 is assumed
   If ending row / column not given then takes these value from UsedRange call.
   Between r1 & r2 it will take lower one as starting row , similarly for column
  Returns Array of Array containing worksheet data
  If starting row (r1) is nil then reads all the data in the sheet.
=end
def read_sheet(fnarg_h={})
  if (!fnarg_h['ws'].is_a?(WIN32OLE))
    puts "Err","read_sheet: Worksheet is not WIN32OLE object ",fnarg_h['ws']
    return nil
  end
  ws=fnarg_h['ws']
  all = (fnarg_h['all']==nil) ? false : fnarg_h['all']
  all = true if ( !fnarg_h['r1'] and !fnarg_h['c1'] and !fnarg_h['r2'] and !fnarg_h['c2'] )
  r1=fnarg_h['r1'] || 1
  c1=fnarg_h['c1']  || 1
  r2=fnarg_h['r2']
  c2=fnarg_h['c2']

  res_aofa = Array.new
  begin # Exception processing
    if (all)
      res_aofa = ws.UsedRange.value
    else
      r1=1 if (!r1.is_a?(Integer) or (r1<1) )
      c1=1 if (!c1.is_a?(Integer)or (c1<1) )
      r2=ws.UsedRange.rows.count if (!r2.is_a?(Integer) or (r2<1) )
      c2=ws.UsedRange.columns.count if (!c2.is_a?(Integer) or (c2<1) )
      r1,r2=r2,r1 if ( r2<r1)
      c1,c2=c2,c1 if ( c2<c1)
      res_aofa = ws.range(ws.cells(r1,c1),ws.cells(r2,c2)).value
    end
  rescue
    Logger.msg("Err", "read_sheet: #{ws} reading excel sheet error #{$!}")
  end
  return res_aofa
end


=begin
  Used to write data into worksheet
  ws : Reference to worksheet, where data has to be written
  dataset : Data which is to be written in the sheet. It can be Array of Array (or) Array of Has or Simple Hash
  r1,c1 : Startin row & column . Default value is 1
  append : Whether to append the data in the existing sheet or overwrite
  hdlist : Array contain column name. Used when input dataset is ArrHash, it will output only given column
  hdfmt : Hash contain format string for column.
  Used when input dataset is ArrHash, gives output format for the column
  If dataset is Hash, and hdfmt['value'] is given format string, then use that to format all the values in the Hash
  Note : If the input dataset is Array of Array, hdlist, hdfmt is not used.Inner array should contain objects
  of class for which the function "value" is defined. (eg) I cannot have array of hash.
  It tried to output all data at once, but in case any problem in that then fill up cells one by one.
  For the case of simple Hash, no exception handling done, I assume it will not be very large data.
  If data is present only in cell(1,1) it will be overwritten even if "append" is true
  Return true if write succeed, else false.
=end
def out2sheet(fnarg_h={})

  if ( (!fnarg_h['dataset'].is_a?(Array))  and (!fnarg_h['dataset'].is_a?(Hash)) )
    Logger.msg("Err","out2sheet: Given dataset is neither Array nor hash",fnarg_h['dataset'].class)
    return false
  end

  if (!fnarg_h['ws'].is_a?(WIN32OLE))
    Logger.msg("Err","out2sheet: worksheet reference is not WIN32OLE",fnarg_h['ws'])
    return false
  end

  ws=fnarg_h['ws']
  dataset=fnarg_h['dataset']
  r1 = ( (fnarg_h['r1'].is_a?(Integer)) and (fnarg_h['r1']>0) ) ? fnarg_h['r1'] : 1
  c1= ( (fnarg_h['c1'].is_a?(Integer)) and (fnarg_h['c1']>0) ) ? fnarg_h['c1'] : 1
  hdlist=fnarg_h['hdlist']
  hdfmt=fnarg_h['hdfmt']
  append=(fnarg_h['append']==nil) ? true : fnarg_h['append']

  begin
    if (append==true)
      urange = ws.UsedRange
      nor = urange.rows.count
      noc = urange.columns.count
      rindex = ( ( nor ==1 ) and  (noc==1) ) ? 1 : nor+1
      rindex = r1 if ( rindex<r1 )   ## In append if starting row is given and is higher than current last row, then use that.
    else
      ws.UsedRange.delete
      rindex = r1
    end  # if append
    if ( dataset.is_a?(Array) )  ## Assume dataset is array of array.
      nor= dataset.length
      noc=(dataset[0].length <1 ) ? 1 : dataset[0].length
      begin
        ws.Range(ws.cells(rindex,c1),ws.cells(rindex+nor-1,c1+noc-1)).value=dataset
      rescue
        #There are some issue in writting very big chunk of data, in that case , I write row by row.
        dataset.each { |arr|
          arr.each_with_index { |v, ind|  ws.Cells(rindex,c1+ind).value = v }
        } #each arr
        rindex += 1
      end  #rescue
    elsif ( dataset.is_a?(Hash) )
      nor = dataset.keys.length
      noc = 2
      d_aofa = dataset.select { |key,val| true }
      d_aofa.collect! { |arr| [arr[0],sprintf("#{hdfmt['value']}",arr[1])] } if (hdfmt['value'].is_a?(String))
      d_aofa=d_aofa.unshift(['Description','Value'])
      ws.Range(ws.cells(rindex,c1),ws.cells(rindex+nor-1,c1+noc-1)).value=d_aofa
    end # dataset is Hash
  rescue
    Logger.msg("Err", "out2sheet: #{ws} writing to excel sheet error #{$!}")
    return false
  end
  return true
end  # out2sheet

=begin
Set my standardard format to the given worksheet
ws : Reference to worksheet
=end
def mystdfmt(ws)
  return if  !(ws.is_a?(WIN32OLE))
  ws.rows(1).Font.Bold=true
  ws.UsedRange.Font.size=8
  ws.columns.autofit
end

