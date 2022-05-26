local WorldSystem={}
local conf = require("game_conf")
local entities
local factory
local level
local collisionMap

-- globals :(
planes = require("engine.plane_pool")()

function WorldSystem:load(level_name)
    planes:reset()

    -- create I/O classes (inc. caching)
    local pakReader=require("pak_reader")(conf.root_path)
    local modelReader=require("model_reader")(pakReader)
    
    -- load file
    level=modelReader:load("maps/"..level_name)
    -- 2d/3d collision map
    collisionMap=require("collision_map")(level.model[1])

    -- "private" array of entities to bind after level load
    local ents={}    
    entities=require("entities")(ents)
    -- context
    local api=require("progs_api")(modelReader, level.model, entities, collisionMap)
    factory=require("progs_factory")(conf, api)

    -- bind entities and engine
    for i=1,#level.entities do        
        -- order matters: worldspawn is always first
        local ent = level.entities[i]
        -- todo: match with difficulty level
        if band(ent.spawnflags or 0,512)==0 then
            local ent = factory:create(ent)
            if ent then
                -- valid entity?
                add(ents, ent)
            end
        end
    end
end
function WorldSystem:update()

    entities:preUpdate()
end

return WorldSystem