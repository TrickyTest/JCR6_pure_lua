--[[
***********************************************************
test.lua
This particular file has been released in the public domain
and is therefore free of any restriction. You are allowed
to credit me as the original author, but this is not 
required.
This file was setup/modified in: 
2019
If the law of your country does not support the concept
of a product being released in the public domain, while
the original author is still alive, or if his death was
not longer than 70 years ago, you can deem this file
"(c) Jeroen Broks - licensed under the CC0 License",
with basically comes down to the same lack of
restriction the public domain offers. (YAY!)
*********************************************************** 
Version 19.02.06
]]
require "JCR6_zlib"

local io = io
local pairs = pairs
local print = print

-- JCR_Chat = true -- This is a test after all!

print("Reading")
local d = JCR_Dir("MKL_test.jcr") -- I didn't include this file in the repository for obvious reasons, I believe :P



print("Let's see the results")


local function serie(t,tabs)
    tabs = tabs or 0
    for k,v in pairs(t) do
        for i=1,tabs do io.write("\t") end
        io.write( ("%s %s = "):format(type(v),k) )
        if type(v)=="table" then
           print("{}")
           serie(v,tabs+1)
        elseif type(v)=="function" then
           print("< FUNC >")
        else
           print(v)
        end         
    end
    -- print("")
end


serie(d)

for e in d:EntryList() do
    print(e)
end    


print(d:Get("ReadMe.md"))

local bt = d:Open('Readme.md')
while not bt:eof() do
      io.write(("\27[3%d;4%dm%s"):format(bt.pos % 8,7 - (bt.pos % 8),bt:ReadString(1)))
end
print("\27[0m\n\n")      