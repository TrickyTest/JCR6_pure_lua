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