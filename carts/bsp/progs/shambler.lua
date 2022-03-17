local shambler=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model("progs/shambler.mdl")

    progs.monster_shambler=function(self)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/shambler.mdl")
        local anim = 0
        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.frame = "stand"..((anim%17)+1)
            self.nextthink = progs:time() + 0.1
            anim = anim+1
        end
    end
end
return shambler