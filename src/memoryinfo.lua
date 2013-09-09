
MemoryInfo = {}
MemoryInfo.__index = MemoryInfo

function MemoryInfo.Create(emu)
	local ret = {}
	ret.emu = emu
	setmetatable(ret,MemoryInfo)
	return ret
end

function MemoryInfo:read(offset)
	if offset == 0 then
		return self.emu.memsize
	else
		return 0
	end
end

function MemoryInfo:readb(offset)
	return 0
end

function MemoryInfo:write(offset,v)
	return
end

function MemoryInfo:writeb(offset,v)
	return
end

