bit = require("bit")


Mips = {}
Mips.__index = Mips


function Mips.Create(size)
	local mips = {}
	setmetatable(mips,Mips)

	mips.memory = {}
	mips.memsize = size
	assert(size%4 == 0)
	mips.pc = 0
	mips.inDelaySlot = false
	mips.regs = {}
	

	for i = 0,32 do
		mips.regs[i] = 0
	end

	for i = 0,size/4 do
		mips.memory[i] = 0
	end

	return mips
end

function Mips:translateAddr(addr)
	local paddr = addr - 0xa0000000
	
	if paddr >= self.memsize or paddr < 0 then
	    error(string.format("bad physical address %x from %x" ,paddr,addr))
	end
	
	return paddr
end

function Mips:readb(addr)
	local offset = addr % 4
	local baseaddr = addr - offset
	baseaddr = self:translateAddr(baseaddr)
	word = self.memory[baseaddr/4]

	local shamt = 8*(3 - offset)
	local mask = bit.lshift(0xff,shamt)
	local b = bit.rshift(bit.band(word,mask),shamt)

	assert(0 <= b and b < 256)
	return b
end

function Mips:writeb(addr,val)
	assert(0 <= val and val < 256)
	local offset = addr % 4
	local baseaddr = addr - offset
	baseaddr = self:translateAddr(baseaddr)
	word = self.memory[baseaddr/4]

	local shamt = 8*(3 - offset)
	local clearmask = bit.bnot(bit.lshift(0xff,shamt))
	local valmask = bit.lshift(val,shamt)
	word = bit.band(word,clearmask)
	self.memory[baseaddr/4] = bit.bor(word,valmask)
end

function Mips:read(addr)
	if addr % 4 ~= 0 then
		error("reading unaligned address")
	end
	addr = self:translateAddr(addr)
	return self.memory[addr/4]
end

function Mips:write(addr,val)
	if addr % 4 ~= 0 then
		error("writing unaligned address")
	end
	addr = self:translateAddr(addr)
	assert(0 <= val and val <= 0xffffffff)
	self.memory[addr/4] = val
end


function Mips:step()
	assert( self.pc % 4 == 0,"unaligned pc")
	local opcode = self:read(self.pc)
	
	local prevpc = self.pc
	
	self:doop(opcode)
	
	if self.pc == prevpc then
	    if self.inDelaySlot == false then
	        self.pc = self.pc + 4
	    end
	end
	
end

-- opcode implementation

function Mips:op_sll(op)
    self.pc = self.pc + 4
end



