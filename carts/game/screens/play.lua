local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")
local world = require("systems.world")
local messages = require("systems.message")
local conf = require("game_conf")

-- game screen/state
return function(level)    
    local player
    local death_ttl
    return     
        -- update
        function()
            -- handle inputs
            -- any active player?
            if player and player.deadflag==0 then
                player.prethink(input)
            end   
            
            if player.deadflag>0 and not death_ttl then
                death_ttl = time() + 2
            end
            
            -- avoid immediate click to start menu
            if death_ttl and time()>death_ttl then
                if input:released("ok") then
                    stateSystem:next("screens.menu")
                end
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
            -- any messages? (dont't display if player dead)
            if messages.msg and not death_ttl then
                print(messages.msg,480/2-#messages.msg*4/2,110,15)
            end

            if player then
                print("content: "..player.contents.."\nground: "..tostring(player.on_ground and player.on_ground.classname).."\nhp:"..player.health,2,2,15)
            end

            if player.deadflag>0 and flr(time()*2)%2==0 then
                local msg = "You are dead.\nPress fire to start over"
                print(msg,480/2-#msg*4/2,110,15)
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