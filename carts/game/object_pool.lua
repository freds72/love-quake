local object_pool=function(name,size)
    local logging = require("logging")
    -- p8 compat
    local add,del=table.insert,table.remove
    local flr=math.floor

    size=size or 100
    local pool,cursor,total={},0,0
    local function reserve()
        for i=1,size do
            add(pool,{})
        end
        total = total + size
        logging.debug(name.." - new pool#: "..total.."("..#pool..")")
    end
    return setmetatable({
        -- reserve an entry in pool
        pop=function(self)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- reserve an entry            
            cursor = cursor + 1
            return cursor,pool[cursor]
        end,
        -- reclaim everything
        reset=function(self)
            cursor = 0
        end,
        stats=function(self)   
            return "pool:"..name.." free: "..(total-cursor).." size: "..#pool
        end
    },{
        -- redirect get/set to underlying array
        __index = function(self,k)
            return pool[k]
        end,
        __newindex = function(self, key, value)
            pool[key] = value
        end
    })
end
return object_pool