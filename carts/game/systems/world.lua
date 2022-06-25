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

function WorldSystem:load(level_name)
    -- globals :(
    planes = require("engine.plane_pool")()

    self.loaded = false
    self.player = nil
    self.level = nil
    
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

    -- bind entities and engine
    for i=1,#level.entities do        
        -- order matters: worldspawn is always first
        local ent = level.entities[i]
        -- match with difficulty level
        if band(ent.spawnflags or 0, shl(gameState.skill,8))==0 then
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

-- update world / run physics / create late entities / ...
function WorldSystem:update()
    -- transfer new entities to active list     
    for k,ent in pairs(new_entities) do
        add(active_entities, ent)
        new_entities[k]=nil
    end

    -- run physic "warm" loop
    local platforms={}
    for i=#active_entities,1,-1 do
        local ent = active_entities[i]
        if not ent.free and not ent.SOLID_NOT and ent.SOLID_BSP and ent.MOVETYPE_PUSH then
            if ent.velocity then
                local velocity = v_scale(ent.velocity,1/60)
                -- collect moving box
                local absmins,absmaxs=v_add(ent.absmins,velocity),v_add(ent.absmaxs,velocity)
                -- collect touching entities (excludes world!!)
                local touchingEnts=collisionMap:touches(absmins,absmaxs,ent,true)
                -- 
                ent.SOLID_NOT=true
                local can_push = true
                for j=1,#touchingEnts do
                    local touchingEnt=touchingEnts[j]
                    --if not touchingEnt.free and not ent.MOVETYPE_PUSH and ent.SOLID_SLIDEBOX then
                    if touchingEnt.classname=="player" then
                        --printh(time().." plat touching: "..touchingEnt.classname)
                        -- collect "push" velocity
                        -- touchingEnt.push = v_add(touchingEnt.push or {0,0,0},ent.velocity,1/60)
                        -- try to push entity
                        local move = collisionMap:slide(touchingEnt,touchingEnt.origin,velocity)
                        if move.fraction<1 then
                            printh(time().."player blocked by: "..move.ent.classname)
                            can_push = false
                            break
                        else
                            touchingEnt.origin = move.pos
                            -- update bounding box
                            touchingEnt.absmins=v_add(touchingEnt.origin,touchingEnt.mins)
                            touchingEnt.absmaxs=v_add(touchingEnt.origin,touchingEnt.maxs)
                    
                            -- link to world
                            collisionMap:register(touchingEnt)                        
                        end
                    end
                end
                ent.SOLID_NOT=nil
                if can_push then
                    -- move platform
                    ent.origin = v_add(ent.origin, velocity)
                    -- update bounding box
                    ent.absmins=v_add(ent.origin,ent.mins)
                    ent.absmaxs=v_add(ent.origin,ent.maxs)
            
                    -- link to world
                    collisionMap:register(ent)                           
                end
            end
            -- update entity
            if ent.nextthink and ent.nextthink<time() and ent.think then
                ent.nextthink = nil
                ent:think()
            end                  
            add(platforms,ent)
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
        elseif not ent.MOVETYPE_PUSH then
            if ent.velocity then
                local velocity = v_scale(ent.velocity,1/60)
                -- print("entity: "..i.." moving: "..v_tostring(ent.origin))
                local prev_contents = ent.contents
                -- water? super damping
                if prev_contents==-3 then
                    -- velocity[3]=velocity[3]*0.6
                end

                if ent.MOVETYPE_TOSS then
                    local move = collisionMap:fly(ent,ent.origin,velocity)
                    ent.origin = move.pos          
                    velocity[3] = velocity[3] - conf.gravity_z/60          
                    -- hit other entity?
                    if move.ent then
                        vm:call(ent,"touch",move.ent)
                    end
                elseif ent.SOLID_SLIDEBOX then
                    -- check next position                    
                    local vn,vl=v_normz(velocity)      
                    local on_ground = ent.on_ground
                    if vl>0.1 then
                        local move = collisionMap:slide(ent,ent.origin,velocity)   
                        on_ground = move.on_ground
                        if on_ground and move.on_wall and move.fraction<1 then
                            local up_move = collisionMap:slide(ent,v_add(ent.origin,{0,0,18}),velocity) 
                            -- largest distance?
                            if not up_move.invalid and up_move.fraction>move.fraction then
                                move = up_move
                            end
                        end
                        ent.origin = move.pos
                        velocity = move.velocity

                        -- trigger touched items
                        for other_ent in pairs(move.touched) do
                            vm:call(other_ent,"touch",ent)
                        end                               
                    else
                        velocity = {0,0,0}
                    end
                    -- "debug"
                    ent.on_ground = on_ground                    

                    -- use corrected velocity
                    ent.velocity = v_scale(velocity,60)
                else
                    ent.origin = v_add(ent.origin, velocity)
                end

                -- update bounding box
                ent.absmins=v_add(ent.origin,ent.mins)
                ent.absmaxs=v_add(ent.origin,ent.maxs)
        
                -- link to world
                collisionMap:register(ent)

                if prev_contents~=ent.contents then
                    -- print("transition from: "..prev_contents.." to:"..ent.contents)
                end        
            end
            
            if ent.nextthink and ent.nextthink<time() and ent.think then
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