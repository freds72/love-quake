local MenuState={}
local logging=require("logging")

-- handles console commands
local state={}
function state:pre_update()
    input:update()
end

function state:update()
end

function state:draw()
end

return MenuState