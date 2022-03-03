local triggers=function(progs)
    -- internal helpers
    local function init_trigger(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true;
        self.DRAW_NOT = true
        self.nextthink = -1
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    -- help: https://www.moddb.com/tutorials/quake-c-touch
    progs.trigger_teleport=function(self)
        -- init entity
        init_trigger(self)
        if not self.target then
            progs:objerror("no target")
        end
        self.touch=function(other)
            print("touched by: "..other.classname)
        end
        self.use=function(other)
            print("touched by: "..other.classname)
        end
    end

    progs.trigger_multiple=function(self)
        -- init entity        
        init_trigger(self)
        if not self.wait then
		    self.wait = 0.2
        end

        self.touch=function(other)
            if self.nextthink>progs:time() then
                return
            end
            print("touched by: "..other.classname)
            if self.message then
                print("MESSAGE - "..self.message)
                progs:print(self.message)
            end
            -- reactivate (or not)
            if self.wait>0 then
                self.nextthink = progs:time() + self.wait
            else
                -- todo: remove entity
                self.touch = nil
            end
        end
    end
        
end
return triggers