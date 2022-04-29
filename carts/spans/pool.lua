local PoolCls=function(name,stride,size)
    local logging = require("logging")
    -- p8 compat
    local add,del=table.insert,table.remove
    local flr=math.floor

    size=size or 100
    local pool,cursor,total={},0,0
    local function reserve()
        for i=1,size do
            for j=1,stride do
                add(pool,0)
            end
        end
        total = total + size
        logging.debug(name.." - new pool#: "..total.."("..#pool..")")
    end
    return setmetatable({
        -- reserve an entry in pool
        pop=function(self,...)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- init values
            local idx=cursor*stride
            cursor = cursor + 1
            local args={...}
            for i=1,#args do
                pool[idx+i]=args[i]
            end
            return idx+1
        end,
        pop5=function(self,a,b,c,d,e)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- init values
            local idx=cursor*stride+1
            cursor = cursor + 1
            pool[idx]  =a
            pool[idx+1]=b
            pool[idx+2]=c
            pool[idx+3]=d
            pool[idx+4]=e
            return idx
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
return PoolCls