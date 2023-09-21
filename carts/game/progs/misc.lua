local misc=function(progs)

    -- p8 compat
    local band=bit.band
    local rnd=math.random

    progs:precache_model("maps/b_explob.bsp")
    progs:precache_model("progs/flame.mdl")
    progs:precache_model("progs/flame2.mdl")
    progs:precache_model("progs/lavaball.mdl")
    progs:precache_model("progs/laser.mdl")

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
        self.SOLID_NOT = true
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
        -- particle params
        local particles={
            rate=50, -- 50 particles/sec
            ttl={0.5,1},
            mins={-8,-8,-8},
            maxs={8,8,8},
            gravity_z=30,
            ramp=3
        }
        local blast={
            radius={5,12},
            gravity_z=-600,
            ttl={0.1,0.4},
            speed={50,150}
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
                    progs:attach(fireball,"blast",blast)
                    progs:remove(fireball)
                end
                fireball.nextthink = progs:time() + 5
                fireball.think=function()
                    progs:remove(fireball)
                end
                fireball.skin=1
                fireball.frame = "frame1"
                progs:setmodel(fireball,"progs/lavaball.mdl")
                progs:attach(fireball,"trail",particles)
                progs:attach(fireball,"light",{
                    radius={60,64}
                })

                -- attach a particle system
                self.nextthink = progs:time() + 5 * rnd()
            end
        })
    end

    -- path location
    progs.path_corner=function(self)
        if not self.targetname then
            progs:objerror ("monster_movetarget: no targetname")
        end
        self.DRAW_NOT = true
        self.SOLID_TRIGGER = true
        self.MOVETYPE_NONE = true
        -- self.touch = t_movetarget
        self.mins = {-8,-8,-8}
        self.maxs = {8,8,8}
        set_defaults(self,{
            wait=0
        })
        self.m={
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            0,0,0,1}
        progs:setorigin(self, self.origin)
    end

    local blast={
        radius={5,12},
        gravity_z=-600,
        ttl={0.1,0.4},
        speed={50,150}
    }

    -- traps
    progs.trap_spikeshooter0=function(self)
        self.DRAW_NOT = true
        self.MOVETYPE_NONE = true
        
        local angle = self.angle or 0
        local mangles
        if angle == -1 then
            -- up
            mangles = {0,0,0}
        elseif angle == -2 then
            -- down
            mangles = {0,-0.25,0}
        else
            mangles = {0,0,angle/360+0.5}
        end

        set_move_dir(self)
        self.mins = {0,0,0}
        self.maxs = {0,0,0}
        self.m={
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            0,0,0,1}
        progs:setorigin(self, self.origin)

        self.use=function()
            local spikes = progs:spawn()
            spikes.classname = "spikes"
            spikes.SOLID_TRIGGER = true
            spikes.MOVETYPE_FLY = true
            spikes.velocity = v_scale(self.movedir,200)
            spikes.touch=function(other)
                progs:attach(spikes,"blast",blast)
                take_damage(spikes,spikes,other,25,"Perforated")
                progs:remove(spikes)
            end
            -- ttl
            spikes.nextthink = progs:time() + 5
            spikes.think=function()
                progs:remove(spikes)
            end
            spikes.mangles=mangles

            spikes.mins = {0,0,0}
            spikes.maxs = {0,0,0}
            progs:setorigin(spikes, self.origin) -- v_add(self.origin,{0,0,-1},8))                  
            spikes.skin = 1     
            spikes.frame = "frame1"
            progs:setmodel(spikes,"progs/laser.mdl")
            spikes.mins = {0,0,0}
            spikes.maxs = {0,0,0}
            -- move!
        end
    end
end
return misc