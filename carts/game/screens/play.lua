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
        function(_,rasterizer, camera, renderer)    
            -- crosshair 
            -- todo: replace hardcoded values?
            local hw,hh=480/2,270/2
            pset(hw-1,hh,8)       
            pset(hw+1,hh,8)       
            pset(hw,  hh-1,8)       
            pset(hw,  hh+1,8)  
            
            -- weapon?
            if player and player.deadflag==0 and camera.ready then
                -- something to display?
                rasterizer:beginFrame()

                -- 
                renderer:beginFrame()
                local fwd=m_fwd(player.m)
                local up=m_up(player.m)
                local origin=v_add(v_add(player.origin,player.eyepos),fwd,48)

                local angle=player.mangles
                local to_world=m_x_m(
                    m_x_m(
                      make_m_from_euler(0,0,angle[3]),
                      make_m_from_euler(angle[1],0,0)),
                      make_m_from_euler(0,angle[2],0))
                m_set_pos(to_world, v_add(v_add(player.origin, player.eyepos, -1),{0,0,-player.eye_offset/16}))

                local to_local=make_m_from_euler(0,0,-0.25)
                m_set_pos(to_local,{0,0,0})
                local local_to_world=m_x_m(to_world, to_local)
                renderer:drawModel(camera,{0,0,0},local_to_world,player.weapon,"shot"..player.weaponframe)
                renderer:endFrame()
                rasterizer:endFrame()
                
                -- draw hit pos
                --[[
                local origin=v_add(player.origin,player.eyepos)
                local trace = world.collisionMap:hitscan({0,0,0},{0,0,0},player.origin,v_add(player.origin,fwd,1024),{},{world.entities[1]},player)
                if trace.n then
                    local x0,y0=camera:project(trace.pos)
                    local x1,y1=camera:project(v_add(trace.pos,trace.n,16))
                    line(x0,y0,x1,y1,32)
                end
                ]]
            end

            -- any messages? (dont't display if player dead)
            if messages.msg and not death_ttl then
                print(messages.msg,480/2-#messages.msg*4/2,110,15)
            end

            if player then
                print("content: "..player.contents.." ("..player.water_level..")\nground: "..tostring(player.on_ground and player.on_ground.classname).."\nhp:"..player.health,2,2,15)
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