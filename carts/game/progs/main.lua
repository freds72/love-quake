local main=function(context)

    local logging=require("logging")

    -- helpers
    -- game modules
    local modules={
        "world",
        "triggers",
        "buttons",
        "doors",
        "lights",
        "walls",
        "player",
        "items",
        "misc",
        "shambler",
        "zombie",
        "soldier",
        "weapons"
    }

    -- global functions
    local env = setmetatable({},{__index=context})
    for i=1,#modules do
        local name = modules[i]
        logging.info("init extension: "..name)
        require("progs/"..name)(env)
    end

    return {
        -- call a "mod" function unless entity is tagged for delete
        call=function(self,ent,fn,...)
            if not ent.free and ent[fn] then
                ent[fn](...)
            end
        end,
        bind=function(self,ent)
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
return main