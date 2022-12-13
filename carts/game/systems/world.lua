local WorldSystem={time_t=0}
local conf = require("game_conf")
local maths = require("engine.maths3d")
local logging = require("engine.logging")
local gameState = require("systems.game_state")

-- private vars
local vm
local collisionMap
local active_entities={}
local new_entities={}

local physic

function WorldSystem:load(level_name)
    -- globals :(
    planes = require("engine.plane_pool")()

    self.loaded = false
    self.player = nil
    self.level = nil
    -- "physics" time (fixed clock)
    self.time_t = 0
    
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
    -- debug
    self.collisionMap = collisionMap
    
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
            -- todo: cleanup default
            ent.ltime = 0
            local oent=ent
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

-- update world / run physics / create late entities / ...
function WorldSystem:update()
    -- transfer new entities to active list     
    for k,ent in pairs(new_entities) do
        add(active_entities, ent)
        new_entities[k]=nil
    end

    -- printh('--------------------')
    local dt = 1/60
    self.time_t = self.time_t + dt

    -- run physic "warm" loop
    local platforms={}
    for i=1,#active_entities do
        local ent = active_entities[i]
        if ent.MOVETYPE_PUSH then
            platforms[ent] = true
            physic.pusher(ent, dt)
        end
    end

    -- any thinking to do?
    for i=1,#active_entities do
        local ent = active_entities[i]
        if not platforms[ent] then
            if ent.velocity then
                local velocity = ent.velocity--v_scale(ent.velocity,dt)

                if ent.MOVETYPE_TOSS then
                    physic.toss(ent, velocity, dt)
                elseif ent.MOVETYPE_WALK then
                    physic.walk(ent, velocity, dt)
                elseif ent.MOVETYPE_BOUNCE then
                    physic.bounce(ent, velocity, dt)
                elseif ent.MOVETYPE_FLY then
                    physic.fly(ent, velocity, dt)
                else
                    ent.origin = v_add(ent.origin, velocity, dt)
                end

                -- link to world
                collisionMap:register(ent)                
            end
            
            if ent.nextthink and ent.nextthink<self.time_t and ent.think then
                ent.nextthink = nil
                ent:think()
            end

            -- todo: force origin changes via function / useless?
            if ent.m then
                local angles=ent.mangles or {0,0,0}
                ent.m=make_m_from_euler(unpack(angles))          
                m_set_pos(ent.m, ent.origin)
            end
        end
        if ent.postthink then
            ent.postthink()
        end
    end

    -- drop "free" entities
    for i=#active_entities,1,-1 do
        local ent = active_entities[i]
        if ent.free then
            if ent.classname=="player" then
                self.player = nil
            end
            collisionMap:unregister(ent)
            del(active_entities, i)
        end
    end
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