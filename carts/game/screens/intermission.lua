local logging=require("engine.logging")
local input=require("engine.input_system")
local stateSystem = require("engine.state_system")

-- intermission screen
return function(world,level,secrets,total)

    return     
        -- update
        function()
            if input:released("action") then
                stateSystem:next("screens.play",level)
            end
        end,
        -- draw
        function()            
            local x,y=200,120
            print("Level Complete",x,y,15)
            if total>0 then                
                y = y + 9
                local s="Secrets found: "..secrets.."/"..total
                print(s,x,y+1,31)
                print(s,x,y,15)
            end
        end
end
