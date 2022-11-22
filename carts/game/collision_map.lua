local maths3d = require("engine.maths3d")
local bsp = require("bsp")
local CollisionMap=function(world)
    local level = world.level.model[1]
    -- init the root of the 2d BSP (for collision)
    local _root
    -- collision map (2d)
    local _map

    -- depth of 2d map
    local MAX_DEPTH = 4
    local function create_map(mins,maxs,depth)
        if depth>MAX_DEPTH then
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
            -- stores physic+triggers entities
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
        if sides==3 or cell.depth==MAX_DEPTH then
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
        find=function(self,cell,mins,maxs,filter)
            if not cell then
                return
            end
            -- in case filter as a owner (eg: missile) filter out as well
            local owner=filter and filter.owner
            -- collect current cell items
            local x0,y0,z0,x1,y1,z1=mins[1],mins[2],mins[3],maxs[1],maxs[2],maxs[3]    
            for e,_ in pairs(cell.ents) do
                if not self.ents[e] and e~=filter and e~=owner then              
                    -- touching?
                    if x0<=e.absmaxs[1] and x1>=e.absmins[1] and
                       y0<=e.absmaxs[2] and y1>=e.absmins[2] and
                       z0<=e.absmaxs[3] and z1>=e.absmins[3] then
                        -- avoid duplicates
                        self.ents[e] = true
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
        self:register(ent)
    end

    function this:set_size(ent,mins,maxs)
    end    

    function this:unregister(ent)
        -- unregister from visible world
        if ent.nodes then
            for node,_ in pairs(ent.nodes) do
                if node.ents then
                    node.ents[ent]=nil
                end
                ent.nodes[node] = nil
            end    
        end
        -- unregister from physical world
        if ent.cell then
            ent.cell.ents[ent]=nil
            ent.cell=nil
        end
    end

    function this:register(ent, touch_triggers)
        -- refresh attributes linked to origin
        ent.absmins=v_add(ent.origin,ent.mins)
        ent.absmaxs=v_add(ent.origin,ent.maxs)
        m_set_pos(ent.m,ent.origin)
    
        -- unlink first
        self:unregister(ent)

        if ent.free then
            return
        end

        if not ent.DRAW_NOT then
            local mins,maxs=ent.absmins,ent.absmaxs
            local c={
                0.5*(mins[1]+maxs[1]),
                0.5*(mins[2]+maxs[2]),
                0.5*(mins[3]+maxs[3])
            }
            -- extents
            local e=make_v(c, maxs)
            -- register in visible world (e.g. PVS)
            register_bbox(_root, ent, c, e)
        end
        
        --
        -- to make items easier to pick up and allow them to be grabbed off
        -- of shelves, the abs sizes are expanded
        --
        if ent.FL_ITEM then
            ent.absmins[1] = ent.absmins[1] - 15
            ent.absmins[2] = ent.absmins[2] - 15
            ent.absmaxs[1] = ent.absmaxs[1] + 15
            ent.absmaxs[2] = ent.absmaxs[2] + 15
        else
        	-- because movement is clipped an epsilon away from an actual edge,
            -- we must fully check even when bounding boxes don't quite touch
            ent.absmins[1] = ent.absmins[1] - 1
            ent.absmins[2] = ent.absmins[2] - 1
            ent.absmins[3] = ent.absmins[3] - 1
            ent.absmaxs[1] = ent.absmaxs[1] + 1
            ent.absmaxs[2] = ent.absmaxs[2] + 1
            ent.absmaxs[3] = ent.absmaxs[3] + 1
        end

        -- register to 2d map
        register_map(_map, ent)
    end

    -- returns all entities touching the given absolute box    
    function this:touches(mins,maxs,ent,no_world)
        -- always add world
        touch_query.ents = no_world and {} or {world.entities[1]}
        touch_query:find(_map,mins,maxs,ent)
        return touch_query.ents
    end

    function this:get_map()
        return _map
    end

    -- returns first hit along a ray, testing all "ents" along the way
    -- adds touched triggers entities to "triggers" table
    -- note: world is an entity like any other (sort of!)
    -- returns:
    --      t: fraction
    --      n: normal at impact + distance
    --      pos: pos at impact
    --      all_solid: start/end in solid
    --      start_solid: start in solid
    --      in_open: clear space
    --      in_water: in "water" volume
    --      ent: touched entity
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

        -- default = reaches target position
        local hits={
            t=1,
            pos=p1
        }
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
                        -- adjust pos                        
                        hits = tmphits
                        -- rebase to world space
                        hits.pos=v_add(hits.pos,other_ent.origin)
                    end
                end
            end
        end  
        return hits
    end

    local STOP_EPSILON = 0.1
    function clipVelocity(velocity,normal,overbounce)
        local blocked = 0
        if normal[3] > 0 then
            blocked = bor(blocked,1) -- floor
        end
        if normal[3]==0 then
            blocked = bor(blocked,2) -- step
        end

        local out, backoff = {}, v_dot(velocity, normal) * overbounce
        for i=1,3 do
            local v = velocity[i] - normal[i]*backoff
            if v > -STOP_EPSILON and v < STOP_EPSILON then
                v = 0
            end
            out[i]=v
        end
        
        return out,blocked
    end

    -- slide on wall move (players, npc...)
    function this:slide(ent,origin,velocity)
        local original_velocity=v_clone(velocity)
        local primal_velocity=v_clone(velocity)
        local blocked = 0
        local time_left = 1/60
        local planes={}
        local wall_n
        local ground_ent

        -- avoid touching the same non-solid multiple times (ex: triggers)
        local touched = {}
        -- collect all potential touching entities (done only once)
		local l=max(0.03125,2*v_len(velocity))
		local mins,maxs=
			v_add(ent.origin,ent.mins),
			v_add(ent.origin,ent.maxs)        
        local ents=self:touches(v_add(mins,{1,1,1},-l), v_add(maxs,{1,1,1},l),ent)
        -- check current to target pos
        for i=1,4 do
            -- try far target
            local next_pos=v_add(origin,velocity,time_left)

            local hits = self:hitscan(ent.mins,ent.maxs,origin,next_pos,touched,ents)
            if not hits.n then
                -- all clear
                origin=next_pos
                break
            end
            if hits.start_solid or hits.all_solid then
                printh("in solid")
    			velocity={0,0,0}
                break
            end
            -- actually covered some distance
            if hits.t>0 then
                origin=hits.pos
                planes={}
            end
            if hits.t==1 then
                break
            end

            -- ground?
            if hits.n[3]>0.7 then
                blocked = bor(blocked,1)
                -- last hit ground entity
                ground_ent = hits.ent
            end
            -- wall?
            if hits.n[3]==0 then
                blocked = bor(blocked,2)
                wall_n = hits.n
            end

            time_left = time_left - time_left*hits.t
            if #planes>5 then
                -- printh("too many planes: "..#planes)
    			velocity={0,0,0}
                break
            end
            add(planes,hits.n)

            local i,np,new_vel=1,#planes
            while i<=np do
                -- adjust velocity
                new_vel = clipVelocity(original_velocity,planes[i],1)
                local clear=true
                for j=1,np do
                    if i~=j then
                        if v_dot(new_vel, planes[j])<0 then
                            clear = false
                            break
                        end
                    end
                end
                if clear then
                    break
                end
                i=i+1
            end
            if i<=np then
                -- go along
                velocity = new_vel
            else
                if np~=2 then
                    -- printh("Collision error - too many planes: "..np)
                    velocity={0,0,0}
                    break
                end
                local dir=v_cross(planes[1],planes[2])
                local d=v_dot(dir,velocity)
                velocity=v_scale(dir,d)
            end

            -- if original velocity is against the original velocity, stop dead
            -- to avoid tiny occilations in sloping corners
            if v_dot(velocity, primal_velocity) <= 0 then
                --printh("opposite velocities!")
    			velocity={0,0,0}
                break
            end
        end

        return {
            pos=origin,
            velocity=velocity,
            ground=ground_ent,
            on_ground=band(blocked,1)>0,
            on_wall=band(blocked,2)>0,
            t=time_left*60,
            n=wall_n,
            touched=touched}
    end
    
    -- missile type move (no course correction)
    function this:fly(ent,origin,velocity,no_world)
        local next_pos=v_add(origin,velocity)
        local invalid,hit_ent=false
    
        -- avoid touching the same non-solid multiple times (ex: triggers)
        local touched = {}
        -- collect all potential touching entities (done only once)
        -- todo: smaller box
        local ents=self:touches(v_add(ent.absmins,{-256,-256,-256}), v_add(ent.absmaxs,{256,256,256}),ent,no_world)
        -- check current to target pos
        local hits = self:hitscan(ent.mins,ent.maxs,origin,next_pos,touched,ents)  
        hits.touched = touched
        return hits
    end
    return this
end
return CollisionMap