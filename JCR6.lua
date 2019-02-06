--[[
  JCR6.lua
  
  version: 19.02.06
  Copyright (C) 2019 Jeroen P. Broks
  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.
  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:
  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
]]

-- Main

JCR_Crash = true -- When set to true a crash will occur when an error pops up
JCR_Caught = {}  -- Contains all errors caught (only used when JCR_Crash is false)
JCR_Chat = false -- When set true some debug info could be displayed


local function chat(a)
     if JCR_Chat then print(("DEBUG: %s"):format(a)) end
end

local function chats(f,...)
      chat(f:format(...))
end      

function JCR_error(a)
     if JCR_Crash then error(a) end
     print("JCR6 Error: "..a)
     JCR_Caught[#JCR_Caught+1] = a
end

function JCR_assert(c,a)
     if not c then JCR_error(a) end
     return c
end     


-- A few globals converted to locals for speed
local fopen = io.open
local sprintf = string.format


function printf(f,...)
    io.write ( f:format(...) )
end    



--[[ These are integer readers.
     A way to read and write integers, written by Tom N Harris.
  ]] 

-- Read an integer in LSB order.
local
function stringtonumber(str)
  local function _b2n(exp, num, digit, ...)
    if not digit then return num end
    return _b2n(exp*256, num + digit*exp, ...)
  end
  return _b2n(256, string.byte(str, 1, -1))
end

-- Read an integer in MSB order.
local
function stringtonumber2(str)
  local function _b2n(num, digit, ...)
    if not digit then return num end
    return _b2n(num*256 + digit, ...)
  end
  return _b2n(0, string.byte(str, 1, -1))
end

-- Write an integer in LSB order using width bytes.
local
function numbertobytes(num, width)
  local function _n2b(width, num, rem)
    rem = rem * 256
    if width == 0 then return rem end
    return rem, _n2b(width-1, math.modf(num/256))
  end
  return string.char(_n2b(width-1, math.modf(num/256)))
end

-- Write an integer in MSB order using width bytes.
local
function numbertobytes2(num, width)
  local function _n2b(t, width, num, rem)
    if width == 0 then return table.concat(t) end
    table.insert(t, 1, string.char(rem * 256))
    return _n2b(t, width-1, math.modf(num/256))
  end
  return _n2b({}, width, math.modf(num/256))
end

--[[ End of code by Tom N Harris ]]

--[[
   Lua does not support classes, but this will help me to 'fake' a class
]]   

-- Raw file read functions
-- The 2nd local definition is because locals are said to be faster than globals, but I *do* want the functions to be callable by scripts calling this library!
function RAW_ReadInt(stream)
     local s = stream:read(4)
     for i=1,4 do io.write(s.byte(i).."/") end print(" read => "..stringtonumber(s)) -- debug
     return stringtonumber(s)
end local RAW_ReadInt = RAW_ReadInt

function RAW_ReadString(stream,length)
     length = length or RAW_ReadInt(stream)
     return stream:read(length)
end local RAW_ReadString = RAW_ReadString

function RAW_Read(stream)
    local s = stream:read(1)
    return s:byte(s,1,1)
end local RAW_Read = RAW_Read
local RAW_ReadByte = RAW_Read

function RAW_ReadBoolean(stream)
    return RAW_Read(stream)>0
end local RAW_ReadBoolean = RAW_ReadBoolean    


       

-- "classes"
local class_JCRDir = {
      Entries = "@newtable",
      Comments = "@newtable",
      MainConfig = "@newtable",
      CFGbool = "@newtable",
      CFGstr = "@newtable",
      CFGint = "@newtable",
      Vars = "@newtable",
      FAToffset = 0,
      FATsize = 0,
      FATcsize = 0,
      FATstorage = "Store",
      
      Get = function(self,Entry) 
      -- Will be used to read an entry
      end,
      
      Patch = function(self,PatchJCR)
      -- Will be usd to patch to JCR
      end,
      
      EntryList = function(self)
        local l = {}
        local i = 0
        for k,_ in pairs(self.Entries) do l[#l+1]=k end
        table.sort(l)
        return function()
            i = i + 1
            return l[i]
        end
     end       
      
}

local compression_drivers = {}
local dir_drivers = {}

function JCR_RegisterCompression(name,driver)
    assert(type(name)=="string","Driver name MUST be a string!")
    assert(type(driver)=="table","Driver must be a table!")
    assert(type(driver.compress)=="function","Function expected for compress field, but I received "..type(driver.compress))
    assert(type(driver.expand  )=="function","Function expected for expand   field, but I received "..type(driver.expand))
    compression_drivers[name] = driver
end

function JCR_RegisterDir(driver)
    assert(type(driver)=="table",("Driver must be a table and not be a %s!"):format(type(driver)))
    assert(type(driver.recognize)=='function',("Driver recognize must be a function and not be a %s"):format(type(driver.recognize)))
    assert(type(driver.dir)=='function',("Driver dir must be a function and not be a %s!"):format(type(driver.dir)))
    assert(type(driver.name)=='string',("Driver name must be a string and not be a %s!"):format(type(driver.name)))
    dir_drivers[#dir_drivers+1]=driver
end

local function FAKESTORE(a) return a,#a end -- Since no compression is done is store, just return what we got.
JCR_RegisterCompression("Store",{ compress=FAKESTORE, expand=FAKESTORE })    

local function jnew(class)
    local ret = {}
    for k,v in pairs(class) do
        if v=="@newtable" then ret[k]={} else ret[k]=v end
    end
    if ret.constructor then ret.constructor() end
    return ret
end

function newJCRDir() return jnew(class_JCRDir) end


local class_textbuff = {
    str = "",
    pos = 0,
    size = function(self) return #self.str end,
    eof = function(self) return pos>=#self.str end,
    Raw = function(self,s)
           local p = self.pos + 1
           local r = self.str:sub(p,self.pos+s)
           self.pos = self.pos + s
           return r
          end,
    ReadByte = function(self) return(self:Raw(1):byte()) end,           
    ReadInt = function(self)
          local b = Raw(4)
          return stringtonumber(b)
         end,       
    ReadString = function(self,size) 
          size = size or self:ReadInt()
          return Raw(size)
         end 
}

-- Read string as file
function bytes_NewReader(string)
    local ret = jnew(class_textbuff)
end    


local JCR6_DirDriver = {

          name = "JCR6",          
          
          recognize = function(file)
             local bt = fopen(file,"rb"); if not bt then return nil end
             local head = RAW_ReadString(bt,5)
             -- print("head = "..head)
             bt:close()
             return head=="JCR6"..string.char(26)
          end,
          
          dir = function(file)
             -- The code in this function was originally written in the Go programming language and manually converted to Lua. 
             -- As Go is a rather odd programming language, I hope this translation will work out well :P
             -- JCR6Error = ""
             local ret = newJCRDir() -- := TJCR6Dir{} //make(map[string]TJCR6Entry), make(map[string]string), make(map[string]int32), make(map[string]bool), make(map[string]string), 0, 0, 0, "Store"}
             -- None of these need to be done anymore as the function above already took care of that one!
             -- ret.CFGbool = map[string]bool{}
             -- ret.CFGint = map[string]int32{}
             -- ret.CFGstr = map[string]string{}
             -- ret.Vars = map[string]string{}
             -- ret.Comments = map[string]string{}
             local bt = fopen(file,"rb") -- bt, e := os.Open(file)
             if not JCR_assert(bt,("file %s could not be opened for reading!"):format(file)) then return end -- qerr.QERR(e)
             if RAW_ReadString(bt, 5) ~= "JCR6\x1a" then
                   error("YIKES!!! A NONE JCR6 FILE!!!! HELP! HELP! I'M DYING!!!") -- This error should NEVER be possible!
             end
             ret.FAToffset = RAW_ReadInt(bt)
             if ret.FAToffset <= 0 then
                 JCR_error( "Invalid FAT offset. Maybe you are trying to read a JCR6 file that has never been properly finalized" )
                 bt:close()
                 return nil
             end
             chat(sprintf("FAT Offest %i", ret.FAToffset))
             local TTag = 0 --    var TTag byte
             local Tag = "" --var Tag string
             TTag = RAW_ReadByte(bt)
             while TTag ~= 255 do
                   Tag = RAW_ReadString(bt)
                   chat(sprintf("CFGtag %i/%s", TTag, Tag))
                   -- Unfortunately Lua has no support for casing:       switch TTag {
                   if TTag==1 then -- case 1:
                      ret.CFGstr[Tag] = RAW_ReadString(bt)
                   elseif TTag==2 then
                      ret.CFGbool[Tag] = RAW_ReadByte(bt) == 1
                   elseif TTag==3 then
                      ret.CFGint[Tag] = RAW_ReadInt(bt)
                   --case 255:
                   --default:
                   elseif TTag~=255 then
                       JCR_error(sprintf("Invalid config tag (%d) %s",TTag,file))
                       bt:close()
                       return nil--        return ret
                   end 
                   TTag = qff.ReadByte(bt)
             end
             if ret.CFGbool["_CaseSensitive"] then
                JCR_error("Case Sensitive dir support was already deprecated and removed from JCR6 before it went to the Go and the Lua languages. It's only obvious that support for this was never implemented in Lua in the first place.")
                bt:close()
                return nil
             end   
             chat("Reading FAT")
             chat(sprintf("Seeking at: %d", ret.FAToffset))
             bt:seek("set",ret.FAToffset) --    qff.Seek(*bt, int(ret.FAToffset))
             -- chats("Positioned at: %i of %d", qff.Pos(*bt), qff.Size(*bt))
             local theend = false
             -- chats("The End: %s", theend)
             -- chats("EOF:     %s", qff.EOF(*bt))
             ret.FATsize    = RAW_ReadInt(bt)
             ret.FATcsize   = RAW_ReadInt(bt)
             ret.FATstorage = RAW_ReadString(bt)
             --    ret.Entries = map[string]TJCR6Entry{}
             chats("FAT Compressed Size: %d",ret.FATcsize)
             chats("FAT True Size:       %d",ret.FATsize)
             chats("FAT Comp. Algorithm: %s",ret.FATstorage)
             local fatcbytes --:=make([]byte,ret.FATcsize)
             local fatbytes --[]byte
             fatcbytes = bt:read(ret.FATcsize)
             bt:close()
             if not compression_drivers[ret.FATstorage] then --_,ok:=JCR6StorageDrivers[ret.FATstorage];!ok{
                JCR_error( sprintf("There is no driver found for the %s compression algorithm, so I cannot unpack the file table",ret.FATstorage) )
                return nil
             end
             fatbytes=compression_drivers[ret.FATstorage].expand(fatcbytes,ret.FATsize)
             if len(fatbytes)~=ret.FATsize then
                printf("WARNING!!!\nSize after unpacking does NOT match the size written inside the JCR6 file.\nSize is %d and it must be %d\nErrors can be expected!\n",len(fatbytes),ret.FATsize)
             end
             --    //fatbuffer:=bytes.NewBuffer(fatbytes)
             local btf = bytes_NewReader(fatbytes)
             -- qff.DEOF=false
             while (not btf:eof()) and (not theend) do
                  local mtag = btf:ReadByte()
                  local ppp,_ = btf.pos -- :=btf.Seek(0,1)
                  chats("FAT POSITION %d",ppp)
                  chat(sprintf("FAT MAIN TAG %d", mtag))
                  -- switch mtag {
                  if mtag==0xff then --      case 0xff:
                     theend = true
                  elseif mtag==0x01 then -- case 0x01:
                     local tag = btf:ReadString():upper()
                     chats("FAT TAG %s", tag)
                     -- switch tag {
                     if tag =="FILE" then --        case "FILE":
                        local newentry = {} -- := TJCR6Entry{}
                        newentry.Mainfile = file
                        newentry.Datastring = {} -- map[string]string{}
                        newentry.Dataint = {} -- map[string]int{}
                        newentry.Databool = {} -- map[string]bool{}
                        local ftag = btf:ReadByte()
                        while ftag ~= 255 do
                              chats("FILE TAG %d", ftag)
                              --            switch ftag {
                              if ftag==1 then --            case 1:
                                 local k = btf:ReadString()                                  chats("string key %s", k)
                                 local v = btf:ReadString()                                  chats("string value %s", v)
                                 newentry.Datastring[k] = v
                              elseif ftag==2 then --          case 2:
                                 local kb = btf:ReadString()
                                 local vb = btf:ReadByte() > 0
                                 chats("boolean key %s", kb)
                                 chats("boolean value %s",vb)
                                 newentry.Databool[kb] = vb
                              elseif ftag==3 then --         case 3:
                                 local ki = btf:ReadString()
                                 local vi = btf:ReadInt()
                                 chats("integer key %s",ki)
                                 chats("integer value %d",vi)
                                 newentry.Dataint[ki] = int(vi)
                              --            case 255:
                              --            default:
                              elseif ftag==255 then 
                                     -- p,_:=btf.Seek(0,1)
                                     JCR_error( sprintf("Illegal tag in FILE part %d on fatpos %d",ftag,btf.pos) )
                                     -- btf.Close()
                                     return nil
                              end
                              ftag = btf:ReadByte()
                        end
                        newentry.Entry = newentry.Datastring["__Entry"]
                        newentry.Size = newentry.Dataint["__Size"]
                        newentry.Compressedsize = newentry.Dataint["__CSize"]
                        newentry.Offset = newentry.Dataint["__Offset"]
                        newentry.Storage = newentry.Datastring["__Storage"]
                        newentry.Author = newentry.Datastring["__Author"]
                        newentry.Notes = newentry.Datastring["__Notes"]
                        centry = newentry.Entry:upper()
                        --          //fmt.Println("Adding entry: ",centry) // <- Debug
                        ret.Entries[centry] = newentry
                     elseif tag == "COMMENT" then --        case "COMMENT":
                        local commentname = btf:ReadString()
                        ret.Comments[commentname]=btf:ReadString()
                     elseif tag == "IMPORT" or tag == "REQUIRE" then --        case "IMPORT","REQUIRE":
                        if impdebug then
                           printf("%s request from %s\n",tag,file)
                        end
                        -- Now we're playing with power. Tha ability of
                        -- JCR6 to automatically patch other files into
                        -- one resource
                        local deptag = qff.ReadByte(btf)
                        local depk,depv="","" --          var depk,depv string
                        local depm = {} -- := map[string] string {}
                        while deptag~=255 do
                              depk = btf:ReadString()
                              depv = btf:ReadString()
                              depm[depk] = depv
                              deptag = qff.ReadByte(btf)
                        end
                        local depfile = depm["File"]
                        -- //depsig   := depm["Signature"]
                        local deppatha = depm["AllowPath"]=="TRUE"
                        local depcall  = ""
                        local depgetpaths = { [0]={}, [1]={} } --          var depgetpaths [2][] string
                        local owndir      = filepath.Dir(file)
                        local deppath     = 0
                        if impdebug then
                           printf("= Wanted file: %s\n",depfile)
                           printf("= Allow Path:  %d\n",deppatha)
                           printf("= ValConv:     %d\n",deppath)
                           printf("= Prio entnum  %d\n",len(ret.Entries))
                        end
                        if deppatha then
                           deppath=1
                        end
                        if owndir ~= "" then
                           owndir = owndir .. "/"
                        end
                        depgetpaths[0][#depgetpaths[0]+1] = owndir
                        depgetpaths[1][#depgetpaths[1]+1] = owndir
                        -- TODO: Support for multipath 
                        --[[ depgetpaths[1] = append(depgetpaths[1],dirry.Dirry("$AppData$/JCR6/Dependencies/") )
          if qstr.Left(depfile,1)!="/" && qstr.Left(depfile,2)!=":"{
            for _,depdir:=range depgetpaths[deppath]{
              if (depcall=="") && qff.Exists(depdir+depfile) {
                depcall=depdir+depfile
              } else if depcall=="" && impdebug {
                if !qff.Exists(depdir+depfile) {
                  fmt.Printf("It seems %s doesn't exist!!\n",depdir+depfile)
                }
              }
            } 
          } else {
            if qff.Exists(depfile) {
              depcall=depfile
            }
          }
          if depcall!="" {
            if (!PatchFile(&ret,depcall)) && tag=="REQUIRE"{
              jcr6err("Required JCR6 addon file ("+depcall+") could not imported!~n~nImporter reported:~n"+JCR6Error) //,fil,"N/A","JCR 6 Driver: Dir()")
              return ret
            } else if tag=="REQUIRE"{
              jcr6err("Required JCR6 addon file ("+depcall+") could not found!") //,fil,"N/A","JCR 6 Driver: Dir()")
            }
          } else if impdebug {
            fmt.Printf("Importing %s failed!",depfile)
            fmt.Printf("Request:    %s",tag)
          }

        }
                          ]]
                       else --      default:
                          JCR_error ( sprintf("Unknown main tag %d", mtag) )
                          return nil
                       end
                  end     
             end
             --    bt.Close()
             return ret
          end
}          



JCR_RegisterDir(JCR6_DirDriver)

-- Returns the name of the driver recognizing the file, and returns "nil" if not recognized
function JCR_Recognize(file)
    local r
    for _,d in ipairs(dir_drivers) do
        if d.recognize(file) then return d.name,d end
    end
 end local Recognize = JCR_Recognize
         

function JCR_Dir(file)
    local dirdriver,driver = Recognize(file)
    if not JCR_assert(dirdriver,("File %s could not be recognized with any driver!"):format(file)) then return nil end
    return driver.dir(file),dirdriver
end

