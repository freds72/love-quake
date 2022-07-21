local FollowLight={}
local lights=require("systems.dynamic_lights")

-- create a new light
-- parameters:
-- radius: min/max range (to be used to create a blinking light for ex.)
-- ttl: lifetime (range, optional) 
function FollowLight:new(owner,params)
    local ttl = params.ttl and time() + lerp(params.ttl[1],params.ttl[2],rnd())
    local radius = lerp(params.radius[1],params.radius[2],rnd())
    local light = {radius=radius, origin=owner.origin}
    
    function light:update(dt)
        if owner.free then
            self.free=true
            return
        end
        if ttl and time()>ttl then
            self.radius = 0
            self.free=true
            return
        end

        local next_radius = lerp(params.radius[1],params.radius[2],rnd())
        -- 0.8 per frame
        radius=lerp(radius, next_radius, 48 * dt)
        -- track owner
        self.origin = owner.origin
        self.radius = radius
    end

    -- register to main system
    return lights:attach(light)
end

-- register to component table
_components["light"] = FollowLight

return FollowLight