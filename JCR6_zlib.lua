--[[
  JCR6_zlib.lua
  
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


--[[

  Using this module should automatically import JCR6 as a whole ;)
  
 ]]
 
 
 require "JCR6"
 local zlib = require("zlib") -- Tested with LuaRocks lua-zlib. This should call zlib.so or zlib.dll (depending on your platform)
 
 JCR_RegisterCompression("zlib",{
 
      compress = function(src)
           local pack = zlib.deflate(9) -- 9 for maximal compression has always been the standard for JCR6
           local retstring,eof,bi,bo = pack(src,'finish')
           if JCR_assert(eof,"zlib: eof = false") then return end
           if JCR_assert(bi==#src,"zlib: Source count error") then return end
           if JCR_assert(bo==#retstring,"zlib: Pack count error") then return end
           return retstring,bo
      end,
      
      expand = function(src,size)
           local unpack = zlib.inflate()
           local retstring,eof,bi,bo = unpack(src)
           if JCR_assert(bo==size,("Unpack size mismatch! Size returned doesn't match the size expected\n%d != %d\n%s\n"):format(bo,size,retstring)) then return end
           if JCR_assert(bo==#retstring,"Unpack size error! Unpacked returns different size than the data actually is") then return end
           return retstring
      end      
  
  
 })
