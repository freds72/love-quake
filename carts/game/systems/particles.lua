-- Particles system
local emitters={}
local pool = require("engine.recycling_pool")("particles",9,2500)
local active_particles = {}
local ramp_styles = require("systems.rampstyles")

-- layout
local VBO_X=0
local VBO_Y=1
local VBO_Z=2
local VBO_VX=3
local VBO_VY=4
local VBO_VZ=5
local VBO_TTL=6
local VBO_MAXTTL=7
local VBO_RAMP=8

local ParticleSystem={
    -- attach emitter to particle system
    attach=function(self,emitter)
        emitters[emitter] = true
    end,
    reset=function(self)
        for k in pairs(emitters) do
            emitters[k] = nil
        end
        active_particles = {}
        pool:reset()
    end,
    update=function(self) 
        local dt=1/60
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
            if emitter.free then
                emitters[emitter] = nil
            else
                emitter:update(pool, active_particles, 1/60)
            end
        end
    end,
    draw=function(self,rasterizer,cam)
        for i=1,#active_particles do
            local idx=active_particles[i]
            local x,y,w=cam:project({
                pool[idx + VBO_X],
                pool[idx + VBO_Y],
                pool[idx + VBO_Z]})
            if w>0 then
                local t=1-pool[idx + VBO_TTL]/pool[idx + VBO_MAXTTL]
                -- ensure particles are always visible
                local r,ramp=max(1,w*128),ramp_styles:get(pool[idx + VBO_RAMP])
                rasterizer.addQuad(x-r,y-r,x+r,y+r-1,w,ramp[min(flr(#ramp*t)+1,#ramp)])
            end
        end
    end
}

return ParticleSystem