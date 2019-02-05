--[[

  Using this module should automatically import JCR6 as a whole ;)
  
 ]]
 
 
 require "JCR6"
 local zlib = require("zlib") -- Tested with LuaRocks lua-zlib. This should call zlib.so or zlib.dll (depending on your platform)
 
 JCR_RegisterCompression("zlib",{
 
      compress = function(src)
           local pack = zlib.deflate(9) -- 9 for maximal compression has always been the standard for JCR6
           local retstring,eof,bi,bo = pack(src,'finish')
           JCR_assert(eof,"zlib: eof = false")
           JCR_assert(bi==#src,"zlib: Source count error")
           JCR_assert(bo==#retstring,"zlib: Pack count error")
           return retstring,bo
      end,
      
      expand = function(src,size)
           local unpack = zlib.inflate()
           retstring,eof,bi,bo = pack()
           JCR_assert(bo==size,"Unpack size mismatch! Size returned doesn't match the size expected")
           JCR_assert(bo==#retstring,"Unpack size error! Unpacked returns different size than the data actually is")
           return retstring
      end      
  
  
 })