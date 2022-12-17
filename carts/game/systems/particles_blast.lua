local BlastEmitter={}
local particles = require("systems.particles")

-- create a new emitter
-- parameters:
-- radius: min/max range
-- gravity: gravity vector
-- ttl: particle min/max lifetime
-- speed: particle min/max velocity
-- count: [optional] number of particles to spawn (default: 50)
function BlastEmitter:new(owner,params)
    local emitter={}
    local origin = v_clone(owner.origin)

    local radius0,radius1=unpack(params.radius)
    local ttl0,ttl1=unpack(params.ttl)
    local speed0,speed1=unpack(params.speed)
    function emitter:update(pool,active_particles,dt)
        for i=1,params.count or 50 do        
            local ttl=lerp(ttl0,ttl1,rnd())    
            local angle,speed=rnd(),lerp(speed0,speed1,rnd())
            local azimuth=rnd()
            -- velocity direction
            local dir={sin(azimuth)*cos(angle),sin(azimuth)*sin(angle),cos(azimuth)}
            local pos=v_add(origin, dir, lerp(radius0,radius1,rnd()))
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