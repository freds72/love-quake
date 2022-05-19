local Input={}
local lk=love.input
function Input.isScancodeDown(k)
    return lk.isScancodeDown(k)
end
return Input