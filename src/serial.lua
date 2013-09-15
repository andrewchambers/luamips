
Serial = {}
Serial.__index = Serial

function Serial.Create()
	local ret = {}
	setmetatable(ret,Serial)
	return ret
end

-- signal ready on read

function Serial:read(offset)
	return 0xffffffff
end

function Serial:readb(offset)
	return 0xff
end

function Serial:write(offset,v)
	io.write(string.char(band(0xff,v)))
	io.flush()
end

function Serial:writeb(offset,v)
	io.write(string.char(v))
	io.flush()
end

