local triggers=function(progs)
    -- internal helpers
    local function init_trigger(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true;
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    progs.trigger_teleport=function(self)
        -- init entity
        init_trigger(self)
        if not self.target then
            progs:objerror("no target")
        end
        self.touch=function()
            print("touched!")
        end
        self.use=function()
            print("used!")
        end
    end

    progs.func_button=function(self)
        -- init entity
        init_trigger(self)
        self.touch=function()
            print("touched!")
        end
        self.use=function()
            print("used!")
        end
    end
end
return triggers