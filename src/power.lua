
PowerControl = {}
PowerControl.__index = PowerControl

function PowerControl.Create()
	local ret = {}
	setmetatable(ret,PowerControl)
	return ret
end

function PowerControl:read(offset)
	return 0
end

function PowerControl:readb(offset)
	return 0
end

function PowerControl:write(offset,v)
	if v == 42 then
            os.exit(0)
        end
end

function PowerControl:writeb(offset,v)
	if v == 42 then
            os.exit(0)
        end
end

