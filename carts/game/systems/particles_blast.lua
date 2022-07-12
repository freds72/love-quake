local BlastEmitter={}
local particles = require("systems.particles")

-- create a new emitter
function BlastEmitter:new(owner,params)
    local emitter={}
    local gravity = params.gravity or {0,0,0} 
    local mins,maxs = v_add(owner.origin,params.mins), v_add(owner.origin,params.maxs)

    function emitter:update(pool,active_particles,dt)
        for i=1,50 do        
            local pos=v_lerp(mins,maxs,rnd())
            local ttl=lerp(params.ttl[1],params.ttl[2],rnd())    
            local angle,speed=rnd(),lerp(params.speed[1],params.speed[2],rnd())
            local azimuth=cos(rnd())
            local p=pool:pop(
                pos[1],pos[2],pos[3],
                azimuth*speed*cos(angle),azimuth*speed*sin(angle),azimuth*speed+gravity[3],
                ttl,
                ttl,
                params.ramp or 1
            )
            add(active_particles,p)
        end
        -- kill emitter
        emitter.free = true
    end

    -- register to main system
    particles:attach(emitter)

    -- todo: return opaque ID
    return emitter
end

-- register to component table
_components["blast"] = BlastEmitter

return BlastEmitter