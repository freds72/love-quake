local main=function(context)
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
        "items"
    }

    -- global functions
    local env = setmetatable({},{__index=context})
    for i=1,#modules do
        local name = modules[i]
        print("INFO - init extension: "..name)
        require("progs/"..name)(env)
    end

    return {
        call=function(self,fn,...)
            if env[fn] then
                env[fn](...)
            end
        end,
        bind=function(self,ent)
            -- find extension point
            local fn = env[ent.classname]
            if fn then
                print("INFO - binding: "..ent.classname)
                fn(ent)
                return ent
            end
        end
    }
end
return main