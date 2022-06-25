local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")
local world = require("systems.world")
local messages = require("systems.message")
local conf = require("game_conf")

-- game screen/state
return function(level)    
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
            -- crosshair 
            local hw,hh=480/2,270/2
            pset(hw-1,hh,8)       
            pset(hw+1,hh,8)       
            pset(hw,  hh-1,8)       
            pset(hw,  hh+1,8)       
            -- any messages?
            if messages.msg then
                print(messages.msg,480/2-#messages.msg*4/2,110,15)
            end

            if player then
                print("content: "..player.contents.."\nground: "..tostring(player.on_ground),2,2,15)
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