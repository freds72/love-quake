local input_system=function(conf)
    -- convert configuration into key maps
    local scancodes={}
    for action,keys in pairs(conf.keys) do
        for _,k in pairs(keys) do
            scancodes[k]=action
        end
    end
    -- store current frame down actions
    local down_actions={}

    return {
        -- refresh input events
        update=function(self)
            -- clear previous state
            for k in pairs(down_actions) do
                down_actions[k]=nil
            end

            -- refresh
            for k,action in pairs(scancodes) do
                if love.keyboard.isScancodeDown(k) then
                    down_actions[action]=true
                end          
            end
        end,
        -- returns true if key has been pressed in frame
        is_down=function(self,action)
            return down_actions[action]~=nil
        end
    }
end
return input_system