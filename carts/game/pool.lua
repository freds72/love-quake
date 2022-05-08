local PoolCls=function(name,stride,size)
    local ffi=require("ffi")
    local logging = require("logging")
    -- p8 compat
    local add,del=table.insert,table.remove
    local flr=math.floor

    size=size or 100
    local pool,cursor,total={},0,0
    local function reserve()
        assert(total==0,"cannot expand ffi pool")
        pool = ffi.new("float[?]", size*stride)
        total = total + size
        logging.debug(name.." - new pool#: "..total.."("..stride*size..")")
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
            local n=select("#",...)
            for i=0,n-1 do
                pool[idx+i]=select(i+1,...)
            end
            return idx
        end,
        pop5=function(self,a,b,c,d,e)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- init values
            local idx=cursor*stride
            cursor = cursor + 1
            pool[idx]  =a
            pool[idx+1]=b
            pool[idx+2]=c
            pool[idx+3]=d
            pool[idx+4]=e
            return idx
        end,
        pop6=function(self,a,b,c,d,e,f)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- init values
            local idx=cursor*stride
            cursor = cursor + 1
            pool[idx]  =a
            pool[idx+1]=b
            pool[idx+2]=c
            pool[idx+3]=d
            pool[idx+4]=e
            pool[idx+5]=f
            return idx
        end,       
        -- reclaim everything
        reset=function(self)
            cursor = 0
        end,
        stats=function(self)   
            return "pool:"..name.." free: "..(total-cursor).." size: "..(stride*size)
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