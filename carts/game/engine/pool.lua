local PoolCls=function(name,stride,size)
    local ffi=require("ffi")
    local logging = require("engine.logging")

    local cursor,total=0,size*stride
    local pool=ffi.new("float[?]", total)
    local block_sz = ffi.sizeof("float[?]", stride)
    return setmetatable({
        -- reserve an entry in pool
        pop=function(self,...)
            -- init values
            local idx=cursor
            cursor = cursor + stride
            if cursor>=total then
                assert(false,"Pool: "..name.." full: "..cursor.."/"..total)
            end
            local n=select("#",...)
            for i=0,n-1 do
                pool[idx+i]=select(i+1,...)
            end
            return idx
        end,
        pop5=function(self,a,b,c,d,e)
            -- init values
            local idx=cursor
            cursor = cursor + stride
            if cursor>=total then
                assert(false,"Pool: "..name.." full: "..cursor.."/"..total)
            end
            pool[idx]  =a
            pool[idx+1]=b
            pool[idx+2]=c
            pool[idx+3]=d
            pool[idx+4]=e
            return idx
        end, 
        copy=function(self,src)
            -- init values
            local idx=cursor
            cursor = cursor + stride
            if cursor>=total then
                assert(false,"Pool: "..name.." full: "..cursor.."/"..total)
            end
            ffi.copy(pool + idx, src, block_sz)
            return idx
        end,
        ptr=function(self,offset)     
            return pool + offset
        end,
        -- reclaim everything
        reset=function(self)
            cursor = 0
        end,
        stats=function(self)   
            return "pool:"..name.." free: "..((total-cursor)/stride).." size: "..(total/stride)
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