local bsp={}
-- BSP functions
local maths3d=require("engine.maths3d")

-- find node/leaf the given position is in
function bsp.locate(node,pos)
    while not node.contents do
        node=node[planes.isFront(node.plane,pos)]
    end
    return node
end

function bsp.tostring(node,depth)
    if not node then return end
    depth=depth or 0
    local s=""
    local coma=""
    if node.contents then
        s="\"content\":"..node.contents
        if #node>0 then
            s=s..",\"faces\":["
            local n
            for i=1,#node do
                local face=node[i]
                local x,y,z=planes.get(face.plane)
                local ns="["..x..", "..y..", "..z.."]"
                if n~=ns then
                    if n then
                        s=s..","
                    end
                    s=s..ns                    
                    n=ns
                end
            end
            s=s.."]"
        end
        coma=","
    end
    local left=bsp.tostring(node[true])
    if left then
        s=s..coma.."\"left\":"..left
        coma=","
    end
    local right=bsp.tostring(node[false])
    if right then
        s=s..coma.."\"right\":"..right
    end
    return "{"..s.."}"
end

-- collects all leaves within a radius
local function sphere_bsp_intersect(node,pos,radius,out)
    if node.contents then
        if node.contents~=-2 then
            -- printh("dist:"..dist.." faces:"..#node)
            out[node]={origin=pos,r=radius}
        end
        return
    end
  
    local dist,d=planes.dot(node.plane,pos)
    -- not touching plane
    if dist > d + radius then
        sphere_bsp_intersect(node[true],pos,radius,out)
        return
    end
    -- not touching plane (other side)
    if dist < d - radius then
        sphere_bsp_intersect(node[false],pos,radius,out)
        return
    end
    
    -- overlapping plane
    sphere_bsp_intersect(node[true],pos,radius,out)
    sphere_bsp_intersect(node[false],pos,radius,out)     
end

-- find all touching leaves within radius
function bsp.touches(node,pos,radius)
    local out={}
    sphere_bsp_intersect(node,pos,radius,out)
    return out
end

  -- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/WinQuake/world.c
  -- hull location
  -- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/QW/client/pmovetst.c
  -- https://developer.valvesoftware.com/wiki/BSP
  -- ray/bsp intersection
local function ray_bsp_intersect(node,p0,p1,t0,t1,out)
    local contents=node.contents  
    if contents then
        -- is "solid" space (bsp)
        if contents~=-2 then
            out.all_solid = false
            if contents==-1 then
                out.in_open = true
            else
                out.in_water = true
            end
        else
            out.start_solid = true
        end
        -- empty space
        return true
    end
    local dist,node_dist=planes.dot(node.plane,p0)
    local otherdist=planes.dot(node.plane,p1)
    local side,otherside=dist>node_dist,otherdist>node_dist
    if side==otherside then
        -- go down this side
        return ray_bsp_intersect(node[side],p0,p1,t0,t1,out)
    end
    -- crossing a node
    local t=dist-node_dist
    if t<0 then
        t=t-0.03125
    else
        t=t+0.03125
    end  
    -- cliping fraction
    local frac=mid(t/(dist-otherdist),0,1)
    local tmid,pmid=lerp(t0,t1,frac),v_lerp(p0,p1,frac)
    if not ray_bsp_intersect(node[side],p0,pmid,t0,tmid,out) then
        return
    end

    if bsp.locate(node[not side],pmid).contents ~= -2 then
        return ray_bsp_intersect(node[not side],pmid,p1,tmid,t1,out)
    end

    -- never got out of the solid area
    if out.all_solid then
        return
    end

    local scale=side and 1 or -1
    local nx,ny,nz=planes.get(node.plane)
    out.n = {scale*nx,scale*ny,scale*nz,node_dist}
    out.t = tmid
    out.pos = pmid
end

-- ray/bsp intersection
function bsp.intersect(node,p0,p1,out)
    return ray_bsp_intersect(node,p0,p1,0,1,out)
end

-- find first straddling node of the given bounding box
function bsp.firstNode(node,ent)
    local mins,maxs=ent.absmins,ent.absmaxs
    local c={
        0.5*(mins[1]+maxs[1]),
        0.5*(mins[2]+maxs[2]),
        0.5*(mins[3]+maxs[3])
    }
    -- extents
    local e=make_v(c, maxs)
    while not node.contents do
        -- find first stradling plane
        local sides=planes.classifyBBox(node.plane,c,e)
        if sides==3 then
            return node,count
        end
        if band(sides,1)~=0 then
            node=node[false]
        end
        if band(sides,2)~=0 then
            node=node[true]
        end
    end
end

return bsp