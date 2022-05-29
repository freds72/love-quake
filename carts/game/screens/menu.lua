local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")

-- start menu screen/state
return function(conf, level)
    local menu,selected={
        "Start",
        "E1M1",
        "E1M3",
        "----------",
        "Options..."
    },0
    local actions={
        function()
            stateSystem:next(require("screens.play"),conf,"start.bsp")
        end,
        function()
            stateSystem:next(require("screens.play"),conf,"e1m1.bsp")
        end,
        function()
            stateSystem:next(require("screens.play"),conf,"e1m3.bsp")
        end,
        function()
            -- todo: open option menu
        end
    }

    -- load level
    local world = require("systems.world")
    world:load(level)

    return     
        -- update
        function()
            if input:pressed("up") then
                selected = selected - 1 
                if selected<0 then selected=#menu-1 end
            end
            if input:pressed("down") then
                selected = selected + 1 
                if selected==#menu then selected=0 end
            end    
            if input:pressed("action") then
                actions[selected + 1]()
            end
        end,
        -- draw
        function()            
            local x,y=200,120
            print("Small Quake",x,y,15)
            y = y + 9
            for i=1,#menu do
                local s=(i==selected+1) and ">" or " "
                print(s..menu[i],x,y+1,31)
                print(s..menu[i],x,y,15)
                y = y + 8
            end
        end
end
