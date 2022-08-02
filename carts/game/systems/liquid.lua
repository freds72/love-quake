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
        -- find current content (origin only)
        local node = bsp.locate(root,owner.origin)
        owner.contents = node.contents

        local water_level = node.contents<-2 and 1 or 0
        -- find "depth"
        if node.contents<-2 then
            for i=1,#params do
                local node = bsp.locate(root,v_add(owner.origin,{0,0,params[i]}))
                if node.contents>-2 then
                    break
                end
                water_level = i+1
            end
        end
        owner.water_level = water_level
    end
    return depth
end

-- register game component
_components["liquid"] = Liquid
return Liquid

