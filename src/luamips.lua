
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


function Mips.Create(size)
	local mips = {}
	setmetatable(mips,Mips)

	mips.memory = {}
	mips.memsize = size
	assert(size%4 == 0)
	mips.pc = 0
	mips.inDelaySlot = false
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
	"zero",
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
	"fp",
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
	local paddr = addr - 0xa0000000
	return paddr
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
		error("writing unaligned address")
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
	local opcode = self:read(self.pc)
	local delaypc = self.pc +4
	
	self:doop(opcode)
	self.regs[0] = 0
	
    if self.inDelaySlot then
        opcode = self:read(delaypc)
        self:doop(opcode)
        self.regs[0] = 0
        self.inDelaySlot = false
    else
        self.pc = self.pc + 4
    end
    
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

function Mips:op_lw(op)
	local addr = (self:getRs(op) + self:getImm(op)) % 0x100000000
	local v = self:read(addr)
	self:setRt(op,v)
end

function Mips:op_ori(op)
	local v = bor(self:getRs(op),self:getImm(op))
	self:setRt(op,v)
end

function Mips:op_sll(op)
	local v = lshift(self:getRt(op),self:getShamt(op))
	self:setRd(op,v)
end

function Mips:op_addiu(op)
	local v = (self:getRs(op) + sext16(self:getImm(op))) % 0x100000000
	self:setRt(op,v)
end

function Mips:op_addu(op)
	self:setRd(op,(self:getRs(op) + self:getRt(op)) % 0x100000000 )
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

function Mips:op_lb(op)
	local addr = (self:getRs(op) + self:getImm(op)) % 0x100000000
	local v = self:readb(addr)
	v = sext8(v)
	self:setRt(op,v)
end

function Mips:op_lbu(op)
	local addr = (self:getRs(op) + self:getImm(op)) % 0x100000000
	local v = self:readb(addr)
	self:setRt(op,v)
end

function Mips:op_sb(op)
	local addr = (self:getRs(op) + self:getImm(op)) % 0x100000000
	self:writeb(addr,band(self:getRt(op),0xff))
end

function Mips:op_j(op)
	local top = band(self.pc,0xf0000000)
	local addr = bor(top,(band(op,0x3ffffff)*4))
	self.pc = addr
	self.inDelaySlot = true
end

function Mips:op_bne(op)
	local offset = sext18(self:getImm(op) * 4)
	if self:getRs(op) ~= self:getRt(op) then
		self.pc = (self.pc + offset) % 0x100000000
	else
		self.pc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_beq(op)
	local offset = sext18(self:getImm(op) * 4)
	if self:getRs(op) == self:getRt(op) then
		self.pc = (self.pc + offset) % 0x100000000
	else
		self.pc = self.pc + 8
	end
	self.inDelaySlot = true
end

function Mips:op_jal(op)
	local pc = self.pc
	local top = band(pc,0xf0000000)
	local addr = bor(top,lshift(band(op,0x3ffffff),2))
	self.pc = addr
	self.regs[31] = (pc + 8) % 0x100000000
	self.inDelaySlot = true
end

function Mips:op_jr(op)
	self.pc = self:getRs(op)
	self.inDelaySlot = true
end

