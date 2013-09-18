
Mips = {}
Mips.__index = Mips


function lshift(v,amt)
	return (v * 2^amt) % 0x100000000
end

function rshift(v,amt)
	return math.floor(v / (2^amt))
end

function bor(a,b)
	local val = 0
	local i = 0
	while a > 0 or b > 0 do		
		if a % 2 == 1 or b % 2 == 1 then
			val = val + 2^i
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		i = i + 1
	end
	return val
end

function band(a,b)
	local val = 0
	local i = 0
	while a > 0 and b > 0 do		
		if a % 2 == 1 and b % 2 == 1 then
			val = val + 2^i
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		i = i + 1
	end
	return val
end

function bxor(a,b)
	local val = 0
	for i=0,31 do		
		if (a % 2 + b % 2) == 1 then
			val = val + 2^i
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		i = i + 1
	end
	return val
end


function bnot(a)
	return 0xffffffff - a
end

function sext18(val)
	if band(val,0x20000) ~= 0 then
		return bor(0xfffc0000,val)
	end
	
	return band(0x0003ffff,val)
end

function sext16(val)
	if band(val,0x8000) ~= 0 then
		return bor(0xffff0000,val)
	end
	
	return band(0x0000ffff,val)
end

function sext8(val)
	if band(val,0x80) ~= 0 then
		return bor(0xffffff00,val)
	end
	
	return band(0x000000ff,val)
end

function signed(val)
	if val >= 0x80000000 then
		local result = bnot(val) + 1
		return -result
	end
	
	return val
end

function karatsuba(a,b,signed)
    -- karatsuba algorithm for multiplying
    -- this is done so we dont lose precision in 64 bit mult
    local number1 = a
    local number2 = b
    
    local n1sign = band(a,0x80000000) > 0
    local n2sign = band(b,0x80000000) > 0
    
    if signed then
        -- first do the multiply as if we are unsigned
        -- we will add the sign back later
        if n1sign then
            number1 = (bnot(a) + 1) % 0x100000000 
        end
        
        if n2sign then
            number2 = (bnot(b) + 1) % 0x100000000
        end
        
    end

    local number1Hi = rshift(number1,16)
    local number1Lo = band(number1,0xffff)
    local number2Hi = rshift(number2,16)
    local number2Lo = band(number2,0xffff)
    local z2 = (number1Hi * number2Hi)
    local z1 = (number1Hi * number2Lo) + (number1Lo * number2Hi)
    local z0 = (number1Lo * number2Lo)
    local result = (z2*4294967296 + z1*65536 + z0)
    local t1 = (z1*65536 + z0)
    local hi = z2 + ((t1-t1%4294967296) / 4294967296)
    local lo = (z1*65536 + z0) % 0x100000000
    
    
    -- not (n1sign xor n2sign)
    if signed and not ( (n1sign and n2sign) or (not (n1sign or n2sign) ) ) then
        --we must make hi and lo negative
        --do a twos compliment
        lo = bnot(lo)
        hi = bnot(hi)
        lo = lo + 1
        if lo > 0xffffffff then
            lo = 0
            hi = hi + 1
            if hi > 0xffffffff then
                hi = 0
            end
        end
    end
    
    return hi,lo
end


function Mips.Create(size)
	local mips = {}
	setmetatable(mips,Mips)

	mips.memory = {}
	mips.memsize = size
	assert(size%4 == 0)
	mips.pc = 0
	mips.delaypc = 0
	mips.inDelaySlot = false
	mips.hi = 0
    mips.lo = 0
    mips.regs = {}
	mips.devices = {}

	for i = 0,32 do
		mips.regs[i] = 0
	end

	for i = 0,size/4 do
		mips.memory[i] = 0
	end

	return mips
end

-- reg number to reg names using the o32 abi
regn2o32 = {
	"r0",
	"at",
	"v0",
	"v1",
	"a0",
	"a1",
	"a2",
	"a3",
	"t0",
	"t1",
	"t2",
	"t3",
	"t4",
	"t5",
	"t6",
	"t7",
	"s0",
	"s1",
	"s2",
	"s3",
	"s4",
	"s5",
	"s6",
	"s7",
	"t8",
	"t9",
	"k0",
	"k1",
	"gp",
	"sp",
	"s8",
	"ra"
}

function Mips:dumpState()
	for i=0,31 do
		print(string.format("%s: %08x",regn2o32[i+1],self.regs[i]))
	end
	print(string.format("pc: %08x",self.pc))
end

function Mips:addDevice(baseaddr,size,device)
	table.insert(self.devices,{base = baseaddr,size = size, device = device})
end

function Mips:matchDevice(addr)
	for devCount = 1, #self.devices do
		local curentry = self.devices[devCount]
		if addr >= curentry.base and addr < curentry.base + curentry.size then
			return curentry
		end
	end
	return nil
end


function Mips:translateAddr(addr)	
    if addr >= 0x80000000 and addr < 0xa0000000 then 
    	return addr - 0x80000000
    end

    if addr >= 0xa0000000 and addr < 0xc0000000 then 
    	return addr - 0xa0000000
    end

    return addr
end

function Mips:readb(addr)
	
	addr = self:translateAddr(addr)
	local offset = addr % 4
	local baseaddr = addr - offset	
	
	
	local deventry = self:matchDevice(addr)
	if deventry ~= nil then
		return deventry.device:readb(addr - deventry.base)
	end
	
	if baseaddr >= self.memsize or baseaddr < 0 then
	    error(string.format("bad physical address %x" ,baseaddr))
	end
	word = self.memory[baseaddr/4]
	local shamt = 8*(3 - offset)
	local mask = lshift(0xff,shamt)
	local b = rshift(band(word,mask),shamt)
	assert(0 <= b and b < 256)
	return b
end

function Mips:writeb(addr,val)
	assert(0 <= val and val < 256)
	
	addr = self:translateAddr(addr)
	local offset = addr % 4
	local baseaddr = addr - offset
	
	local deventry = self:matchDevice(addr)
	if deventry ~= nil then
		deventry.device:writeb(addr - deventry.base,val)
		return
	end
	
	
	if baseaddr >= self.memsize or baseaddr < 0 then
	    error(string.format("bad physical address %x" ,baseaddr))
	end
	
	word = self.memory[baseaddr/4]
	local shamt = 8*(3 - offset)
	local clearmask = bnot(lshift(0xff,shamt))
	local valmask = lshift(val,shamt)
	word = band(word,clearmask)
	self.memory[baseaddr/4] = bor(word,valmask)
end

function Mips:read(addr)
	if addr % 4 ~= 0 then
		error("reading unaligned address")
	end
	
	addr = self:translateAddr(addr)
	
	local deventry = self:matchDevice(addr)
	if deventry ~= nil then
		return deventry.device:read(addr - deventry.base)
	end
	
	if addr >= self.memsize or addr < 0 then
	    error(string.format("bad physical address %x",addr))
	end
	
	return self.memory[addr/4]
end

function Mips:write(addr,val)
	if addr % 4 ~= 0 then
        self:dumpState()
		error("writing unaligned address " .. string.format("%08x",addr))
	end
	addr = self:translateAddr(addr)
	
	local deventry = self:matchDevice(addr)
	if deventry ~= nil then
		deventry.device:writeb(addr - deventry.base,val)
		return
	end
	
	
	if addr >= self.memsize or addr < 0 then
	    error(string.format("bad physical address %x",addr))
	end
	assert(0 <= val and val <= 0xffffffff)
	self.memory[addr/4] = val
end


function Mips:step()
	assert( self.pc % 4 == 0,"unaligned pc")
	
	local startInDelaySlot = self.inDelaySlot
	local opcode = self:read(self.pc)
    self:doop(opcode)
    self.regs[0] = 0
	if startInDelaySlot then
	    self.pc = self.delaypc
	    self.inDelaySlot = false
	    return
	end
    
    self.pc = self.pc +4
    
end

function Mips:setRt(op,val)
	local idx = rshift(band(op,0x1f0000),16)
	self.regs[idx] = val
end

function Mips:getRt(op,val)
	local idx = rshift(band(op,0x1f0000),16)
	return self.regs[idx]
end

function Mips:setRd(op,val)
	local idx = rshift(band(op,0xf800),11)
	self.regs[idx] = val
end

function Mips:getRs(op)
	local idx = rshift(band(op,0x3e00000),21)
	return self.regs[idx]
end

function Mips:getImm(op)
	return band(op,0xffff)
end

function Mips:getShamt(op)
	return rshift(band(op,0x7c0),6)
end

-------------------------------------
-- opcode implementation
-------------------------------------

function Mips:op_lui(op)
	local v = lshift(self:getImm(op),16)
	self:setRt(op,v)
end

function Mips:op_addi(op)
	local v = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	self:setRt(op,v)
end

function Mips:op_ori(op)
	local v = bor(self:getRs(op),self:getImm(op))
	self:setRt(op,v)
end

function Mips:op_xori(op)
	local v = bxor(self:getRs(op),self:getImm(op))
	self:setRt(op,v)
end

function Mips:op_andi(op)
	local v = band(self:getRs(op),self:getImm(op))
	self:setRt(op,v)
end

function Mips:op_and(op)
	self:setRd(op,band(self:getRs(op),self:getRt(op)))
end

function Mips:op_or(op)
	self:setRd(op,bor(self:getRs(op),self:getRt(op)))
end

function Mips:op_nor(op)
	self:setRd(op,bnot(bor(self:getRs(op),self:getRt(op))))
end

function Mips:op_xor(op)
	self:setRd(op,bxor(self:getRs(op),self:getRt(op)))
end


function Mips:op_addiu(op)
	local v = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
    self:setRt(op,v)
end

function Mips:op_addu(op)
	self:setRd(op,(self:getRs(op) + self:getRt(op)) % 0x100000000 )
end

function Mips:op_subu(op)
	local v = bnot(self:getRt(op)) + 1 % 0x100000000
    self:setRd(op,(self:getRs(op) + v) % 0x100000000 )
end

function Mips:op_add(op)
	local v = (self:getRs(op) + self:getRt(op))
	local r = v % 0x100000000
	
	if v ~= r then
		error("overflow trap not implemented")
	end 
	self:setRd(op,r)
end

function Mips:op_sw(op)
	local offset = sext16(self:getImm(op))
	local addr = (self:getRs(op) + offset) % 0x100000000
	self:write(addr,self:getRt(op))
end

function Mips:op_sh(op)
	local offset = sext16(self:getImm(op))
	local addr = (self:getRs(op) + offset) % 0x100000000
	local vlo = band(self:getRt(op),0xff)
	local vhi = rshift(band(self:getRt(op),0xff00),8)
	self:writeb(addr,vhi)
	self:writeb(addr+1,vlo)
end

function Mips:op_lwl(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:readb(addr + 3)
    wordVal = wordVal + self:readb(addr + 2) * 0x100
    wordVal = wordVal + self:readb(addr + 1) * 0x10000
    wordVal = wordVal + self:readb(addr)     * 0x1000000
    local offset = addr % 4
    local result

    if offset == 0 then
        result = wordVal
    end
    
    if offset == 1 then
        result = bor(band(wordVal, 0xffffff00) , band(rtVal, 0xff))
    end
    
    if offset == 2 then
        result = bor(band(wordVal, 0xffff0000) , band(rtVal, 0xffff))
    end
    
    if offset == 3 then
        result = bor(band(wordVal, 0xff000000) , band(rtVal, 0xffffff))
    end
    
    self:setRt(op,result)
end


function Mips:op_swl(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:readb(addr + 3)
    wordVal = wordVal + self:readb(addr + 2) * 0x100
    wordVal = wordVal + self:readb(addr + 1) * 0x10000
    wordVal = wordVal + self:readb(addr)     * 0x1000000
    local offset = addr % 4
    local result

    if offset == 0 then
        result = wordVal
    end
    
    if offset == 1 then
        result = bor(band(wordVal, 0xffffff00) , band(rtVal, 0xff))
    end
    
    if offset == 2 then
        result = bor(band(wordVal, 0xffff0000) , band(rtVal, 0xffff))
    end
    
    if offset == 3 then
        result = bor(band(wordVal, 0xff000000) , band(rtVal, 0xffffff))
    end
    
    self:writeb(addr,band(result,0xff))
    self:writeb(addr + 1,band(result,0xff00) / 0x100)
    self:writeb(addr + 2,band(result,0xff0000) / 0x10000)
    self:writeb(addr + 3,band(result,0xff000000) / 0x1000000)
end

function Mips:op_lwr(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:readb(addr)
    wordVal = wordVal + self:readb(addr - 1 ) * 0x100
    wordVal = wordVal + self:readb(addr - 2) * 0x10000
    wordVal = wordVal + self:readb(addr - 3)     * 0x1000000
    local offset = addr % 4
    local result

    if offset == 3 then
        result = wordVal
    end
    
    if offset == 2 then
        result = bor(band(wordVal, 0x00ffffff) , band(rtVal, 0xff000000))
    end
    
    if offset == 1 then
        result = bor(band(wordVal, 0xffff) , band(rtVal, 0xffff0000))
    end
    
    if offset == 0 then
        result = bor(band(wordVal, 0xff) , band(rtVal, 0xffffff00))
    end
    
    self:setRt(op,result)
end

function Mips:op_swr(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:readb(addr)
    wordVal = wordVal + self:readb(addr - 1) * 0x100
    wordVal = wordVal + self:readb(addr - 2) * 0x10000
    wordVal = wordVal + self:readb(addr - 3) * 0x1000000
    local offset = addr % 4
    local result

    if offset == 3 then
        result = wordVal
    end
    
    if offset == 2 then
        result = bor(band(wordVal, 0x00ffffff) , band(rtVal, 0xff000000))
    end
    
    if offset == 1 then
        result = bor(band(wordVal, 0xffff) , band(rtVal, 0xffff0000))
    end
    
    if offset == 0 then
        result = bor(band(wordVal, 0xff) , band(rtVal, 0xffffff00))
    end
    
    self:writeb(addr,band(result,0xff))
    self:writeb(addr + 1,band(result,0xff00) / 0x100)
    self:writeb(addr + 2,band(result,0xff0000) / 0x10000)
    self:writeb(addr + 3,band(result,0xff000000) / 0x1000000)
end

function Mips:op_lw(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	local v = self:read(addr)
	self:setRt(op,v)
end

function Mips:op_lhu(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	local vlo = self:readb(addr+1)
	local vhi = self:readb(addr)
	local v = bor(lshift(vhi,8),vlo)
	self:setRt(op,v)
end

function Mips:op_lh(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	local vlo = self:readb(addr+1)
	local vhi = self:readb(addr)
	local v = sext16(bor(lshift(vhi,8),vlo))
	self:setRt(op,v)
end

function Mips:op_lb(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	local v = self:readb(addr)
	v = sext8(v)
	self:setRt(op,v)
end

function Mips:op_lbu(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	local v = self:readb(addr)
	self:setRt(op,v)
end

function Mips:op_sb(op)
	local addr = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	self:writeb(addr,band(self:getRt(op),0xff))
end

function Mips:op_j(op)
	local top = band(self.pc,0xf0000000)
	local addr = bor(top,(band(op,0x3ffffff)*4))
	self.delaypc = addr
	self.inDelaySlot = true
end

function Mips:op_bne(op)
	local offset = sext18(self:getImm(op) * 4)
	if self:getRs(op) ~= self:getRt(op) then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_beq(op)
	local offset = sext18(self:getImm(op) * 4)
	if self:getRs(op) == self:getRt(op) then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_blez(op)
	local offset = sext18(self:getImm(op) * 4)
	if signed(self:getRs(op)) <= 0 then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_bgez(op)
	local offset = sext18(self:getImm(op) * 4)
	if signed(self:getRs(op)) >= 0 then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_bltz(op)
	local offset = sext18(self:getImm(op) * 4)
	if signed(self:getRs(op)) < 0 then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_bgtz(op)
	local offset = sext18(self:getImm(op) * 4)
	if signed(self:getRs(op)) > 0 then
		self.delaypc = (self.pc + 4 + offset) % 0x100000000
	else
		self.delaypc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_jal(op)
	local pc = self.pc
	local top = band(pc,0xf0000000)
	local addr = bor(top,lshift(band(op,0x3ffffff),2))
	self.delaypc = addr
	self.regs[31] = (pc + 8) % 0x100000000
	self.inDelaySlot = true
end

function Mips:op_jr(op)
	self.delaypc = self:getRs(op)
	self.inDelaySlot = true
end


function Mips:op_sll(op)
	local v = lshift(self:getRt(op),self:getShamt(op))
	self:setRd(op,v)
end


function Mips:op_srl(op)
	local v = rshift(self:getRt(op),self:getShamt(op))
	self:setRd(op,v)
end

function Mips:op_sra(op)
	local rt = self:getRt(op)
	local sa = self:getShamt(op)
	local signed = band(rt,0x80000000) > 0
	local v = rshift(rt,sa)
	if signed then
		v = bor(bnot(rshift(0xffffffff,sa)),v)
	end
	self:setRd(op,v)
end

function Mips:op_srav(op)
	local rt = self:getRt(op)
	local sa = band(self:getRs(op),0x1f)
	local signed = band(rt,0x80000000) > 0
	local v = rshift(rt,sa)
	if signed then
		v = bor(bnot(rshift(0xffffffff,sa)),v)
	end
	self:setRd(op,v)
end

function Mips:op_srlv(op)
    self:setRd(op,rshift(self:getRt(op),band(self:getRs(op),0x1f)))
end

function Mips:op_sllv(op)
    self:setRd(op,lshift(self:getRt(op),band(self:getRs(op),0x1f)))
end

function Mips:op_slti(op)
    local rs = self:getRs(op);
    local c = self:getImm(op);
    if signed(rs) < signed(sext16(c)) then
        self:setRt(op,1)
    else
        self:setRt(op,0)
    end
end

function Mips:op_sltiu(op)
    local rs = self:getRs(op);
    local c = self:getImm(op);
    if rs < sext16(c) then
        self:setRt(op,1)
    else
        self:setRt(op,0)
    end
end

function Mips:op_sltu(op)
    local rs = self:getRs(op);
    local rt = self:getRt(op);
    if rs < rt then
        self:setRd(op,1)
    else
        self:setRd(op,0)
    end
end

function Mips:op_slt(op)
    local rs = self:getRs(op);
    local rt = self:getRt(op);
    if signed(rs) < signed(rt) then
        self:setRd(op,1)
    else
        self:setRd(op,0)
    end
end

function Mips:op_div(op)
    local rs = self:getRs(op)
    local rt = self:getRt(op)
    
    if rt == 0 then
        return
    end
    
    local n1sign = band(rs,0x80000000) > 0
    local n2sign = band(rt,0x80000000) > 0
    
    if signed then
        -- first do the divide as if we are unsigned
        -- we will add the sign back to the results
        if n1sign then
            rs = (bnot(rs) + 1) % 0x100000000 
        end
        
        if n2sign then
            rt = (bnot(rt) + 1) % 0x100000000
        end
        
    end
    
    self.hi = rs % rt
    self.lo = (rs - self.hi) / rt
    
    --twos compliment them, the result must be signed
    if not ( (n1sign and n2sign) or (not (n1sign or n2sign) ) ) then
        self.lo = (bnot(self.lo) + 1) % 0x100000000 
    end
    
    -- the rem takes the sign of the divisor
    if n1sign then
        self.hi = (bnot(self.hi) + 1) % 0x100000000 
    end
    
end

function Mips:op_divu(op)
    local rs = self:getRs(op)
    local rt = self:getRt(op)
    if rt == 0 then
        return
    end
    self.hi = rs % rt
    self.lo = (rs - self.hi) / rt
end

function Mips:op_mult(op)
    -- XXX consider evaling HI and LO lazily, and in seperate parts
    self.hi,self.lo = karatsuba(self:getRs(op),self:getRt(op),true)
end

function Mips:op_multu(op)
    -- XXX consider evaling HI and LO lazily, and in seperate parts
    self.hi,self.lo = karatsuba(self:getRs(op),self:getRt(op),false)
end

function Mips:op_mfhi(op)
    self:setRd(op,self.hi)
end

function Mips:op_mflo(op)
    self:setRd(op,self.lo)
end
