local logging={}
logging.level = 2

local function array_tostring(v,...)
    if not v then
        return ""
    end
    return tostring(v)..array_tostring(...)
end
local function log(sev, ...)
    print(sev.." - "..array_tostring(...))
end
local logs = {
    debug="DEBUG",
    info="INFO",
    warn="WARNING",
    err="ERROR",
    critical="CRITICAL"
}

for k,v in pairs(logs) do    
    logging[k]=function(...)        
        log(v,...)
    end
end

return logging