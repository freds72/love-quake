local WorldSystem={}
local conf = require("game_conf")
local maths = require("engine.maths3d")
local logging = require("engine.logging")
local gameState = require("systems.game_state")

-- private vars
local vm
local collisionMap
local active_entities={}
local new_entities={}
local time_t = 0

local physic

function WorldSystem:load(level_name)
    -- globals :(
    planes = require("engine.plane_pool")()

    self.loaded = false
    self.player = nil
    self.level = nil
    -- "physics" time (fixed clock)
    time_t = 0
    
    if level_name=="start" then
        gameState:reset()
    end

    planes.reset()
    active_entities={}    

    -- create I/O classes (inc. caching)
    local pakReader=require("io.pak_reader")(conf)
    local modelReader=require("io.model_reader")(pakReader)
    
    -- load file
    local level=modelReader:load("maps/"..level_name..".bsp")
    self.level = level

    -- 2d/3d collision map
    collisionMap=require("collision_map")(self)

    -- live entities
    self.entities=require("entities")(active_entities)
    -- context
    local api=require("systems.progs_api")(modelReader, level.model, self, collisionMap)
    vm = require("systems.progs_vm")(api)

    -- 
    physic = require("systems.physics")(self, vm, collisionMap)

    -- bind entities and engine
    for i=1,#level.entities do        
        -- order matters: worldspawn is always first
        local ent = level.entities[i]
        -- match with difficulty level
        if band(ent.spawnflags or 0, shl(gameState.skill,8))==0 then
            ent.ltime = 0
            local ent = vm:create(ent)
            if ent then
                -- valid entity?
                add(active_entities, ent)
            end
        end
    end
    self.loaded = true
end

function WorldSystem:spawn()
    -- don't add new entities in this frame
    local ent={
        -- local time (used for doors & platforms mostly)
        ltime = 0,
        -- PVS nodes the entity is in
        nodes={},
        m={
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            0,0,0,1
            }        
        }
    -- 
    add(new_entities, ent)
    return ent
end

-- call a "program" function unless entity is tagged for delete
function WorldSystem:call(ent,fn,...) 
    vm:call(ent,fn,...)
end

local 	STOP_EPSILON    = 0.1

--
-- Slide off of the impacting object
-- returns the blocked flags (1 = floor, 2 = step / wall)
local function PM_ClipVelocity(origin, normal, out, overbounce)
    local blocked = 0
    if normal[3] > 0 then
        blocked = bor(blocked, 1) --floor
    end
    if normal[3]==0 then
        blocked = bor(blocked,2)  -- step
    end
    local backoff = v_dot (origin, normal) * overbounce

    for i=1,3 do
        local change = normal[i]*backoff
        out[i] = origin[i] - change
        if out[i] > -STOP_EPSILON and out[i] < STOP_EPSILON then
            out[i] = 0
        end
    end
    
    return blocked
end

local MAX_CLIP_PLANES=5

-- The basic solid body movement clip that slides along multiple planes
local function PM_FlyMove(world, pmove)	
	local numbumps = 4
	
	local blocked = 0
	local original_velocity = v_clone(pmove.velocity)
	local primal_velocity = v_clone(pmove.velocity)
	local planes = {}
	local time_left = 1/60

	for bumpcount=0,numbumps-1 do
        local move_end = v_add(pmove.origin, pmove.velocity, time_left)

		local trace = PM_PlayerMove (pmove.origin, move_end)

		if  trace.startsolid or trace.allsolid then
		    -- entity is trapped in another solid
            pmove.velocity = {0,0,0}
			return 3
        end

		if trace.fraction > 0 then
		    -- actually covered some distance
            pmove.origin = trace.endpos
			planes={}
        end

		if trace.fraction == 1 then
            -- moved the entire distance
			 break
        end

		-- save entity for contact
		add(pmove.touched,trace.ent)

		if trace.n[3] > 0.7 then
			blocked = bor(blocked, 1) -- floor
        end
		if trace.n[2]==0 then
			blocked = bor(blocked, 2) --step
        end

		time_left = time_left - time_left * trace.fraction
		
	    -- cliped to another plane
		if #planes >= MAX_CLIP_PLANES then
		    -- this shouldn't really happen
            pmove.velocity = {0,0,0}			
			break
        end

        add(planes, trace.n)

    --
    -- modify original_velocity so it parallels all of the clip planes
    --
        local all_clear=true
        for i=1,#planes do
			PM_ClipVelocity (original_velocity, planes[i], pmove.velocity, 1)
            local clear=true
            for j=1,#planes do
				if j ~= i then
					if v_dot(pmove.velocity, planes[j]) < 0 then
                        -- not ok
                        clear = nil
						break
                    end
				end
            end
			if clear then
                all_clear = nil
				break
            end
		end
		
		if not all_clear then
			-- go along this plane		
		else
		
            -- go along the crease
			if #planes ~= 2 then
                printh("clip velocity, numplanes == "..#planes)
                pmove.velocity = {0,0,0}
				break
            end
            local dir = v_cross(planes[1], planes[2])
			local d = v_dot (dir, pmove.velocity)
            dir = v_scale(dir, pmove.velocity, d)
		end

        --
        -- if original velocity is against the original velocity, stop dead
        -- to avoid tiny occilations in sloping corners
        --
		if v_dot(pmove.velocity, primal_velocity) <= 0 then
            pmove.velocity = {0,0,0}
			break
        end
	end

	if pmove.waterjumptime>0 then
        pmove.velocity = primal_velocity
    end
		
	return blocked
end

-- update world / run physics / create late entities / ...
function WorldSystem:update()
    -- transfer new entities to active list     
    for k,ent in pairs(new_entities) do
        add(active_entities, ent)
        new_entities[k]=nil
    end

    -- printh('--------------------')
    local dt = 1/60
    time_t = time_t + dt

    -- run physic "warm" loop
    local platforms={}
    for i=#active_entities,1,-1 do
        local ent = active_entities[i]
        if ent.MOVETYPE_PUSH then
            platforms[ent] = true
            physic.pusher(ent, dt)
        end
    end

    -- any thinking to do?
    for i=#active_entities,1,-1 do
        local ent = active_entities[i]
        -- to be removed?
        if ent.free then
            if ent.classname=="player" then
                self.player = nil
            end
            collisionMap:unregister(ent)
            del(active_entities, i)
        elseif not platforms[ent] then
            if ent.velocity then
                local velocity = v_scale(ent.velocity,dt)

                if ent.MOVETYPE_TOSS then
                    physic.toss(ent, velocity, dt)
                elseif ent.MOVETYPE_WALK then
                    physic.walk(ent, velocity, dt)
                elseif ent.MOVETYPE_BOUNCE then
                    physic.bounce(ent, velocity, dt)
                else
                    ent.origin = v_add(ent.origin, velocity)
                end

                -- link to world
                collisionMap:register(ent)                
            end
            
            if ent.nextthink and ent.nextthink<time_t and ent.think then
                ent.nextthink = nil
                ent:think()
            end

            -- todo: force origin changes via function
            if ent.m then
                local angles=ent.mangles or {0,0,0}
                ent.m=make_m_from_euler(unpack(angles))          
                m_set_pos(ent.m, ent.origin)
            end
        end
    end

    --[[
    -- move platforms (if possible)
    for i=1,#platforms do
        local ent=platforms[i]
        -- clip with world
        ent.SOLID_NOT=nil
        local move = collisionMap:fly(ent,ent.origin,v_scale(ent.velocity,1/60),true)
        -- not collision?
        if not move.ent then
            ent.origin = move.pos          
            -- update bounding box
            ent.absmins=v_add(ent.origin,ent.mins)
            ent.absmaxs=v_add(ent.origin,ent.maxs)

            -- link to world
            collisionMap:register(ent)
            local angles=ent.mangles or {0,0,0}
            ent.m=make_m_from_euler(unpack(angles))          
            m_set_pos(ent.m, ent.origin)
        else
            printh(ent.classname.." collides: "..move.ent.classname)
        end
    end
    ]]
end

-- create a player
function WorldSystem:connect()
    -- find a suitable pos
    for _,kv in pairs(self.level.entities) do
        if kv.classname=="info_player_start" then
            -- local positions = self.entities:find(nil, "classname", "info_player_start")
            -- local i = 1-- flr(rnd(1,#positions))
            local ent = {
                classname = "player",
                -- always start slighlty above ground
                origin = v_add(v_clone(kv.origin),{0,0,1})
            }
            
            local ent = vm:create(ent)
            assert(ent,"cannot create player")
            -- valid entity?
            self.player = ent
            add(active_entities, ent)
            return ent
        end
    end
end

function WorldSystem:findClass(classname)
    local ents={}
    for _,kv in pairs(self.level.entities) do
        if kv.classname==classname then
            add(ents,kv)
        end
    end
    return ents
end

return WorldSystem