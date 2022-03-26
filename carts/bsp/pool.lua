local PoolCls=function(stride,size)
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
        print("new pool#: "..total.."("..#pool..")")
    end
    local function vargs_copy(idx,value,...)
        if not value then
            return
        end
        pool[idx] = value
        vargs_copy(idx+1,...)
    end
    return setmetatable({
        -- reserve an entry in pool
        pop=function(self,...)
            -- no more entries?
            if cursor==total then    
                reserve()
            end
            -- init values
            local idx=cursor*stride+1
            cursor = cursor + 1
            vargs_copy(idx,...)
            return idx
        end,
        -- reclaim everything
        reset=function(self)
            cursor = 0
        end,
        stats=function(self)   
            return "free: "..(total-cursor).." pool: "..#pool/stride
        end
    },{
        __index=function(self,k)
            return pool[k]
        end,
        __newindex = function(self, key, value)
            pool[key] = value
        end
    })
end
return PoolCls