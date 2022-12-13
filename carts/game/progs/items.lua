local items=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model("maps/b_shell0.bsp")
    progs:precache_model("maps/b_bh10.bsp")
    progs:precache_model("maps/b_bh100.bsp")
    progs:precache_model("maps/b_bh25.bsp")

    local H_ROTTEN = 1
    local H_MEGA = 2

    progs.item_shells=function(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
        self.FL_ITEM = true
        -- set size and link into world
        progs:setmodel(self, "maps/b_shell0.bsp")
        progs:drop_to_floor(self)

        self.touch=function(other)
            if other.classname ~= "player" then
                return
            end

            progs:remove(self)
            
            -- todo:    
            printh("got shells")        
        end
    end

    progs.item_health=function(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
        self.FL_ITEM = true
        local flags = self.spawnflags or 0
        
        if band(flags,H_ROTTEN)~=0 then
            progs:setmodel(self, "maps/b_bh10.bsp")
            self.noise = "items/r_item1.wav"
            self.healamount = 15
            self.healtype = 0
        elseif band(flags,H_MEGA)~=0 then
            progs:setmodel(self, "maps/b_bh100.bsp")
            self.noise = "items/r_item2.wav"
            self.healamount = 100
            self.healtype = 2
        else
            progs:setmodel(self, "maps/b_bh25.bsp")
            self.noise = "items/health1.wav"
            self.healamount = 25
            self.healtype = 1
        end
        progs:drop_to_floor(self)
        
        self.touch=function(other)
            if other.classname ~= "player" then
                return
            end

            progs:remove(self)

            -- todo: sound
            take_heal(other, self.healamount)
            
            -- linked actions?
            use_targets(self)
        end
    end
end
return items