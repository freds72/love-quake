-- loads declared "programs" in configuration
local logging=require("engine.logging")
local ProgsFactory=function(conf,env)
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
        end
    }
end
return ProgsFactory