local weapons=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model ("progs/g_shot.mdl")
    progs:precache_model ("progs/g_nail.mdl")

    progs.weapon_supershotgun=function(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        self.frame = "shot1"
        self.mangles = {0,0,self.angle or 0}
        -- set size and link into world
        progs:setmodel(self, "progs/g_shot.mdl",{0,0,-24})
        --progs:drop_to_floor(self)

        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.mangles={0,0,progs:time()}
            self.nextthink = progs:time() + 0.01
        end        
    end
    progs.weapon_nailgun=function(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        self.frame = "shot1"
        self.mangles = {0,0,self.angle or 0}
        -- set size and link into world
        progs:setmodel(self, "progs/g_nail.mdl",{0,0,-24})
        --progs:drop_to_floor(self)
        
        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.mangles={0,0,progs:time()}
            self.nextthink = progs:time() + 0.01
        end        
    end
end
return weapons