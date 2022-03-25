local add,del=table.insert,table.remove
local rnd,flr=love.math.random,math.floor

local lg = love.graphics
local lm = love.math

local mid=function(x,a,b)
    return math.min(b,math.max(x,a))
end

local PoolCls=function(stride,size)
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
    end
    return setmetatable({
        -- reserve an entry in pool
        pop=function()
            -- no more entries?
            if #free==0 then    
                reserve()
                print("expand reserve: "..#pool/6)        
            end
            -- pick from the free list                
            local idx=del(free)
            return idx
        end,
        -- reclaim slot
        push=function(self,idx)
            add(free,idx)
        end,
        stats=function(self)   
            return "free: "..#free.." pool: "..#pool/6
        end
    },{
        __index=function(self,k)
            return pool[k]
        end
    })
end

local ParticleSystemCls=function(size)
    local pool=PoolCls(6)
    -- 
    local particles,ttl={},-1
    return {
        spawn=function(self,x,y)
            -- get from pool
            local idx=pool:pop()
            pool[idx+0] = x
            pool[idx+1] = y
            pool[idx+2] = rnd()
            local angle = 2*3.1415*rnd()
            pool[idx+3] = math.cos(angle)
            pool[idx+4] = math.sin(angle)
            pool[idx+5] = 30+60*rnd()
            -- reference
            particles[idx]=true
        end,
        update=function(self)
            if ttl<love.frame then
                for i=1,3 do
                    self:spawn(512*rnd(),512*rnd())
                end
                ttl = love.frame + 2*rnd()
            end
            for idx in pairs(particles) do
                local ttl=pool[idx+5]
                ttl = ttl - 1
                if ttl<0 then
                    -- reclaim pool entry
                    pool:push(idx)
                    particles[idx] = nil
                else
                    local x,y=pool[idx+0],pool[idx+1]
                    x = x + pool[idx+3]   
                    y = y + pool[idx+4]
                    if x<0 or x>512 then
                        x=mid(x,0,512)
                        pool[idx+3] = -pool[idx+3]
                    end
                    if y<0 or y>512 then
                        y=mid(y,0,512)
                        pool[idx+4] = -pool[idx+4]
                    end

                    pool[idx+0] = x
                    pool[idx+1] = y
                    pool[idx+5] = ttl
                end
            end
        end,
        draw=function(self) 
            love.graphics.print(pool:stats(),2,2)
            for idx in pairs(particles) do
                local r=60/(30+pool[idx+5])
                lg.circle(
                    "line",
                    pool[idx]-r/2,
                    pool[idx+1]-r/2,
                    r)
            end
        end
    }
end

local _ps=ParticleSystemCls()

function love.load()
    love.frame = 0
end

function love.update()
    _ps:update()

    love.frame = love.frame + 1
end

function love.draw()
    lg.clear()
    _ps:draw()

    love.graphics.print("gc:"..flr(collectgarbage("count")),2,16)

end