local weapons=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model ("progs/v_rock.mdl")

    progs.weapon_supershotgun=function(self)
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true;
        self.skin = 1
        self.frame = "shot1"
        self.mangles = {0,0,self.angle or 0}
        -- set size and link into world
        progs:setmodel(self, "progs/v_rock.mdl",{0,0,56})

        local anim = 0
        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.frame = "shot"..((anim%7)+1)
            self.nextthink = progs:time() + 0.1
            anim = anim+1
        end        
    end
end
return weapons