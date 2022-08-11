local bsp=require("bsp")
local world = require("systems.world")
local Liquid={}
-- set "water_level" and "contents" attributes to owner 
-- params: sorted array of depths
function Liquid:new(owner, params)
    -- get world BSP
    local root=world.level.model[1].hulls[1]

    local depth={}
    function depth:update()

        local origin = v_clone(owner.origin)
        local z = owner.origin[3]
        origin[3] = z + owner.mins[3] + 1
        -- find current content (origin only)
        local node = bsp.locate(root,origin)
        owner.contents = -1

        local water_level = 0
        -- find "depth"
        if node.contents<-2 then
            water_level = 1
            owner.contents = node.contents

            origin[3] = z + (owner.mins[3] + owner.maxs[3])*0.5
            node = bsp.locate(root,origin)
            if node.contents<-2 then
                water_level = 2

                origin[3] = z + owner.eyepos[3]
                node = bsp.locate(root,origin)
                if node.contents<-2 then
                    water_level = 3
                end
            end
        end
        owner.water_level = water_level
    end
    return depth
end

-- register game component
_components["liquid"] = Liquid
return Liquid

