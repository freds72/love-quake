-- camera
local logging = require("engine.logging")
local CameraSystem=function(world)
    local function track(self,pos,m)
        --pos=v_add(v_add(pos,m_fwd(m),-24),m_up(m),24)	      
        self.m={unpack(m)}            
        -- inverse view matrix
        m[2],m[5]=m[5],m[2]
        m[3],m[9]=m[9],m[3]
        m[7],m[10]=m[10],m[7]
        --
        self.m=m_x_m(m,{
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            -pos[1],-pos[2],-pos[3],1
        })
        
        self.origin=pos
    end

    local function makeFPSCamera(parent)
        return {
            update=function(self)
                local player=world.player
                if not player or player.dead then
                    return 1
                end
                -- track(parent,player.origin,
            end
        }
    end

    local function makeMissionCamera(parent)
        -- switch every 10s
        local ttl,spot=-1
        return {
            update=function(self)
                local player=world.player
                -- actual game started?
                if player and not player.dead then
                    return 0
                end
                if time()>ttl then
                    -- switch position
                    -- todo: pick a random location
                    -- try to find intermission positions
                    local spots = world.entities:find(nil,"classname","info_intermission")
                    if #spots>0 then
                        spot=spots[flr(rnd(#spots))+1]
                        logging.info("Intermission cam - switched to: "..v_tostring(spot.origin).."/"..#spots)
                        ttl=time() + 5
                    end
                end
                if spot then 
                    track(parent,v_add(spot.origin,{0,0,-24}),make_m_from_euler(unpack(spot.mangles)))
                end
            end
        }       
    end

    local activeCam
    return {
        update=function(self)
            -- create an active cam if none
            if not activeCam then
                activeCam=makeMissionCamera(self)
            end

            if activeCam then
                local res=activeCam:update()
                if res==0 then
                    activeCam = makeFPSCamera(self)
                    activeCam:update()
                elseif res==1 then
                    activeCam = makeMissionCamera(self)
                    activeCam:update()
                end
            end
        end
    }
end

return CameraSystem