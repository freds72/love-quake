local zombie=function(progs)
    progs:precache_model("progs/zombie.mdl")
    
    progs.monster_zombie=function(self)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        -- crucified?        
        local crucified = band(self.spawnflags or 0, 1)~=0        
        self.frame = crucified and "cruc_1" or "stand1"
        self.mangles = {0,0,(self.angle or 0)/180}
        progs:setmodel(self, "progs/zombie.mdl")
        progs:drop_to_floor(self)
        
        local anim = flr(rnd() * 16)
        self.nextthink = progs:time() + 0.1
        if crucified then
            self.think=function()            
                self.frame = "cruc_"..((anim%6)+1)
                self.nextthink = progs:time() + 0.1
                anim = anim+1
            end
        else
            self.think=function()            
                self.frame = "stand"..((anim%15)+1)
                self.nextthink = progs:time() + 0.1
                anim = anim+1
            end
        end
    end
end
return zombie