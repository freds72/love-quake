local misc=function(progs)

    -- p8 compat
    local band=bit.band
    local rnd=math.random

    progs:precache_model("maps/b_explob.bsp")
    progs:precache_model("progs/flame.mdl")
    progs:precache_model("progs/flame2.mdl")
    progs:precache_model("progs/lavaball.mdl")

    progs.misc_explobox=function(self)
        self.SOLID_BSP = true
        self.MOVETYPE_NONE = true
        progs:setmodel(self, "maps/b_explob.bsp")
        progs:drop_to_floor(self)
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

    progs.misc_fireball=function(self)
        self.classname = "fireball"
        local particles={
            rate=50, -- 50 particles/sec
            ttl={0.5,1},
            mins={-8,-8,-8},
            maxs={8,8,8},
            gravity={0,0,30},
            ramp=3
        }
        set_defaults(self,{
            SOLID_NOT=true,            
            DRAW_NOT=true,
            speed = 1000,
            -- for debug/display only
            mins={-4,-4,-4},
            maxs={4,4,4},
            nextthink = progs:time() + 5 * rnd(),
            think = function()
                local fireball = progs:spawn()
                fireball.classname = self.classname
                fireball.SOLID_TRIGGER = true
                -- apply balistic physics
                fireball.MOVETYPE_TOSS = true
                fireball.origin = v_clone(self.origin)
                fireball.velocity = {
                    (rnd() * 100) - 50,
                    (rnd() * 100) - 50,
                    self.speed + rnd() * 200}
                fireball.touch=function(other)
                    progs:remove(fireball)
                end
                fireball.nextthink = progs:time() + 5
                fireball.think=function()
                    progs:remove(fireball)
                end
                fireball.skin=1
                fireball.frame = "frame1"
                progs:setmodel(fireball,"progs/lavaball.mdl")
                progs:attach(fireball,"particles",particles)

                -- attach a particle system
                self.nextthink = progs:time() + 5 * rnd()
            end
        })
    end
end
return misc