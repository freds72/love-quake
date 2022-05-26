local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")

return function(conf)
    -- connect a player to level
    local worldSystem = require("systems.world")
    
    -- find a place for the player
    local spawnPoints = worldSystem:find("player_start")
    
    return     
        -- update
        function()

        end,
        -- draw
        function()
            print("Game!!",480/2,270/2,256*time())
        end
end