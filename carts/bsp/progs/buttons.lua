local triggers=function(progs)
    -- internal helpers
    local function init_button(self)
        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true;
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    -- help: https://www.moddb.com/tutorials/quake-c-touch
    progs.func_button=function(self)
        -- init entity
        init_button(self)
        self.touch=function(other)
            print("button touched by: "..other.classname)
        end
        self.use=function(other)
            print("button touched by: "..other.classname)
        end
    end
end
return triggers