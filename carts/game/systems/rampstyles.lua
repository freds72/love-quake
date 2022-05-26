local RampStylesSystem={}
local ramp_styles={}
function RampStylesSystem:set(id, ramp)
    ramp_styles[id] = ramp
end
return RampStylesSystem