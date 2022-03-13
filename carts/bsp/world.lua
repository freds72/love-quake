local world={}
local maths3d = require("math3d")

-- p8 compat
local band=bit.band

-- init the root of the 2d BSP (for collision)
function world.init(model)
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

function world.register(node, ent)
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
    local sides = plane_classify_bbox(node.plane, ent.absmins, ent.absmaxs)
	-- sides or straddling?
    if band(sides,1)>0 then
        world.register(node[false], ent)
    end
    if band(sides,2)>0 then
        world.register(node[true], ent)
    end
end
return world