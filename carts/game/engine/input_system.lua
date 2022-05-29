local InputSystem={}
local conf = require("game_conf")

-- convert configuration into key maps
local scancodes={}
for action,keys in pairs(conf.keys) do
    for _,k in pairs(keys) do
        scancodes[k]=action
    end
end
-- store current frame down actions
local down_actions={}
local up_actions={}

-- refresh input events
function InputSystem:update()
    -- clear previous state
    for k in pairs(down_actions) do
        down_actions[k]=nil
    end
    for k in pairs(up_actions) do
        up_actions[k]=nil
    end

    -- refresh
    for k,action in pairs(scancodes) do
        if key(k) then down_actions[action]=true end
        if keyp(k) then up_actions[action]=true end
    end

    self.mx,self.my=mouse()
    self.mdx,self.mdy=dmouse()
end

-- returns true if key has been pressed in frame
function InputSystem:pressed(action)
    return down_actions[action]==true
end
function InputSystem:released(action)
    return up_actions[action]==true
end

return InputSystem