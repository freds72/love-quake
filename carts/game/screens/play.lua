local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")
local world = require("systems.world")
local messages = require("systems.message")

-- game screen/state
return function(conf, level)    
    local player
    return     
        -- update
        function()
            -- handle inputs
            -- any active player?
            if player then
                player.prethink(input)
            end            
        end,
        -- draw
        function()            
            -- any messages?
            if messages.msg then
                print(messages.msg,480/2-#messages.msg*4/2,110,15)
            end
        end,
        -- init
        function()
            player = nil
            world:load(level)
            -- create a player
            player = world:connect()
        end
end