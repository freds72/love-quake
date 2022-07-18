local BlastEmitter={}
local particles = require("systems.particles")

-- create a new emitter
-- parameters:
-- radius: min/max range
-- gravity: gravity vector
-- ttl: particle min/max lifetime
-- speed: particle min/max velocity
function BlastEmitter:new(owner,params)
    local emitter={}
    local origin = v_clone(owner.origin)

    function emitter:update(pool,active_particles,dt)
        for i=1,50 do        
            local ttl=lerp(params.ttl[1],params.ttl[2],rnd())    
            local angle,speed=rnd(),lerp(params.speed[1],params.speed[2],rnd())
            local azimuth=cos(rnd())
            -- velocity direction
            local dir={azimuth*cos(angle),azimuth*sin(angle),azimuth}
            local pos=v_add(origin, dir, lerp(params.radius[1],params.radius[2],rnd()))
            local p=pool:pop(
                pos[1],pos[2],pos[3],
                speed*dir[1],speed*dir[2],speed*dir[3],
                ttl,
                ttl,
                params.ramp or 1,
                params.gravity_z or 0
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