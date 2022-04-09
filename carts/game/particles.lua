local particles=function()
    -- p8 compat
    local add,del=table.insert,table.remove
    local rnd,flr=math.random,math.floor
    -- components is the global registry of services
    local emitters={}
    local pool = require("recycling_pool")("particles",7,2500)
    local active_particles = {}
    -- layout
    local VBO_X=0
    local VBO_Y=1
    local VBO_Z=2
    local VBO_VX=3
    local VBO_VY=4
    local VBO_VZ=5
    local VBO_TTL=6
    return {
        -- create a new particle system        
        new=function(self,owner,params)
            local emitter={
                origin=v_clone(owner.origin),
                size=v_add(params.maxs,params.mins,-1),
                params=params,
                count=0
            }
            emitters[emitter] = owner
            -- todo: return opaque ID
            return emitter
        end,
        free=function(self,emitter)
            emitters[emitter] = nil
        end,
        update=function(self,dt) 
            -- update existing particles
            for i=#active_particles,1,-1 do
                local idx = active_particles[i]
                local ttl=pool[idx + VBO_TTL]
                ttl=ttl-dt
                if ttl<=0 then
                    pool:push(idx)
                    --active_particles[i]=nil
                    del(active_particles,i)
                else
                    for i=idx,idx+2 do
                        pool[VBO_X + i] = pool[VBO_X + i] + pool[VBO_VX + i]*dt
                    end
                    pool[idx + VBO_TTL] = ttl
                end
            end

            -- spawn new particles
            for emitter,owner in pairs(emitters) do
                local next_pos=v_clone(owner.origin)
                local params = emitter.params
                local count = emitter.count + params.rate*dt
                if count>1 then   
                    local n = flr(count)
                    for i=0,n-1 do
                        local pos=v_add(
                            v_lerp(emitter.origin,next_pos,i/n),
                            {
                               lerp(params.mins[1],params.maxs[1],rnd()),
                               lerp(params.mins[2],params.maxs[2],rnd()),
                               lerp(params.mins[3],params.maxs[3],rnd())
                            })
                        local p=pool:pop(
                            pos[1],pos[2],pos[3],
                            0,0,0,
                            lerp(params.ttl[1],params.ttl[2],rnd())
                        )
                        add(active_particles,p)
                    end
                    -- keep remainder
                    count = count%1                    
                end
                emitter.prev_origin = emitter.origin
                emitter.origin = next_pos
                emitter.count = count
            end
        end,
        render=function(self,cam,rectfill)
            for i=1,#active_particles do
                local idx=active_particles[i]
                local x,y,w=cam:project({
                    pool[idx + VBO_X],
                    pool[idx + VBO_Y],
                    pool[idx + VBO_Z]})
                if w>0 then
                    rectfill(x-1,y-1,x+1,y+1,w)
                end
            end
        end
    }
end
return particles