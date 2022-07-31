local pool = require("engine.recycling_pool")("dynamic lights",1,64)
local active_lights={}
local DynamicLights=setmetatable({
    -- register a new light
    attach=function(self,light)
        local idx=pool:pop(light)
        active_lights[idx]=light
        return idx
    end,
    reset=function()
        active_lights = {}
        pool:reset()
    end,
    update=function() 
        local dt=1/60
        for idx,light in pairs(active_lights) do
            if light.free then
                pool:push(idx)
                active_lights[idx] = nil
            else
                light:update(dt)
            end
        end
    end,
    -- visitor
    -- parameter 1: light id
    -- parameter 2: light pos
    -- parameter 3: light radius
    visit=function(self,ent,fn,...)
        for idx,light in pairs(active_lights) do
            -- rebase light in entity space
            local origin=v_add(light.origin,ent.origin,-1)
            fn(idx,origin,light.radius,...)
        end
    end,
    get=function(self,k)
        return active_lights[k]
    end
    },{
        -- return active light based on unique id
        __index=function(self,k)
            assert(active_lights[k],"invalid light id: "..k)
            return active_lights[k]
        end
    })    

return DynamicLights