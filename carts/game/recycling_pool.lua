local recycling_pool=function(name,stride,size)
    local logging = require("logging")
    
    -- p8 compat
    local add,del=table.insert,table.remove

    size=size or 100
    local pool,free={},{}
    local function reserve()
        for i=1,size do
            -- "free" index
            add(free,#pool*stride+1)
            for j=1,stride do
                add(pool,0)
            end
        end
        logging.debug("pool:"..name.." - new pool#: "..#pool/stride)
    end
    return setmetatable({
        -- reserve an entry in pool
        pop=function(self,...)
            -- no more entries?
            if #free==0 then    
                reserve()
            end
            -- pick from the free list                
            local idx=del(free)
            local args={...}
            for i=0,#args-1 do
                pool[idx+i]=args[i+1]
            end
            return idx
        end,
        -- reclaim slot
        push=function(self,idx)
            add(free,idx)
        end,
        stats=function(self)   
            return "pool: "..name.." free: "..#free.." pool: "..#pool/stride
        end
    },{
        -- redirect get/set to underlying array
        __index=function(self,k)
            return pool[k]
        end,
        __newindex = function(self, key, value)
            pool[key] = value
        end
    })
end
return recycling_pool