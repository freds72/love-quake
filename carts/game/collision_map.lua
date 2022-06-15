local maths3d = require("engine.maths3d")
local bsp = require("bsp")
local CollisionMap=function(world)
    local level = world.level.model[1]
    -- init the root of the 2d BSP (for collision)
    local _root
    -- collision map (2d)
    local _map

    local function create_map(mins,maxs,depth)
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

    local function register_bbox(node, ent, pos, size)    
        if node.contents==-2 then
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
        local sides = planes.classifyBBox(node.plane, pos, size)
        -- sides or straddling?
        if band(sides,1)~=0 then
            register_bbox(node[false], ent, pos, size)
        end
        if band(sides,2)~=0 then
            register_bbox(node[true], ent, pos, size)
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

    -- query helper
    local touch_query={ 
        ents = {},
        find=function(self,cell,mins,maxs,filter)
            if not cell then
                return
            end
            -- collect current cell items
            local x0,y0,z0,x1,y1,z1=mins[1],mins[2],mins[3],maxs[1],maxs[2],maxs[3]    
            for e,_ in pairs(cell.ents) do
                if e~=filter then
                    -- touching?
                    if x0<=e.absmaxs[1] and x1>=e.absmins[1] and
                    y0<=e.absmaxs[2] and y1>=e.absmins[2] and
                    z0<=e.absmaxs[3] and z1>=e.absmins[3] then
                        add(self.ents,e)
                    end
                end
            end
    
            -- visit touching cells
            local sides = cell.classify(mins, maxs)
            if band(sides,1)~=0 then
                self:find(cell[false],mins,maxs,filter)
            end
            if band(sides,2)~=0 then
                self:find(cell[true],mins,maxs,filter)
            end
        end
    }

    -- public api
    local this={}
    _root = level.hulls[1]

    -- init the 2d bsp

    _map = create_map(level.mins,level.maxs,0)      

    -- teleport entity to specified position
    function this:set_origin(ent,pos)    
        ent.origin=v_clone(pos)    
        m_set_pos(ent.m,pos)
        self:register(ent)
    end

    function this:set_size(ent,mins,maxs)
    end    

    function this:unregister(ent)
        -- nothing to unregister
        if not ent.nodes then
            return
        end
        for node,_ in pairs(ent.nodes) do
            if node.ents then
                node.ents[ent]=nil
            end
            ent.nodes[node] = nil
        end    
    end

    function this:register(ent)
        -- unlink first
        self:unregister(ent)

        if not ent.DRAW_NOT then
            local mins,maxs=ent.absmins,ent.absmaxs
            local c={
                0.5*(mins[1]+maxs[1]),
                0.5*(mins[2]+maxs[2]),
                0.5*(mins[3]+maxs[3])
            }
            -- extents
            local e=make_v(c, maxs)
            -- register in visible world
            register_bbox(_root, ent, c, e)

            -- find current content (origin only)
            local node = bsp.locate(_root,ent.origin)
            ent.contents = node.contents
        end

        -- register to 2d map
        register_map(_map, ent)
    end

    -- returns all entities touching the given absolute box

    function this:touches(mins,maxs,filter)
        -- always add world
        touch_query.ents = {world.entities[1]}
        touch_query:find(_map,mins,maxs,filter)
        return touch_query.ents
    end

    function this:get_map()
        return _map
    end

    -- returns first hit along a ray
    -- note: world is an entity like any other (sort of!)
    function this:hitscan(mins,maxs,p0,p1,triggers,ents,ignore_ent)
        local size=make_v(mins,maxs)
        local radius=max(size[1],size[2])
        -- pick the right collision enveloppe
        local hull_type = 1
        if radius>=64 then
            hull_type = 3
        elseif radius>=32 then
            hull_type = 2
        end

        -- collect triggers
        local hits
        for k=1,#ents do
            local other_ent = ents[k]
            -- skip "hollow" entities
            if not (other_ent.SOLID_NOT or ignore_ent==other_ent or triggers[other_ent]) then
                -- convert into model's space (mostly zero except moving brushes)
                local model,hull=other_ent.model
                if not model or not model.hulls then
                    -- use local aabb - hit is computed in ent space
                    hull = planes.makeHull(make_v(maxs,other_ent.mins),make_v(mins,other_ent.maxs))
                else
                    hull = model.hulls[hull_type]
                end
                
                local tmphits={
                    t=1,
                    all_solid=true,
                    ent=other_ent
                } 
                -- rebase ray in entity origin
                bsp.intersect(hull,make_v(other_ent.origin,p0),make_v(other_ent.origin,p1),tmphits)

                -- "invalid" location
                if tmphits.start_solid or tmphits.all_solid then
                    if not other_ent.SOLID_TRIGGER then
                        return tmphits
                    end
                    -- damage or other actions
                    triggers[other_ent] = true
                end

                if tmphits.n then
                    -- closest hit?
                    -- printh(other_ent.classname.." @ "..tmphits.t)
                    if other_ent.SOLID_TRIGGER then
                        -- damage or other actions
                        triggers[other_ent] = true
                    elseif tmphits.t<(hits and hits.t or 32000) then
                        hits = tmphits
                    end
                end
            end
        end  
        return hits
    end

    -- slide on wall move (players, npc...)
    function this:slide(ent,origin,velocity)
        local vel2d = {velocity[1],velocity[2],0}
        local vl = v_len(vel2d)
        local vl0 = vl
        local next_pos=v_add(origin,velocity)
        local on_ground,blocked = false,false
        local invalid=false
    
        -- avoid touching the same non-solid multiple times (ex: triggers)
        local touched = {}
        -- collect all potential touching entities (done only once)
        -- todo: smaller box
        local ents=self:touches(v_add(ent.absmins,{-256,-256,-256}), v_add(ent.absmaxs,{256,256,256}),ent)
        -- check current to target pos
        for i=1,4 do
            local hits = self:hitscan(ent.mins,ent.maxs,origin,next_pos,touched,ents)
            if not hits then
                goto clear
            end
            if hits.n then            
                local fix=v_dot(hits.n,velocity)
                -- not separating?
                if fix<0 then  
                    vl = vl + v_dot(vel2d,hits.n)
                    local old_vel = v_clone(velocity)
                    velocity=v_add(velocity,hits.n,-fix)
                    -- print("fix pos:"..fix.." before: "..v_tostring(old_vel).." after: "..v_tostring(velocity))      
                    -- floor?
                    if hits.n[3]>0.7 then
                        on_ground=true
                    end
                    -- wall hit?
                    if not hits.ent.SOLID_SLIDEBOX and hits.n[3]==0 then
                        blocked=true
                    end
                end
                next_pos=v_add(origin,velocity)
            end
        end
    ::blocked::
        invalid = true
        velocity={0,0,0}
    ::clear::
    
        return {
            pos=v_add(origin,velocity),
            velocity=velocity,
            on_ground=on_ground,
            on_wall=blocked,
            fraction=max(0,vl/vl0),
            touched=touched,
            invalid=invalid}
    end
    
    -- missile type move (no course correction)
    function this:fly(ent,origin,velocity)
        local next_pos=v_add(origin,velocity)
        local invalid,hit_ent=false
    
        -- avoid touching the same non-solid multiple times (ex: triggers)
        local touched = {}
        -- collect all potential touching entities (done only once)
        -- todo: smaller box
        local ents=self:touches(v_add(ent.absmins,{-256,-256,-256}), v_add(ent.absmaxs,{256,256,256}),ent)
        -- check current to target pos
        local hits = self:hitscan(ent.mins,ent.maxs,origin,next_pos,touched,ents)        
        if hits then
            -- invalid move
            if hits.start_solid or hits.all_solid then
                next_pos = origin
                invalid = true
            else
                -- position at impact
                -- report closest hit
                next_pos=v_add(hits.pos, hits.ent.origin)
                hit_ent = hits.ent
            end
        end
    
        return {
            pos=next_pos,
            ent=hit_ent,
            touched=touched,
            invalid=invalid}
    end
        
    return this
end
return CollisionMap