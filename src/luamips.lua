Mips = {}
Mips.__index = Mips

local SLOW_BITOPS = false
local SLOW_ASSERTIONS = true

if bit ~= nil and bit.bor ~= nil and SLOW_BITOPS ~= true then -- luajit
    io.stdout:write("using fast bitops\n")
    function make_positive(v)
        return bit.band(v,0x7fffffff) + 0x80000000
    end
    
    function band(a,b)
        local ret = bit.band(a,b)
        if ret < 0 then
            return make_positive(ret)
        end
        return ret
    end

    function bor(a,b)
        local ret = bit.bor(a,b)
        if ret < 0 then
            return make_positive(ret)
        end
        return ret
    end

    function bxor(a,b)
        local ret = bit.bxor(a,b)
        if ret < 0 then
            return make_positive(ret)
        end
        return ret
    end
    
    function lshift(a,b)
        if b > 31 then
            return 0
        end
        local ret = bit.lshift(a,b)
        ret = ret % 0x100000000
        if ret < 0 then
            return make_positive(ret)
        end
        return ret
    end
    
    function rshift(a,b)
        if b > 31 then
            return 0
        end
        ret = bit.rshift(a,b)
        if ret < 0 then
            return make_positive(ret)
        end
        return ret
    end

else -- we dont have the luajit bit library
    io.stdout:write("using slow bitops\n")
    
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
    
    function lshift(v,amt)
	    return (v * 2^amt) % 0x100000000
    end

    function rshift(v,amt)
	    return math.floor(v / (2^amt))
    end

    
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


-- START Uart code i.e. the terminal input and output to the machine

-- -------------------------------------------------
-- -------------------- UART -----------------------
-- -------------------------------------------------

local UART_LSR_DATA_READY = 0x1
local UART_LSR_FIFO_EMPTY = 0x20
local UART_LSR_TRANSMITTER_EMPTY = 0x40

local UART_IER_THRI = 0x02  -- Enable Transmitter holding register int.
local UART_IER_RDI = 0x01  -- Enable receiver data interrupt

local UART_IIR_MSI = 0x00  -- Modem status interrupt (Low priority)
local UART_IIR_NO_INT = 0x01
local UART_IIR_THRI = 0x02 -- Transmitter holding register empty
local UART_IIR_RDI = 0x04 -- Receiver data interrupt
local UART_IIR_RLSI = 0x06 -- Receiver line status interrupt (High p.)
local UART_IIR_CTI = 0x0c -- Character timeout

local UART_LCR_DLAB = 0x80 -- Divisor latch access bit

local UART_DLL = 0 -- R/W: Divisor Latch Low, DLAB=1
local UART_DLH = 1 -- R/W: Divisor Latch High, DLAB=1

local UART_IER = 1 -- R/W: Interrupt Enable Register
local UART_IIR = 2 -- R: Interrupt ID Register
local UART_FCR = 2 -- W: FIFO Control Register
local UART_LCR = 3 -- R/W: Line Control Register
local UART_MCR = 4 -- W: Modem Control Register
local UART_LSR = 5 -- R: Line Status Register
local UART_MSR = 6 -- R: Modem Status Register
local UART_SCR = 7 -- R/W: 

-- FIFO code - used so we dont drop characters of input
-- dont call these directly, 



function uart_newFifo()
    local b = {}
    for i = 0,31 do
        b[i] = 0
    end
    return {last = 0 , first = 0 , count = 0 , buff = b }
end

function uart_fifoHasData(fifo)
    return fifo.count > 0;
end

function uart_fifoPush(fifo, c) 
    fifo.buff[fifo.last] = c
    fifo.last = (fifo.last + 1) % 32;
    fifo.count = fifo.count + 1
    if fifo.count > 32  then
       fifo.count = 32 
    end
end

function uart_fifoGet(fifo) 

    local c = 0
    
    if not uart_fifoHasData(fifo) then
        return 0;
    end
    
    c = fifo.buff[fifo.first]
    fifo.first = (fifo.first + 1) % 32;
    fifo.count = fifo.count - 1
    
    return c;
end

function uart_fifoClear(fifo)
    fifo.last  = 0
    fifo.first = 0
    fifo.count = 0
end


-- end Fifo code

Serial = {}
Serial.__index = Serial

function Serial.Create()
    local ret = {}
    setmetatable(ret,Serial)
    ret.fifo = uart_newFifo()
    ret:reset()
    return ret
end

-- signal ready on read

function Serial:read(offset)
    return 0xffffffff
end


function Serial:write(offset,v)

end

function Serial:reset()
    self.LCR = 3;
    self.LSR = bor(UART_LSR_TRANSMITTER_EMPTY , UART_LSR_FIFO_EMPTY)
    self.MSR = 0;
    self.IIR = UART_IIR_NO_INT
    self.IER = 0;
    self.DLL = 0;
    self.DLH = 0;
    self.FCR = 0;
    self.MCR = 0;
    self.SCR = 0;    
    uart_fifoClear(self.fifo);
end

function Serial:updateIrq ()
    if band(self.LSR , UART_LSR_DATA_READY) > 0 and band(self.IER , UART_IER_RDI) > 0  then
        self.IIR = UART_IIR_RDI
    elseif band(self.LSR , UART_LSR_FIFO_EMPTY) > 0 and band(self.IER , UART_IER_THRI) > 0 then
        self.IIR = UART_IIR_THRI
    else
        self.IIR = UART_IIR_NO_INT
    end
    
    -- if there is an interrupt pending
    if (self.IIR ~= UART_IIR_NO_INT) then
        --triggerExternalInterrupt(emu,0);
    else
        --clearExternalInterrupt(emu,0);
    end
end

function Serial:recieveChar()
    uart_fifoPush(self..fifo,c);
    self.LSR = bor(self.LSR,UART_LSR_DATA_READY)
    self:updateIrq()
end

function Serial:readb(offset) 
    
    local ret
    
    offset = band(offset,7)
    
    if band(self.LCR , UART_LCR_DLAB) > 0 then
            if offset == UART_DLL then
                return self.DLL
            elseif offset == UART_DLH then
                return self.DLH
            end
    end
    if offset == 0 then
        ret = 0
        if uart_fifoHasData(self.fifo) then
            ret = uart_fifoGet(self.fifo)
            self.LSR = band(self.LSR, bnot(UART_LSR_DATA_READY))
            if uart_fifoHasData(self.fifo) then
                self.LSR = bor(self.LSR,UART_LSR_DATA_READY)
            end
        end
        self:updateIrq()
        return ret
    elseif offset == UART_IER then
        return band(self.IER,0x0F)
    elseif offset == UART_MSR then
        return self.MSR
    elseif offset == UART_MCR then
        return self.MCR
    elseif offset == UART_IIR then
        ret = self.IIR -- the two top bits are always set
        return ret
    elseif offset == UART_LCR then
        return self.LCR
    elseif offset == UART_LSR then
        if uart_fifoHasData(self.fifo) then
            self.LSR = bor(self.LSR ,UART_LSR_DATA_READY)
        else
            self.LSR = band(self.LSR, bnot(UART_LSR_DATA_READY))
        end
        return self.LSR;
    elseif offset == UART_SCR then
        return self.SCR
    else
        --print("Error in uart ReadRegister: offset not supported);
        return 0
    end
end

function Serial:writeb(offset, x)
    
    x = band(0xff,x)
    local offset = band(offset,7)
    
    if band(self.LCR , UART_LCR_DLAB) > 0 then
        if offset == UART_DLL then
            self.DLL = x
            return
        elseif offset == UART_DLH then
            self.DLH = x
            return
        end
    end

    if offset == 0 then
        self.LSR = band(self.LSR, bnot(UART_LSR_FIFO_EMPTY))
        if band(self.MCR , 16) > 0 then -- LOOPBACK 
            uart_RecieveChar(self.fifo,x)
        else
            io.write(string.char(x))
            io.flush()
        end
        -- Data is sent with a latency of zero!
        self.LSR = bor(self.LSR, UART_LSR_FIFO_EMPTY) -- send buffer is empty                   
        self:updateIrq()
        return
    elseif offset == UART_IER then
        -- 2 = 10b ,5=101b, 7=111b
        self.IER = band(x , 0x0F) -- only the first four bits are valid
        -- Ok, check immediately if there is a interrupt pending
        self:updateIrq()
    elseif offset == UART_FCR then
        self.FCR = x
        if band(self.FCR , 2) > 0  then
            uart_fifoClear(self.fifo)
        end
    elseif offset == UART_LCR then
        self.LCR = x
    elseif offset == UART_MCR then
        self.MCR = x
    elseif offset == UART_SCR then
        self.SCR = x
    else
        -- printf"Error in uart WriteRegister: offset not supported")
    end
end

-- END Uart

--CP0 flags
local CP0St_CU3 = 31
local CP0St_CU2 = 30
local CP0St_CU1 = 29
local CP0St_CU0 = 28
local CP0St_RP  = 27
local CP0St_FR  = 26
local CP0St_RE  = 25
local CP0St_MX  = 24
local CP0St_PX  = 23
local CP0St_BEV = 22
local CP0St_TS  = 21
local CP0St_SR  = 20
local CP0St_NMI = 19
local CP0St_IM  = 8
local CP0St_KX  = 7
local CP0St_SX  = 6
local CP0St_UX  = 5
local CP0St_UM  = 4
local CP0St_KSU = 3
local CP0St_ERL = 2
local CP0St_EXL = 1
local CP0St_IE  = 0
-- Possible Values for the EXC field in the status reg
local EXC_Int    = 0
local EXC_Mod    = 1
local EXC_TLBL   = 2
local EXC_TLBS   = 3
local EXC_AdEL   = 4
local EXC_AdES   = 5
local EXC_IBE    = 6
local EXC_DBE    = 7
local EXC_SYS    = 8
local EXC_BP     = 9
local EXC_RI     = 10
local EXC_CpU    = 11
local EXC_Ov     = 12
local EXC_Tr     = 13
local EXC_Watch  = 23
local EXC_MCheck = 24



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

    mips.tlbExceptionWasNoMatch = false

    mips.llbit = 0
    mips.CP0_Index = 0
    mips.CP0_EntryHi = 0
    mips.CP0_EntryLo0 = 0
    mips.CP0_EntryLo1 = 0
    mips.CP0_Context = 0
    mips.CP0_Wired = 0
    mips.CP0_Status = 4 -- set erl
    mips.CP0_Epc = 0
    mips.CP0_BadVAddr = 0
    mips.CP0_ErrorEpc = 0
    mips.CP0_Cause = 0
    mips.CP0_PageMask = 0
    
    mips.CP0_Count = 0
    mips.CP0_Compare = 0


    mips.tlbEntries = {}

    for i = 0, 15 do
        local tlbent = {}
        tlbent.VPN2 = 0
        tlbent.ASID = 0
        tlbent.G =  false
        tlbent.V0 = false
        tlbent.V1 = false
        tlbent.D0 = false
        tlbent.D1 = false
        tlbent.C0 = false
        tlbent.C1 = false
        tlbent.PFN = {}
        tlbent.PFN[0] = 0
        tlbent.PFN[1] = 0
        mips.tlbEntries[i] = tlbent
    end

	for i = 0,31 do
		mips.regs[i] = 0
	end

	for i = 0,size/4 do
		mips.memory[i] = 0
	end

	return mips
end

function Mips:debugCheckState()
    local err = function(msg)
	    io.stderr:write(msg .. "\n")
	    self:dumpState()
	    os.exit(1)
    end 
    
    local passed = false
    for i = 0,31 do
		if self.regs[i] < 0 or self.regs[i] > 0xffffffff  then
            err("register " .. regn2o32[i] .. " out of range!\n")
		end
	end
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


function Mips:writeTlbExceptionExtraData(vaddr) 
    self.CP0_BadVAddr = vaddr
    self.CP0_Context = bor(band(self.CP0_Context, bnot(0x007fffff)) , band(rshift(vaddr, 9) , 0x007ffff0))
    self.CP0_EntryHi = bor(band(self.CP0_EntryHi , 0xff) , band(vaddr , 0xffffe000))
end


-- XXX currently hardcoded for 4k pages
function Mips:tlb_lookup (vaddress, write)
    local ASID = band(self.CP0_EntryHi, 0xFF)
    local i
    self.tlbExceptionWasNoMatch = false
    
    for i = 0, 15 do
        local tlb_e = self.tlbEntries[i]
        local tag = rshift(band(vaddress, 0xfffff000) , 13)
        local VPN2 = tlb_e.VPN2
        -- Check ASID, virtual page number & size 
        if ((tlb_e.G or tlb_e.ASID == ASID) and VPN2 == tag) then
            -- TLB match 
            local n = band(rshift(vaddress , 12) , 1) > 0
            -- Check access rights

            if (not (n and tlb_e.V1 or tlb_e.V0)) then
                self.exceptionOccured = true
                self:setExceptionCode(write and EXC_TLBS or EXC_TLBL)
                self:writeTlbExceptionExtraData(vaddress)
                return -1
            end
            if (write == true or (n and tlb_e.D1 or tlb_e.D0)) then
                return bor(tlb_e.PFN[n and 1 or 0] , band(vaddress , 0xfff))
            end
            self.exceptionOccured = true
            self:setExceptionCode(EXC_Mod)
            self:writeTlbExceptionExtraData(vaddress)
            return -1
        end
    end
    self.tlbExceptionWasNoMatch = true
    self.exceptionOccured = true
    self:setExceptionCode(write and EXC_TLBS or EXC_TLBL)
    self:writeTlbExceptionExtraData(vaddress)
    return -1
end


function Mips:translateAddr(vaddr,write)	
    if vaddr <= 0x7FFFFFFF then
        -- useg
        if band(self.CP0_Status , lshift(1,CP0St_ERL)) ~= 0  then
            return vaddr
        else
            return self:tlb_lookup(vaddr, write)
        end
    elseif  vaddr >= 0x80000000 and vaddr <= 0x9fffffff then
        return vaddr - 0x80000000
    elseif  vaddr >= 0xa0000000 and vaddr <= 0xbfffffff then
        return vaddr - 0xa0000000
    else 
        -- kseg2 and 3
        if self:isKernelMode() then
            return self:tlb_lookup(vaddr, write)
        else
            print ("translate address unhandled exception!")
            return vaddr
        end
    end
    
end

function Mips:readb(addr)
	
	addr = self:translateAddr(addr,false)

    if addr < 0 then
        return 0
    end

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
	
	addr = self:translateAddr(addr,true)
    if addr < 0 then
        return
    end
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
	
	addr = self:translateAddr(addr,false)
	if addr < 0 then
        return 0
    end
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
	addr = self:translateAddr(addr,true)
    if addr < 0 then
        return 
    end
	local deventry = self:matchDevice(addr)
	if deventry ~= nil then
		deventry.device:writeb(addr - deventry.base,val)
		return
	end
	
	
	if addr >= self.memsize or addr < 0 then
	    error(string.format("bad physical address %x",addr))
	end
	assert(val ~= nil)
	assert(0 <= val and val <= 0xffffffff)
	self.memory[addr/4] = val
end


function Mips:getExceptionCode()
    return band(rshift(self.CP0_Cause , 2) , 0x1f)
end

function Mips:setExceptionCode(code) 
    self.CP0_Cause = band(self.CP0_Cause, bnot(0x7c)) -- clear exccode
    self.CP0_Cause = bor(self.CP0_Cause, lshift(band(code , 0x1f) , 2)) -- set with new code
end


function Mips:isKernelMode()
    
    if  band(self.CP0_Status , lshift(1 , CP0St_UM)) == 0 then
        return true
    end
    return band(self.CP0_Status , bor(lshift(1 , CP0St_EXL) , lshift(1 , CP0St_ERL))) > 0
end


function Mips:handleException(delaySlot)
    local offset
    local exccode = self:getExceptionCode()
        
    self.inDelaySlot = false
    
    if  band(self.CP0_Status , lshift(1, CP0St_EXL)) == 0 then
        if delaySlot then
            self.CP0_Epc = self.pc - 4
            self.CP0_Cause = bor(self.CP0_Cause, 0x80000000) -- set BD
        else 
            self.CP0_Epc = self.pc
            self.CP0_Cause = band(self.CP0_Cause, 0x7fffffff) -- clear BD
        end
        
        if exccode == EXC_TLBL or exccode == EXC_TLBS then
            -- XXX this seems inverted? bug in also qemu? test with these cases reversed after booting.
            if not self.tlbExceptionWasNoMatch  then
                offset = 0x180
            else 
                offset = 0
            end
        elseif  (exccode == EXC_Int) and (band(self.CP0_Cause , 0x800000) ~= 0) then
            offset = 0x200
        else
            offset = 0x180
        end
    else
        offset = 0x180
    end
    
    -- Faulting coprocessor number set at fault location
    -- exccode set at fault location
    self.CP0_Status = bor(self.CP0_Status, lshift(1,CP0St_EXL))
    
    if band(self.CP0_Status , lshift(1,CP0St_BEV)) ~= 0 then
        self.pc = 0xbfc00200 + offset
    else
        self.pc = 0x80000000 + offset
    end
    self.exceptionOccured = false
end

function Mips:handleInterrupts()
    -- if interrupts disabled or ERL or EXL set
    if band(self.CP0_Status , 1) == 0 or band(self.CP0_Status , 0x6) ~= 0  then
        return false -- interrupts disabled
    end
    
    if band(band(self.CP0_Cause , self.CP0_Status) ,  0xfc00) == 0 then
        return false -- no pending interrupts
    end
    self.waiting = false
    self:setExceptionCode(EXC_Int)
    self:handleException(self.inDelaySlot)
    
    return true
end

function Mips:triggerExternalInterrupt(intNum)
    self.CP0_Cause = bor(self.CP0_Cause , lshift(band(lshift(1 , intNum) , 0x3f ), 10))
end

function Mips:clearExternalInterrupt(intNum)
    self.CP0_Cause = band( self.CP0_Cause, bnot(lshift(band(lshift(1 , intNum) , 0x3f ), 10)))  
end

function Mips:step()
    self.CP0_Count = (self.CP0_Count + 1) % 0x100000000
    -- /* timer code */
    if self.CP0_Count == self.CP0_Compare then
        -- but only do this if interrupts are enabled to save time.
        self:triggerExternalInterrupt(5); -- 5 is the timer int :)
    end
    
    if self:handleInterrupts() then
        return
    end
    
    if self.waiting then
        return
    end

    local startInDelaySlot = self.inDelaySlot
    
    local opcode = self:read(self.pc)
    
    if self.exceptionOccured then -- instruction fetch failed
        self:handleException(startInDelaySlot);
        return
    end
    
    self:doop(opcode)
    self.regs[0] = 0
    
    if self.exceptionOccured then
        self:handleException(startInDelaySlot)
        return    
    end
    
    if SLOW_ASSERTIONS then
        self:debugCheckState()
    end
	if startInDelaySlot then
	    self.pc = self.delaypc
	    self.inDelaySlot = false
	    return
	end
    
    self.pc = (self.pc + 4) % 0x100000000
end
--------------------------------------------------------------------------------
-- Opcode helper functions
--------------------------------------------------------------------------------
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
	--XXX ignores exception for overflow...
    self:op_addiu(op)
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
    local wordVal = self:read(addr - (addr % 4))
    local offset = addr % 4
    local result

    if offset == 0 then
        result = wordVal
    end
    
    if offset == 1 then
        result = bor(lshift(wordVal, 8) , band(rtVal, 0xff))
    end
    
    if offset == 2 then
        result = bor(lshift(wordVal, 16) , band(rtVal, 0xffff))
    end
    
    if offset == 3 then
        result = bor(lshift(wordVal, 24) , band(rtVal, 0xffffff))
    end
    
    self:setRt(op,result)
end

function Mips:op_swl(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:read(addr - (addr % 4))
    local offset = addr % 4
    local result

    if offset == 0 then
        result = rtVal
    end
    
    if offset == 1 then
        result = bor(band(wordVal,0xff000000) , band(rshift(rtVal,8),0xffffff))
    end
    
    if offset == 2 then
        result = bor(band(wordVal,0xffff0000) , band(rshift(rtVal,16),0xffff))
    end
    
    if offset == 3 then
        result = bor(band(wordVal,0xffffff00) , band(rshift(rtVal,24),0xff))
    end
    
    self:write(addr - (addr % 4),result)
end




function Mips:op_lwr(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:read(addr - (addr % 4))
    local offset = addr % 4
    local result

    if offset == 3 then
        result = wordVal
    end
    
    if offset == 2 then
        result = bor(band(rtVal, 0xff000000) , rshift(wordVal,8))
    end
    
    if offset == 1 then
        result = bor(band(rtVal, 0xffff0000) , rshift(wordVal,16))
    end
    
    if offset == 0 then
        result = bor(band(rtVal, 0xffffff00) , rshift(wordVal,24))
    end
    
    self:setRt(op,result)
end

function Mips:op_swr(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local rtVal = self:getRt(op)
    local wordVal = self:read(addr - (addr % 4))
    local offset = addr % 4
    local result

    if offset == 3 then
        result = rtVal
    end
    
    if offset == 2 then
        result = bor( band(lshift(rtVal,8),0xffffff00), band(wordVal,0xff) ) 
    end
    
    if offset == 1 then
        result = bor( band(lshift(rtVal,16),0xffff0000), band(wordVal,0xffff) ) 
    end
    
    if offset == 0 then
        result = bor( band(lshift(rtVal,24),0xff000000), band(wordVal,0xffffff) ) 
    end
    
    self:write(addr - (addr % 4),result)
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

function Mips:op_bnel(op)
    local offset = sext18(self:getImm(op) * 4)
    if self:getRs(op) ~= self:getRt(op) then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
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

function Mips:op_beql(op)
    local offset = sext18(self:getImm(op) * 4)
    if self:getRs(op) == self:getRt(op) then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
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

function Mips:op_blezl(op)
    local offset = sext18(self:getImm(op) * 4)
    if signed(self:getRs(op)) <= 0 then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
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

function Mips:op_bgezl(op)
    local offset = sext18(self:getImm(op) * 4)
    if signed(self:getRs(op)) >= 0 then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
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

function Mips:op_bltzl(op)
    local offset = sext18(self:getImm(op) * 4)
    if signed(self:getRs(op)) < 0 then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
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

function Mips:op_bgtzl(op)
    local offset = sext18(self:getImm(op) * 4)
    if signed(self:getRs(op)) > 0 then
        self.delaypc = (self.pc + 4 + offset) % 0x100000000
        self.inDelaySlot = true
    else
        self.pc = self.pc + 4
    end
    
end

function Mips:op_jal(op)
	local pc = self.pc
	local top = band(pc,0xf0000000)
	local addr = bor(top,lshift(band(op,0x3ffffff),2))
	self.delaypc = addr
	self.regs[31] = (pc + 8) % 0x100000000
	self.inDelaySlot = true
end

function Mips:op_jalr(op)
	self.delaypc = self:getRs(op)
	self.regs[31] = (self.pc + 8) % 0x100000000
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

function Mips:op_movz(op)
    if self:getRt(op) == 0 then
        self:setRd(op,self:getRs(op))
    end
end

function Mips:op_movn(op)
    if self:getRt(op) ~= 0 then
        self:setRd(op,self:getRs(op))
    end
end

function Mips:op_mul(op)
    --XXX can be much faster
    local hi,low = karatsuba(self:getRs(op),self:getRt(op),true)
    self:setRd(op,low);
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

function Mips:op_mthi(op)
    self.hi = self:getRs(op)
end

function Mips:op_mtlo(op)
    self.lo = self:getRs(op)
end


function Mips:op_mfc0(op)
    local regNum = rshift(band(op, 0xf800), 11)
    local sel = band(op, 7)
    local retval = 0
    
    if regNum == 0 then -- Index
        retval = self.CP0_Index;
    elseif regNum == 2 then --EntryLo0
        retval = self.CP0_EntryLo0
    elseif regNum == 3 then --ntryLo1
        retval = self.CP0_EntryLo1;
    elseif regNum == 4 then -- Context
        retval = self.CP0_Context
    elseif regNum == 5 then -- Page Mask
        retval = self.CP0_PageMask
    elseif regNum == 6 then -- Wired
        retval = self.CP0_Wired
    elseif regNum == 8 then -- BadVAddr
        retval = self.CP0_BadVAddr
    elseif regNum == 9 then -- Count
        retval = self.CP0_Count
    elseif regNum == 10 then  -- EntryHi
        retval = self.CP0_EntryHi
    elseif regNum == 11 then  -- Compare
        retval = self.CP0_Compare
    elseif regNum == 12 then  -- Status
        retval = self.CP0_Status
    elseif regNum == 13 then 
        retval = self.CP0_Cause
    elseif regNum == 14 then  -- EPC
        retval = self.CP0_Epc
    elseif regNum == 15 then 
        retval = 0x00018000 --processor id, just copied qemu 4kc
    elseif regNum == 16 then 
        if sel == 0 then
            retval = 0x80008082 -- XXX cacheability fields shouldnt be hardcoded as writeable
        elseif sel == 1 then
            retval = 0x1e190c8a
        end
    elseif regNum == 18 or regNum == 19 then 
        retval = 0
    end
    
    self:setRt(op,retval)
    
end

function Mips:op_mtc0(op)
    local rt = self:getRt(op)
    local regNum = rshift(band(op, 0xf800), 11)
    local sel = band(op, 7)

    if regNum == 0 then -- Index
        self.CP0_Index = bor(band(self.CP0_Index, 0x80000000 ), band(rt , 0xf))
    elseif regNum == 2 then -- EntryLo0
        self.CP0_EntryLo0 = band(rt , 0x3ffffff)
    elseif regNum == 3 then -- EntryLo1
        self.CP0_EntryLo1 = band(rt , 0x3ffffff)
    elseif regNum == 4 then -- Context
        self.CP0_Context = band(self.CP0_Context, bor(band(self.CP0_Context, bnot( 0xff800000 )) , band(rt, 0xff800000 )))
    elseif regNum == 5 then -- Page Mask
        if rt ~= 0 then
            --print("XXX unhandled page mask");
            return
        end
        self.CP0_PageMask = band(rt , 0x1ffe000)
    elseif regNum == 6 then -- Wired
        self.CP0_Wired = band(rt , 0xf)
    elseif regNum == 9 then -- Count
        self.CP0_Count = rt
    elseif regNum == 10 then -- EntryHi
        self.CP0_EntryHi = band(rt , bnot(0x1f00))
    elseif regNum == 11 then -- Compare
        self:clearExternalInterrupt(5)
        self.CP0_Compare = rt
    elseif regNum == 12 then -- Status
        local status_mask = 0x7d7cff17;
        self.CP0_Status =  bor(band(self.CP0_Status, bnot(status_mask)) , band(rt , status_mask))
        --XXX NMI is one way write
    elseif regNum == 13 then --cause
        local cause_mask = bor(bor(lshift(1 , 23) , lshift(1 , 22)) , lshift(3 , 8));
        self.CP0_Cause = bor(band(self.CP0_Cause , bnot(cause_mask) ) , band(rt , cause_mask))
    elseif regNum == 14 then --epc
        self.CP0_Epc = rt
    elseif regNum == 16 then
    elseif regNum == 18 then
    elseif regNum == 19 then
    end

end

function  Mips:op_eret(op)
    
    if self.inDelaySlot then
        return
    end
    
    self.llbit = false
    
    if band(self.CP0_Status , 4) ~= 0 then -- ERL is set
        self.CP0_Status = band(self.CP0_Status,bnot(4)) -- clear ERL;
        self.pc = self.CP0_ErrorEpc
    else
        self.pc = self.CP0_Epc
        self.CP0_Status = band(self.CP0_Status , bnot(2)) -- clear EXL;
    end
    self.pc = self.pc - 4 -- counteract typical pc += 4
end

function Mips:op_ll(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
    local wordVal = self:read(addr)
	if self.exceptionOccured then
        return;
    end
    self.llbit = true
	self:setRt(op,wordVal)
end

function Mips:op_sc(op)
    local c = sext16(band(op,0x0000ffff))
    local addr = (self:getRs(op)+c) % 0x100000000
	
	if self.llbit then
	    self:write(addr,self:getRt(op))
    	if self.exceptionOccured then
            return
        end
	end
	
	if self.llbit then
        self:setRt(op, 1)	    
	else
	    self:setRt(op, 0)
	end
	
end

function Mips:op_cache(op)

end

function Mips:op_pref(op)

end

function Mips:op_tne(op)
	if self:getRs(op) ~= self:getRt(op) then
		-- XXX
		print("XXX unhandled trap!");
	end
end

function Mips:helper_writeTlbEntry(idx)
    idx = band(idx, 0xf) -- only 16 entries must mask it off
    tlbent = self.tlbEntries[idx]
    tlbent.VPN2 = rshift(self.CP0_EntryHi, 13)
    tlbent.ASID = band(self.CP0_EntryHi, 0xff)
    tlbent.G =  band(band(self.CP0_EntryLo0 , self.CP0_EntryLo1) , 1) > 0
    tlbent.V0 = band(self.CP0_EntryLo0 , 2) > 0
    tlbent.V1 = band(self.CP0_EntryLo1 , 2) > 0
    tlbent.D0 = band(self.CP0_EntryLo0 , 4) > 0
    tlbent.D1 = band(self.CP0_EntryLo1 , 4) > 0
    tlbent.C0 = band(rshift(self.CP0_EntryLo0  , 3) , 7) > 0
    tlbent.C1 = band(rshift(self.CP0_EntryLo1  , 3) , 7) > 0
    tlbent.PFN[0] = lshift( band(rshift(self.CP0_EntryLo0 , 6) , 0xfffff) , 12)
    tlbent.PFN[1] = lshift( band(rshift(self.CP0_EntryLo1 , 6) , 0xfffff) , 12)
end

function Mips:op_tlbwi(op) 
    local idx = self.CP0_Index
    self:helper_writeTlbEntry(idx)
end

function Mips:op_tlbwr(op)
    local idx = randomInRange(self.CP0_Wired,15);
    self:helper_writeTlbEntry(idx)
end
