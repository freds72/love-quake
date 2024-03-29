local PlanePool=function()
    local _planes,_box_hull={}
    -- shared content leaves
    local content_types={}
    for i=1,6 do
        -- -1: ordinary leaf
        -- -2: the leaf is entirely inside a solid (nothing is displayed).
        -- -3: Water, the vision is troubled.
        -- -4: Slime, green acid that hurts the player.
        -- -5: Lava, vision turns red and the player is badly hurt.   
        -- -6: sky 
        add(content_types,{contents=-i})
    end  

    -- temp hull for slidebox
    local function initHull()
        local box_clipnodes={}
        for i=0,5 do
            local side,type = band(i,1)==0,shr(i,1)
            local n={0,0,0}
            -- set vector
            n[type+1]=1

            local clipnode={
                plane = planes.pop(n,-1,type)
            }
            clipnode[side] = -1
            if i ~= 5 then
                clipnode[not side] = i + 1
            else
                clipnode[not side] = -2
            end
            -- register
            box_clipnodes[i] = clipnode
        end

        -- attach
        for _,node in pairs(box_clipnodes) do
            local function attach_node(side)
                local id=node[side]
                node[side]=id<0 and content_types[-id] or box_clipnodes[id]
            end
            attach_node(true)
            attach_node(false)
        end
        return box_clipnodes
    end

    return {
        -- reserve an entry in pool
        pop=function(v,d,t)
            -- init values
            local idx=#_planes+1
            _planes[idx  ]=v[1]
            _planes[idx+1]=v[2]
            _planes[idx+2]=v[3]
            -- distance
            _planes[idx+3]=d
            -- type
            _planes[idx+4]=t
            return idx
        end,  
        -- reclaim the pool 
        reset=function()     
            for k in pairs(_planes) do
                _planes[k]=nil
            end
        end,
        -- returns the "next" plane id
        offset=function()
            return #_planes+1
        end,
        -- planes functions (globals)
        get=function(pi)
            return _planes[pi],_planes[pi+1],_planes[pi+2]
        end,
        dot=function(pi,v)
            local t=_planes[pi+4]
            if t<3 then    
                return _planes[pi+t]*v[t+1],_planes[pi+3]
            end
            return _planes[pi]*v[1]+_planes[pi+1]*v[2]+_planes[pi+2]*v[3],_planes[pi+3]
        end,
        isFront=function(pi,v)
            local t=_planes[pi+4]
            if t<3 then                 
                return _planes[pi+t]*v[t+1]>_planes[pi+3]
            end
            return _planes[pi]*v[1]+_planes[pi+1]*v[2]+_planes[pi+2]*v[3]>_planes[pi+3]
        end,
        -- mins/maxs must be absolute corners
        classifyBBox=function(pi,c,e)
            -- cf: https://gdbooks.gitbooks.io/3dcollisions/content/Chapter2/static_aabb_plane.html

            local t,s,r=_planes[pi+4]
            if t<3 then
                local n=_planes[pi+t]
                r = e[t+1]*abs(n)
            
                -- Compute distance of box center from plane
                s = n*c[t+1] - _planes[pi+3]            
            else
                -- Compute the projection interval radius of b onto L(t) = b.c + t * p.n
                local nx,ny,nz=_planes[pi],_planes[pi+1],_planes[pi+2]
                r = e[1]*abs(nx) + e[2]*abs(ny) + e[3]*abs(nz)
            
                -- Compute distance of box center from plane
                s = nx*c[1]+ny*c[2]+nz*c[3] - _planes[pi+3]
            end
            -- Intersection occurs when distance s falls within [-r,+r] interval
            if s<=-r then
                return 1
            elseif s>=r then
                return 2
            end
            return 3  
        end,
        makeHull=function(mins,maxs)
            if not _box_hull then
                _box_hull = initHull()
            end
            _planes[_box_hull[0].plane + 3] = maxs[1]
            _planes[_box_hull[1].plane + 3] = mins[1]
            _planes[_box_hull[2].plane + 3] = maxs[2]
            _planes[_box_hull[3].plane + 3] = mins[2]
            _planes[_box_hull[4].plane + 3] = maxs[3]
            _planes[_box_hull[5].plane + 3] = mins[3]
    
            -- returns top node
            return _box_hull[0]
        end    
    }
end
return PlanePool