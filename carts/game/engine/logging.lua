local Logging={}
Logging.level = 2

local function array_tostring(v,...)
    if not v then
        return ""
    end
    return tostring(v).." "..array_tostring(...)
end
local function log(sev, ...)
    printh(sev.." - "..array_tostring(...))
end
local logs = {
    debug="DEBUG",
    info="INFO",
    warn="WARNING",
    error="ERROR",
    critical="CRITICAL"
}

for k,v in pairs(logs) do    
    Logging[k]=function(...)        
        log(v,...)
    end
end

return Logging