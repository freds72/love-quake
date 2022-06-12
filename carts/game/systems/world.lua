local WorldSystem={}
local conf = require("game_conf")
local maths = require("engine.maths3d")
local factory
local collisionMap
local active_entities={}
local new_entities={}

-- globals :(
planes = require("engine.plane_pool")()

function WorldSystem:load(level_name)
    self.loaded = false
    self.player = nil
    self.level = nil
    planes.reset()
    active_entities={}    

    -- create I/O classes (inc. caching)
    local pakReader=require("io.pak_reader")(conf.root_path)
    local modelReader=require("io.model_reader")(pakReader)
    
    -- load file
    local level=modelReader:load("maps/"..level_name..".bsp")
    self.level = level

    -- 2d/3d collision map
    collisionMap=require("collision_map")(self)

    -- live entities
    self.entities=require("entities")(active_entities)
    -- context
    local api=require("progs_api")(modelReader, level.model, self, collisionMap)
    factory=require("progs_factory")(api)

    -- bind entities and engine
    for i=1,#level.entities do        
        -- order matters: worldspawn is always first
        local ent = level.entities[i]
        -- todo: match with difficulty level
        if band(ent.spawnflags or 0,512)==0 then
            local ent = factory:create(ent)
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

function WorldSystem:update()
    -- transfer new entities to active list     
    for k,ent in pairs(new_entities) do
        add(active_entities, ent)
        new_entities[k]=nil
    end

    -- any thinking to do?
    for i=#active_entities,1,-1 do
        local ent = active_entities[i]
        -- to be removed?
        if ent.free then
            collisionMap:unregister(ent)
            del(active_entities, i)
        else
            -- any velocity?
            local velocity=ent.velocity
            if velocity then
                -- todo: physics...
                -- print("entity: "..i.." moving: "..v_tostring(ent.origin))
                local prev_contents = ent.contents
                if ent.MOVETYPE_TOSS then
                    local move = collisionMap:fly(ent,ent.origin,v_scale(velocity,1/60))
                    ent.origin = move.pos          
                    velocity[3] = velocity[3] - conf.gravity_z/60          
                    -- hit other entity?
                    if move.ent then
                        factory:call(ent,"touch",move.ent)
                    end
                elseif ent.SOLID_SLIDEBOX then
                    -- check next position
                    local vn,vl=v_normz(velocity)      
                    local on_ground = ent.on_ground
                    if vl>0.1 then
                        local move = collisionMap:slide(ent,ent.origin,velocity)   
                        on_ground=move.on_ground
                        if ent.on_ground and move.on_wall and move.fraction<1 then
                            local up_move = collisionMap:slide(ent,v_add(ent.origin,{0,0,18}),velocity) 
                            -- largest distance?
                            if not up_move.invalid and up_move.fraction>move.fraction then
                                move = up_move
                                -- slight nudge up
                                -- todo: fix / doesn't really work
                                -- move.velocity[3] = move.velocity[3] + 4
                                -- "mini" jump
                                ent.on_ground=false
                            end
                        end
                        ent.origin = move.pos
                        velocity = move.velocity

                        -- trigger touched items
                        for other_ent in pairs(move.touched) do
                            factory:call(other_ent,"touch",ent)
                        end                               
                    else
                        velocity = {0,0,0}
                    end
                    -- "debug"
                    ent.on_ground = on_ground                    

                    ent.velocity = velocity
                else
                    ent.origin = v_add(ent.origin, ent.velocity, 1/60)
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
                m_set_pos(ent.m, ent.origin)
            end
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
            
            local ent = factory:create(ent)
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