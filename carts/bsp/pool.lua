local PoolCls=function(stride,size)
    -- p8 compat
    local add,del=table.insert,table.remove
    local flr=math.floor

    size=size or 100
    local pool,free,total={},{},0
    local function reserve()
        for i=1,size do
            -- "free" index
            add(free,#pool+1)
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
            if #free==0 then    
                reserve()
            end
            -- pick from the free list                
            local idx=del(free)
            -- init values
            vargs_copy(idx,...)
            return idx
        end,
        -- reclaim everything
        reset=function(self)
            for i=1,total do
                free[i]=(i-1)*stride + 1
            end
        end,
        -- reclaim slot
        push=function(self,idx)
            add(free,idx)
        end,
        stats=function(self)   
            return "free: "..#free.." pool: "..#pool/stride
        end
    },{
        __index=function(self,k)
            return pool[k]
        end,
        __newindex = function(self, key, value)
            pool [key] = value
        end
    })
end
return PoolCls