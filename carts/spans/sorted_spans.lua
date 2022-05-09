local flr=math.floor
function line(x0,y,x1,y,z)
    local t0,t1=flr(x0/10),flr(x1/10)
    local tabs=""
    for i=1,t0 do
        tabs=tabs.." "
    end
    local span=""
    for i=1,t1-t0 do
        span=span.."*"
    end
    if t1==t0 then
        span="."
    end
    print(tabs..(x0.." - "..x1.." z:"..z).."\n"..tabs..span)
end

--[[
local polys={
    {x0=0  , x1=165, zorder=0},
    {x0=126, x1=203, zorder=12},
    {x0=166, x1=396, zorder=9},
    {x0=204, x1=214, zorder=11},
    {x0=358, x1=359, zorder=10},
    {x0=360, x1=377, zorder=13},
    {x0=397, x1=479, zorder=3},
}
]]

local polys={
    {x0=0   , x1=36 , zorder=19},
    {x0=37  , x1=89 , zorder=22},
    {x0=90  , x1=143, zorder=12},
    {x0=136 , x1=145, zorder=4},
    {x0=146 , x1=197, zorder=10},
    {x0=150 , x1=195, zorder=20},
    {x0=196 , x1=202, zorder=21},
    {x0=198 , x1=232, zorder=13},
    {x0=203 , x1=406, zorder=17},
    {x0=378 , x1=420, zorder=6},
    {x0=407 , x1=479, zorder=0},
    {x0=407 , x1=412, zorder=9}
}
local _sorted_x,_sorted_spans={},{}
for i,poly in pairs(polys) do
    local x0,x1=poly.x0,poly.x1
    -- visible?
    if x0<480 and x1>=0 and x1>=x0 then
        local spans=_sorted_spans[x0]
        -- new?
        if not spans then
            -- capture starting point
            _sorted_x[#_sorted_x+1] = x0
            spans={}
        end
        -- add new span
        spans[#spans+1]=poly
        _sorted_spans[x0] = spans			
    end
end			
-- guard span?
if not _sorted_spans[479] then
    -- capture starting point
    _sorted_x[#_sorted_x+1] = 479
    -- add new span
    _sorted_spans[479] = {x0=479,x1=479,zorder=-1}			
end

-- pick first span
table.sort(_sorted_x)
local x,cur_z,cur_span=_sorted_x[1],-math.huge
-- anything to draw?
if x then
    local spans,last_x=_sorted_spans[x]
    local i,last_x=1,0
    local cur_z,cur_span=-math.huge
    while last_x<480 do
        -- no more active span
        -- find potential next span?
        local maxz,maxspan=cur_z
        for j=1,#_sorted_x do
            local x=_sorted_x[j]
            local spans=_sorted_spans[x]
            for k=1,#spans do
                local span=spans[k]
                local z=span.zorder
                if z>maxz and
                    span.x0<=last_x and
                    span.x1>=last_x and
                    span~=cur_span then
                    maxz=z
                    maxspan=span
                end
            end
        end
        -- guards against infinite loop
        if not maxspan then
            i = i + 1
            -- safeguard
            if i>#_sorted_x then break end            
            cur_z,cur_span=-math.huge
        else
            cur_z,cur_span = maxz,maxspan
            line(last_x,y,cur_span.x1,y,maxz)            
            last_x = cur_span.x1+1
        end
    end
end