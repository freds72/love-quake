local triggers=function(progs)

    local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot

    local SPAWNFLAG_NOMESSAGE = 1
    local SPAWNFLAG_NOTOUCH = 1

    -- internal helpers
    local function init_trigger(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
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

        local enabled = not self.targetname

        if not self.target then
            progs:objerror("no target")
        end

        self.touch=function(other)
            if not enabled then
                return
            end
            local player_only = band(self.spawnflags or 0,1)==1
            if player_only and other.classname~="player" then
                return
            end
            -- pick a (random) target destination
            use_targets(self, other, true)
        end

        self.use=function(other)
            enabled = true
        end
    end

    progs.info_teleport_destination=function(self)
        -- 
        local origin = v_add(self.origin,{0,0,27})
        -- init entity
        self.SOLID_NOT = true
        self.MOVETYPE_NONE = true
        self.DRAW_NOT = true
        -- set size and link into world
        progs:setmodel(self, self.model)   
        set_move_dir(self)

        self.use=function(other)
            -- todo: set angle + velocity
            other.velocity = v_clone(self.movedir)
            progs:setorigin(other, origin)
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
                progs:print(self.message)
            end
            -- reactivate (or not)
            if self.wait>0 then
                self.nextthink = progs:time() + self.wait
            else
                -- remove self
                self.free = true
                self.touch = nil
            end
        end
    end

    progs.trigger_once=function(self)
        -- init entity        
        init_trigger(self)

        self.touch=function(other)
            if self.message then
                progs:print(self.message)
            end
            -- kill self
            self.free = true
            -- avoid reentrancy
            self.touch = nil
            
            -- trigger action (if any)
            use_targets(self)
        end
    end

    progs.trigger_counter=function(self)
        -- init entity        
        init_trigger(self)
        local msg = self.message or "%s more to go..."
        local msg_on = band(self.spawnflags or 0,SPAWNFLAG_NOMESSAGE)==0
        local count = self.count or 2
        self.use = function()
            count = count - 1
            if msg_on then
                if count>0 then
                    progs:print(msg,count)
                else
                    progs:print("Sequence completed!")
                end
            end
            if count==0 then
                -- kill counter
                self.free = true
                self.use = nil
                use_targets(self)
            end
        end
    end

    progs.trigger_secret=function(self)
        init_trigger(self)
        progs.total_secrets = progs.total_secrets + 1
        self.wait = -1
        local msg = self.message or "You found a secret area!"

        local function use_secret(other)
            if other.classname ~= "player" then
			    return
            end
            self.free = true
            self.use = nil
            self.touch = nil
		    progs.found_secrets = progs.found_secrets + 1
            progs:print(msg)
            use_targets(self, other)
        end
        self.use = use_secret
        if band(self.spawnflags or 0,SPAWNFLAG_NOTOUCH)==0 then
            self.touch = use_secret
        end
    end

    progs.trigger_setskill=function(self)
        init_trigger(self)        

        local skill=tonumber(self.message)

        self.touch=function()
            progs:set_skill(skill)
        end
    end

    progs.trigger_changelevel=function(self)
        local NO_INTERMISSION = 1

        init_trigger(self)        
        self.touch = function()
            -- todo: change level
            progs:load(self.map, band(self.spawnflags,NO_INTERMISSION)~=0)
        end
    end

end
return triggers