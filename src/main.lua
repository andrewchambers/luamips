


--Test functions

function test_memory()
	local mips = Mips.Create(1024*1024*32)

	local testbase = 0xa0000000

	assert(mips:read(testbase + 0) == 0)
	assert(mips:readb(testbase + 0) == 0)
	assert(mips:readb(testbase + 1) == 0)
	assert(mips:readb(testbase + 2) == 0)
	assert(mips:readb(testbase + 3) == 0)

	mips:write(testbase + 0,0xffffffff)

	assert(mips:read(testbase + 0) == 0xffffffff)
	assert(mips:readb(testbase + 0) == 0xff)
	assert(mips:readb(testbase + 1) == 0xff)
	assert(mips:readb(testbase + 2) == 0xff)
	assert(mips:readb(testbase +3) == 0xff)

	mips:write(testbase + 0,0x11223344)

	assert(mips:readb(testbase + 0) == 0x11)
	assert(mips:readb(testbase + 1) == 0x22)
	assert(mips:readb(testbase + 2) == 0x33)
	assert(mips:readb(testbase +3) == 0x44)

	mips:writeb(testbase + 0,0x44)
	mips:writeb(testbase + 1,0x33)
	mips:writeb(testbase + 2,0x22)
	mips:writeb(testbase + 3,0x11)

	assert(mips:read(testbase + 0) == 0x44332211)

end



function test()
	test_memory()
end



function loadSrec(emu,fname)

    local f = io.open(fname,"r")

	if f == nil then
		error("failed to open file " .. fname)
	end

    for line in f:lines() do
        if string.sub(line,1,1) == "S" then

            local t = string.sub(line,2,2)
            local address
			local addrlen
			local count
			local lentab = {["1"]=2,["2"]=3,["3"]= 4,
							["7"]=4 ,["8"]=3 , ["9"]=2}
            if t == "1" or t == "2" or t == "3" then
				count = tonumber(string.sub(line,3,4),16)
				addrlen = lentab[t]
				addr = string.sub(line,5,5+(addrlen*2) - 1)

				local datastart = 5+(addrlen*2)
                
				addr = tonumber(addr,16)
				

				for i=0,count-addrlen-2 do
					local b = string.sub(line,datastart + i*2, datastart + i*2 + 1)
					emu:writeb(addr+i,tonumber(b,16))
				end

            end

            if t == "7" or t == "8" or t == "9" then
				count = tonumber(string.sub(line,3,4),16)
				addrlen = lentab[t]
				addr = string.sub(line,5,5+(addrlen*2) - 1)
				print("setting pc:",addr)
				emu.pc = tonumber(addr,16)
			end
        end
    end
    f:close()
end



function main()
	print "running tests"
	test()
	print "loading srec"
	local emu = Mips.Create(1024*1024*32)
	loadSrec(emu,"kernel.srec")
	print "launching emulator..."
	while true do
		emu:step()
	end
end


main()
