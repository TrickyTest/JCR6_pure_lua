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

function JCR_error(a)
     if JCR_Crash then error(a) end
     print("JCR6 Error: "..a)
     JCR_Caught[#JCR_Caught+1] = a
end

function JCR_assert(c,a)
     if not c then JCR_error(a) end
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
local class_JCRDir = {
      Entries = "@newtable",
      MainConfig = "@newtable",
      
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
    assert(type(driver.recognize)=='table',("Driver recognize must be a function and not be a %s"):format(type(driver.recognize)))
    assert(type(driver.dir)=='table',("Driver recognize must be a function and not be a %s!"):format(type(driver.dir)))
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
    return ret
end

function newJCRDir() return jnew(class_JCRDir) end
