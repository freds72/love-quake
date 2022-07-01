local logging=require("engine.logging")
local conf=require("game_conf")

-- interface between "programs" and game engine
local ProgsVM=function(env)
    -- global functions
    for i=1,#conf.progs do
        local name = conf.progs[i]
        logging.info("Initializing extension: "..name)
        require("progs."..name)(env)
    end

    return {        
        -- call a "mod" function unless entity is tagged for delete
        call=function(self,ent,fn,...)
            if not ent.free and ent[fn] then
                ent[fn](...)
            end
        end,
        create=function(self,ent)
            -- find extension point
            local fn = env[ent.classname]
            if fn then
                -- print("INFO - binding: "..ent.classname)
                fn(ent)
                return ent
            end
        end,
        impact=function(self,ent1,ent2)
            if not ent1.SOLID_NOT then
                self:call(ent1,"touch",ent2)
            end
            if not ent2.SOLID_NOT then
                self:call(ent2,"touch",ent1)
            end
        end
    }
end
return ProgsVM