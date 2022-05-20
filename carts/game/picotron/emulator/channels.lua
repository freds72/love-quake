-- thread communication channels
local lt = love.thread
return function()
    return {
        events = lt.getChannel ("events"),
        lock = lt.getChannel("lock")
    }
end
