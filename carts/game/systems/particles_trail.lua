local TrailEmitter={}
local particles = require("systems.particles")

-- create a new emitter
function TrailEmitter:new(owner,params)
    local count = 0
    local emitter={}
    local origin=v_clone(owner.origin)
    local gravity = params.gravity or {0,0,0} 
    local mins,maxs = params.mins, params.maxs

    function emitter:update(pool,active_particles,dt)
        -- kill emitter if owner is dead
        if owner.free then
            emitter.free = true
            return
        end

        local next_pos=v_clone(owner.origin)
        count = count + params.rate*dt                            
        if count>1 then  
            local n = flr(count)
            for i=0,n-1 do
                local pos=v_add(
                    v_lerp(origin,next_pos,i/n),
                    {
                        lerp(mins[1],maxs[1],rnd()),
                        lerp(mins[2],maxs[2],rnd()),
                        lerp(mins[3],maxs[3],rnd())
                    })
                local ttl=lerp(params.ttl[1],params.ttl[2],rnd())                        
                local p=pool:pop(
                    pos[1],pos[2],pos[3],
                    gravity[1],gravity[2],gravity[3],
                    ttl,
                    ttl,
                    params.ramp or 1
                )
                add(active_particles,p)
            end
            -- keep remainder
            count = count%1                    
        end
        origin = next_pos
    end

    -- register to main system
    particles:attach(emitter)

    -- todo: return opaque ID
    return emitter
end

-- register to component table
_components["trail"] = TrailEmitter

return TrailEmitter