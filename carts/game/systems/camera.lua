-- camera
local logging = require("engine.logging")
local CameraSystem=function(world)
    local function track(self,pos,m, water)
        --pos=v_add(v_add(pos,m_fwd(m),-24),m_up(m),24)	      
        self.m={unpack(m)} 
        -- screen wobbling if under water/lava/...           
        if water then
            local w,h=0.98+0.04*cos(time()/2),0.98+0.04*sin(time()/2)
            m[1] = m[1] * w
            m[2] = m[2] * w
            m[3] = m[3] * w

            m[8+1] = m[8+1] * h
            m[8+2] = m[8+2] * h
            m[8+3] = m[8+3] * h
        end

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
                if not player then
                    return 1
                end
                local angle=player.mangles
                local m=m_x_m(
                    m_x_m(
                      make_m_from_euler(0,0,angle[3]),
                      make_m_from_euler(angle[1],0,0)),
                      make_m_from_euler(0,angle[2],0))
                
                track(parent,v_add(player.origin,player.eyepos),m,player.water_level>2)
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
                    -- try to find intermission positions
                    local spots = world:findClass("info_intermission")
                    if #spots>0 then
                        spot=spots[flr(rnd(#spots))+1]
                        logging.info("Intermission cam - switched to: "..v_tostring(spot.origin).."/"..#spots)
                        ttl=time() + 5
                    end
                end
                if spot then
                    local x,y,z=0,0,0
                    if spot.mangles then
                        x,y,z=unpack(spot.mangles)
                    end
                    local m=make_m_from_euler(x,0,z+0.1*cos(time()/16))
                    track(parent,v_add(spot.origin,{0,0,0}),m)
                end
            end
        }       
    end

    local activeCam
    return {
        ready=false,
        project=function(self,pos)
            pos=m_x_v(self.m,pos)
            local w=1/pos[2]
            return 480/2+270*pos[1]*w,270/2-270*pos[3]*w,w
        end,
        update=function(self)
            if not world.loaded then
                return
            end
            -- create an active cam if none
            if not activeCam then
                activeCam=makeMissionCamera(self)
            end

            if activeCam then
                self.ready = true
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