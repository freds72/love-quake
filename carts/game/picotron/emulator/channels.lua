-- thread communication channels
local lt = love.thread
return function()
    local events = lt.getChannel("events")
    local lock = lt.getChannel("lock")
    return {
        wait=function(self,payload)
            events:push(payload)
            return lock:demand()
        end,
        response=function(self,payload)
            lock:push(payload)
        end,
        pop=function()
            return events:pop()
        end
    }
end
