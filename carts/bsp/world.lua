local world={}
local maths3d = require("math3d")
local model = require("model")

-- p8 compat
local band=bit.band

-- init the root of the 2d BSP (for collision)
local _root=nil

function world.init(root)
    _root = root
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

function world.register(ent)
    local mins,maxs=ent.absmins,ent.absmaxs
    local c={
        0.5*(mins[1]+maxs[1]),
        0.5*(mins[2]+maxs[2]),
        0.5*(mins[3]+maxs[3])
    }
    -- extents
    local e=make_v(c, maxs)
    register_bbox(_root, ent, c, e)
end

-- returns all entities touching the given absolute box
function world.touches(absmins,absmaxs)
    local ents={}
    touches_bbox(_root, absmins, absmaxs, ents)
    return ents
end
return world