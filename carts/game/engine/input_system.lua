local InputSystem={}
local input = require("platform").input
local conf = require("engine.conf")

-- convert configuration into key maps
local scancodes={}
for action,keys in pairs(conf.keys) do
    for _,k in pairs(keys) do
        scancodes[k]=action
    end
end
-- store current frame down actions
local down_actions={}

-- refresh input events
function InputSystem:update()
    -- clear previous state
    for k in pairs(down_actions) do
        down_actions[k]=nil
    end

    -- refresh
    for k,action in pairs(scancodes) do
        if input:isScancodeDown(k) then
            down_actions[action]=true
        end          
    end
end

-- returns true if key has been pressed in frame
function InputSystem:btnp(action)
    return down_actions[action]~=nil
end

return InputSystem