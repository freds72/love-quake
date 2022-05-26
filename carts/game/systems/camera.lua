-- camera
local CameraSystem=function(world)
    local function makeFPSCamera()
        return {
            update=function(self)
                local player=world.player
                if not player or player.dead then
                    return 1
                end
            end
        }
    end

    local function makeMissionCamera()
        -- switch every 10s
        local ttl=time()+10
        return {
            update=function(self)
                local player=world.player
                if player and not player.dead then
                    return 0
                end
                if time()>ttl then
                    -- switch position
                    -- todo: pick a random location
                end
            end
        }       
    end

    local activeCam=makeFPSCamera()
    return {
        update=function(self)
            local res=activeCam:update()
            if res==0 then
                activeCam = makeFPSCamera()
            elseif res==1 then
                activeCam = makeMissionCamera()
            end
        end
    }
end

return CameraSystem