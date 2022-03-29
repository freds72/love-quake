local misc=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model("maps/b_explob.bsp")
    progs:precache_model("progs/flame.mdl")
    progs:precache_model("progs/flame2.mdl")
    
    progs.misc_explobox=function(self)
        self.SOLID_BSP = true
        self.MOVETYPE_NONE = true
        progs:setmodel(self, "maps/b_explob.bsp")
    end

    progs.light_torch_small_walltorch=function(self)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        self.frame = "flame1" 
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/flame.mdl")
        local anim = 0
        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.frame = "flame"..((anim%6)+1)
            self.nextthink = progs:time() + 0.1
            anim = anim+1
        end
    end

    local function flame2_func(self)
        self.SOLID_NOCLIP = true
        self.MOVETYPE_NONE = true
        self.skin = 1
        self.frame = "flameb1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/flame2.mdl")
        local anim = 0
        self.nextthink = progs:time() + 0.1
        self.think=function()            
            self.frame = "flameb"..((anim%11)+1)
            self.nextthink = progs:time() + 0.1
            anim = anim+1
        end
    end

    progs.light_flame_large_yellow=flame2_func
    progs.light_flame_small_yellow=flame2_func
end
return misc