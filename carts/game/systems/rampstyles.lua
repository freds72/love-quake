local RampStylesSystem={}
local ramps={}
function RampStylesSystem:set(id,map)
    ramps[id] = map
end
function RampStylesSystem:get(id)
    return ramps[id]
end
return RampStylesSystem