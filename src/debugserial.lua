
DebugSerial = {}
DebugSerial.__index = DebugSerial

function DebugSerial.Create()
	local ret = {}
	setmetatable(ret,DebugSerial)
	return ret
end

-- signal ready on read

function DebugSerial:read(offset)
	return 1
end

function DebugSerial:readb(offset)
	return 1
end

function DebugSerial:write(offset,v)
	io.write(string.char(band(0xff,v)))
	io.flush()
end

function DebugSerial:writeb(offset,v)
	io.write(string.char(v))
	io.flush()
end

