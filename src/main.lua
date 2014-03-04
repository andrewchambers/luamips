


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
	
	assert(mips:read(testbase + 4) == 0)

	mips:writeb(testbase + 0,0x44)
	mips:writeb(testbase + 1,0x33)
	mips:writeb(testbase + 2,0x22)
	mips:writeb(testbase + 3,0x11)

	assert(mips:read(testbase + 0) == 0x44332211)

end

function test_bwise()
	
	assert(rshift(0xff000000,24) == 0xff)
	
	assert(lshift(0xff,24) == 0xff000000)
	assert(rshift(1,1) == 0)
    assert(lshift(0x80000000,1) == 0)
    assert(lshift(0x80000001,31) == 0x80000000)
    assert(lshift(0xffffffff,31) == 0x80000000)
    assert(lshift(0xffffffff,32) == 0)
    assert(lshift(0x80000001,32) == 0x00000000)
	
	assert(bor(0xffffffff,0) == 0xffffffff)
	assert(bor(0xffff0000,0) == 0xffff0000)
	assert(bor(0xffff0000,0xffffffff) == 0xffffffff)
	assert(bor(0xf0f0f0f0,0x0f0f0f0f) == 0xffffffff)
	
	assert(band(0xffffffff,0) == 0x0)
	assert(band(0xffff0000,0) == 0x0)
	assert(band(0xffff0000,0xffffffff) == 0xffff0000)
	assert(band(0xf0f0f0f0,0x0f0f0f0f) == 0x0)
	assert(band(0xf0f0f0f0,0xf0f0f0f0) ==0xf0f0f0f0)
	
	assert(bxor(0xffffffff,0) == 0xffffffff)
	assert(bxor(0xffff0000,0) == 0xffff0000)
	assert(bxor(0xffff0000,0xffffffff) == 0x0000ffff)
	assert(bxor(0xf0f0f0f0,0x0f0f0f0f) == 0xffffffff)
	assert(bxor(0xf0f0f0f0,0xf0f0f0f0) ==0x0)
	
	assert(bnot(0xffffffff) == 0)
	assert(bnot(0) == 0xffffffff)
	assert(bnot(0xf0f0f0f0) == 0x0f0f0f0f)
	
		
	assert(sext18(0x3ffff) == 0xffffffff)
	
	assert(sext16(0xffff) == 0xffffffff)
	assert(sext16(0xf0f0) == 0xfffff0f0)
	assert(sext16(0) == 0x0)
	assert(sext16(0xff) == 0xff)
	
	assert(sext8(0xff) == 0xffffffff)
	assert(sext8(0xf0) == 0xfffffff0)
	assert(sext8(0) == 0x0)
	assert(sext8(0x0f) == 0x0f)
	
	assert(signed(0xffffffff) == -1)
	assert(signed(0xfffffffe) == -2)
	assert(signed(0x80000000) == -2147483648)
	assert(signed(0x7fffffff) == 2147483647)
	assert(signed(0x0fffffff) == 0x0fffffff)
    
    
    local hi
    local lo
    
    hi,lo = karatsuba(0x1,0xffffffff,false)
    assert(hi == 0)
    assert(lo == 0xffffffff)
    
    hi,lo = karatsuba(0x1,0xffffffff,true)
    assert(hi == 0xffffffff)
    assert(lo == 0xffffffff)
    
    hi,lo = karatsuba(0x11223344,0xffffffff,false)
    assert(hi == 0x11223343)
    assert(lo == 0xeeddccbc)

    hi,lo = karatsuba(0x11223344,0xffffffff,true)
    assert(hi == 0xffffffff)
    assert(lo == 0xeeddccbc)        

end

function testDeviceMap()
	local emu = Mips.Create(1024*1024*32)
	
	
	emu:write(0xa0000000,0xffffffff)
	emu:write(0xa0000004,0xffffffff)
	
	assert(emu:read(0xa0000000) == 0xffffffff)
	assert(emu:readb(0xa0000000) == 0xff)
	assert(emu:read(0xa0000004) == 0xffffffff)
	assert(emu:readb(0xa0000004) == 0xff)
	
	meminfo = MemoryInfo.Create(emu)
	
	emu:addDevice(0,4,meminfo)
	
	assert(meminfo:read(0) == 1024*1024*32)
	assert(emu:read(0xa0000000) == 1024*1024*32)
	assert(emu:readb(0xa0000000) == 0)
	assert(emu:read(0xa0000004) == 0xffffffff)
	assert(emu:readb(0xa0000004) == 0xff)
	
end


function test()
	test_memory()
	test_bwise()
	testDeviceMap()
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
					assert(emu:read((addr+i) - (addr+i) % 4) >= 0)
					assert(emu:read((addr+i) - (addr+i) % 4) <= 0xffffffff)
				end

            end

            if t == "7" or t == "8" or t == "9" then
				count = tonumber(string.sub(line,3,4),16)
				addrlen = lentab[t]
				addr = string.sub(line,5,5+(addrlen*2) - 1)
				--print("setting pc:",addr)
				emu.pc = tonumber(addr,16)
			end
        end
    end
    f:close()
end


function startTrace(fname)
    local t = {}
    t.state = {}
    t.file = io.open(fname,"w")
	    if t.file == nil then
	        error("failed to open trace file " .. fname)
	    end
    return t
end

function updateTrace(t,emu)
    
    local tstring = "{"
    for i = 1,32 do
        local rname = regn2o32[i]
        if t.state[rname] ~= emu.regs[i-1] then
            t.state[rname] = emu.regs[i-1]
            tstring = tstring .. string.format('"%s" : %d ,',rname,emu.regs[i-1])
        end
        
        if t.state.pc ~= emu.pc then
            t.state.pc = emu.pc
            tstring = tstring .. string.format('"pc" : %d ,',emu.pc)
        end
        
        if t.state.lo ~= emu.lo then
            t.state.lo = emu.lo
            tstring = tstring .. string.format('"lo" : %d ,',emu.lo)
        end
        
        if t.state.hi ~= emu.hi then
            t.state.hi = emu.hi
            tstring = tstring .. string.format('"hi" : %d ,',emu.hi)
        end
    end
    
    if tstring ~= "{" then
        tstring = string.sub(tstring,0,string.len(tstring) - 1)
    end
    
    tstring = tstring .. "}\n"
    t.file:write(tstring)
    t.file:flush()
end


function printstate(emu, n)
    local i
    io.stderr:write(string.format("State: %d\n",n))
    for i = 0 , 31 do
        io.stderr:write(string.format("gr%d: %08x\n",i,emu.regs[i]))
    end
    
    function PRFIELD(X)
        io.stderr:write(X .. string.format(": %08x\n",emu[X]))
    end 
    PRFIELD("hi")
    PRFIELD("lo")
    PRFIELD("pc")
    PRFIELD("delaypc")
    PRFIELD("CP0_Index")
    PRFIELD("CP0_EntryHi")
    PRFIELD("CP0_EntryLo0")
    PRFIELD("CP0_EntryLo1")
    PRFIELD("CP0_Context")
    PRFIELD("CP0_Wired")
    PRFIELD("CP0_Status")
    PRFIELD("CP0_Epc")
    PRFIELD("CP0_BadVAddr")
    PRFIELD("CP0_ErrorEpc")
    PRFIELD("CP0_Cause")
    PRFIELD("CP0_PageMask")
    PRFIELD("CP0_Count")
    PRFIELD("CP0_Compare")
    
end

function main()
	io.stdout:write("running tests\n")
	test()
	io.stdout:write("loading srec\n")
	local emu = Mips.Create(1024*1024*64)
	emu:addDevice(0x140003f8,8,Serial.Create())
	emu:addDevice(0x10000004,4,MemoryInfo.Create(emu))
    emu:addDevice(0x1fbf0004,4,PowerControl.Create(emu))
	loadSrec(emu,arg[1])
	io.stdout:write("launching emulator...\n")
	local nsteps = 0
	while true do
        if nsteps > 441320000 then
		  printstate(emu,nsteps)
        end
		emu:step()
		nsteps = nsteps + 1
		if nsteps >= 450000000 then
		    break
		end
	end
end


main()
