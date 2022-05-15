local GameState={}
local logging=require("logging")
local input=require("engine.input")

-- handles console commands
function GameState:command(cmd,...)
end

function GameState:pre_update()
    input:update()
end

function GameState:update()
end

function GameState:draw()
end

return GameState