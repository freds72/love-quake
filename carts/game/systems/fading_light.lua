local FadingLight={}
local lights=require("systems.dynamic_lights")

-- create a new light that will last the given ttl and decrease radius linearly
-- parameters:
-- radius: radius (range)
-- ttl: lifetime (range) 
function FadingLight:new(owner,params)
    local duration = lerp(params.ttl[1],params.ttl[2],rnd())
    local ttl = time() + duration
    local radius = lerp(params.radius[1],params.radius[2],rnd())
    local light = {radius=radius, origin=owner.origin}
    
    function light:update(dt)
        if time()>ttl then
            self.radius = 0
            self.free=true
            return
        end

        -- 0.8 per frame
        local r=lerp(0,radius, (ttl-time())/duration)
        -- track owner
        self.radius = r
    end

    -- register to main system
    return lights:attach(light)
end

-- register to component table
_components["fadinglight"] = FadingLight

return FadingLight