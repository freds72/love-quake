-- persistent state between level load

-- private variables
-- default values
local state={}
local function reset(s)
    for k in pairs(s) do
        s[k]=nil
    end
    -- default values
    s.skill = 1
end
reset(state)
return setmetatable(
    state,
    {
        __index={
            reset=function(self)
                reset(state)
            end
        }
    })
