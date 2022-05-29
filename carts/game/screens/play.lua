local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")
local world = require("systems.world")

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
            -- hud...
        end,
        -- init
        function()
            player = nil
            world:load(level)
            -- create a player
            player = world:connect()
        end
end