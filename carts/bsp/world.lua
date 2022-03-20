local world={}
local maths3d = require("math3d")
local modelfs = require("modelfs")

-- p8 compat
local band=bit.band
local add=table.insert

-- init the root of the 2d BSP (for collision)
local _level,_root
-- collision map (2d)
local _map

function create_map(mins,maxs,depth)
    if depth>4 then
        return
    end
    local size,left,right,fn=make_v(mins,maxs)

    if size[1]>size[2] then
        local dist=mins[1]+0.5*size[1]
        left={dist,maxs[2],maxs[3]}
        right={dist,mins[2],mins[3]}
        fn=function(mins,maxs)
            -- Compute the projection interval radius of b onto L(t) = b.c + t * p.n
            local c = 0.5*(mins[1]+maxs[1])
            local r = maxs[1]-c
        
            -- Compute distance of box center from plane
            local s = c - dist
        
            -- Intersection occurs when distance s falls within [-r,+r] interval
            if s<=-r then
                return 1
            elseif s>=r then
                return 2
            end
            return 3              
        end
    else
        local dist=mins[2]+0.5*size[2]        
        left={maxs[1],dist,maxs[3]}
        right={mins[1],dist,mins[3]}
        fn=function(mins,maxs)
            -- Compute the projection interval radius of b onto L(t) = b.c + t * p.n
            local c = 0.5*(mins[2]+maxs[2])
            local r = maxs[2]-c
        
            -- Compute distance of box center from plane
            local s = c - dist
        
            -- Intersection occurs when distance s falls within [-r,+r] interval
            if s<=-r then
                return 1
            elseif s>=r then
                return 2
            end
            return 3              
        end
    end
    
    return     
    {
        classify=fn,
        ents={},
        depth=depth,
        -- debug
        mins=mins,
        maxs=maxs,
        [false]=create_map(mins,left,depth+1),        
        [true]=create_map(right,maxs,depth+1)
    }
end

function world.init(level)
    _level = level
    _root = level.hulls[1]

    -- init the 2d bsp

    _map = create_map(level.mins,level.maxs,0)      
end

-- teleport entity to specified position
function world.set_origin(ent,pos)    
    ent.origin=v_clone(pos)    
    m_set_pos(ent.m,pos)
    world.register(ent)
end

function world.set_size(ent,mins,maxs)
end


local function get_collidables(ent)
end

function world.move(ent)
    -- player move
    -- query player position (water/ground/...)
    local origin = v_add(_player.origin, make_v(player_mins, _player.mins))
    local pmove = {
        origin = origin,
        velocity = v_clone(_player.velocity),
        angles = v_clone(_player.angles),
        physents = {_world.model},
        mins = v_add(origin, {-256,-256,-256}),
        maxs = v_add(origin, {256,256,256})
    }

    -- collect all physical entities during the move
    local blocking={
        world
    }
    query_entities(pmove, blocking)


    --  
    for i=1,#touchables do
        local other=touchables[i]
        if other.touch then
            --             
        end
    end
end

function world.touch(ent)
end

function world.unregister(ent)
    -- nothing to unregister
    if ent.nodes then
        return
    end
    for node,_ in pairs(ent.nodes) do
        if node.ents then
            node.ents[ent]=nil
        end
    end
end

local function register_bbox(node, ent, pos, size)    
    if not node or node.contents==-2 then
        return
    end

    -- any non solid content
    if node.contents then
        -- entity -> leaf
        ent.nodes[node]=true
        -- leaf -> entity
        if not node.ents then
            node.ents={}
        end
        node.ents[ent]=true
        return
    end

    -- classify box
    local sides = plane_classify_bbox(node.plane, pos, size)
	-- sides or straddling?
    if band(sides,1)>0 then
        register_bbox(node[false], ent, pos, size)
    end
    if band(sides,2)>0 then
        register_bbox(node[true], ent, pos, size)
    end
end

local function touches_bbox(node, pos, size, out)    
    if not node or node.contents==-2 then
        return
    end

    -- any non solid content
    if node.contents then        
        if node.ents then
            for ent,_ in pairs(node.ents) do
                out[ent]=true
            end
        end
        return
    end

    -- classify box
    local sides = plane_classify_bbox(node.plane, pos, size)
	-- sides or straddling?
    if band(sides,1)>0 then
        touches_bbox(node[false], pos, size, out)
    end
    if band(sides,2)>0 then
        touches_bbox(node[true], pos, size, out)
    end    
end

local function register_map(cell, ent)
    local sides = cell.classify(ent.absmins, ent.absmaxs)
    if sides==3 or cell.depth==4 then
        -- stradling? register in current cell
        cell.ents[ent]=true
        ent.cell=cell
        return
    end
    local side=band(sides,2)~=0
    register_map(cell[side], ent)
end


function world.register(ent)
    if not ent.DRAW_NOT then
        local mins,maxs=ent.absmins,ent.absmaxs
        local c={
            0.5*(mins[1]+maxs[1]),
            0.5*(mins[2]+maxs[2]),
            0.5*(mins[3]+maxs[3])
        }
        -- extents
        local e=make_v(c, maxs)
        -- register to lowler
        register_bbox(_root, ent, c, e)
    end

    -- register to 2d map
    register_map(_map, ent)
end

-- returns all entities touching the given absolute box
function world.touches(mins,maxs)
    local ents = {}
    local x0,y0,z0,x1,y1,z1=mins[1],mins[2],mins[3],maxs[1],maxs[2],maxs[3]
    local function touches_map(cell)
        if not cell then
            return
        end
        -- collect current cell items
        for e,_ in pairs(cell.ents) do
            -- touching?
            if x0<=e.absmaxs[1] and x1>=e.absmins[1] and
               y0<=e.absmaxs[2] and y1>=e.absmins[2] and
               z0<=e.absmaxs[3] and z1>=e.absmins[3] then               
                add(ents,e)
            end
        end
    
        -- visit touching cells
        local sides = cell.classify(mins, maxs)
        if band(sides,1)~=0 then
            touches_map(cell[false])
        end
        if band(sides,2)~=0 then
            touches_map(cell[true])
        end
    end
    touches_map(_map)
    return ents
end

function world.get_map()
    return _map
end

return world