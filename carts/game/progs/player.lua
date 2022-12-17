local player=function(progs)

    progs:precache_model ("progs/player.mdl")
    progs:precache_model ("progs/v_shot.mdl")
    progs:precache_model ("progs/v_nail.mdl")
    progs:precache_model ("progs/v_shot2.mdl")
    progs:precache_model ("progs/v_rock.mdl")

    -- progs.info_player_start=function(self)
    --     self.SOLID_NOT = true
    --     self.MOVETYPE_NONE = true
    --     self.DRAW_NOT = true
    --     -- set size and link into world
    --     progs:setmodel(self, self.model)
    -- end

    local  DEAD_NO           = 0
    local  DEAD_DYING        = 1
    local  DEAD_DEAD         = 2
    local  DEAD_RESPAWNABLE  = 3

    progs.player=function(self)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_WALK = true
        -- todo: only if camera = self
        self.DRAW_NOT = true

        self.health = 100
        self.max_health = 100
        local dmgtime = 0
        self.deadflag = DEAD_NO
        -- no inventory
        self.items = 0

        self.velocity={0,0,0}
        -- set size and link into world
        self.skin = 1     
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/player.mdl")
        -- liquid depth information
        progs:attach(self,"liquid",{24,48})

        -- from mesh
        local eye_pos = self.model.eyepos
        self.eyepos = eye_pos
        self.eye_offset = 0

        -- default weapon
        progs:attachmodel(self, "progs/v_shot.mdl", "weapon")
        self.ammo = {}
        self.weaponframe = 1

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

        local dust={
            radius={5,8},
            gravity_z=-600,
            ttl={0.1,0.4},
            speed={0,50},
            ramp=3,
            count=20
        }
        local blood={
            radius={2,6},
            gravity_z=-600,
            ttl={0.1,0.4},
            speed={50,75},
            ramp=1
        }

        -- moves
        local moves={
            up={0,1,0},
            down={0,-1,0},
            left={1,0,0},
            right={-1,0,0},
            jump={0,0,4}
        }

        local angle,dangle={0,0,0},{0,0,0}

        local death_angle=0
        local air_time

        local weapon_anim
        local function wait_async(ttl)
            while progs:time()<ttl do
                coroutine.yield()
            end
        end

        local water_move=function()
            if self.health < 0 then
                return
            end

            -- todo: run component pre-think outside?
            self.liquid:update()

            -- todo: add falling damage

            -- -3: Water, the vision is troubled.
            if self.contents==-3 and self.water_level>1 then
                -- not already under water?
                if not air_time then
                    air_time = progs:time() + 10
                end
            else
                air_time = nil
            end
            -- -4: Slime, green acid that hurts the player.
            -- -5: Lava, vision turns red and the player is badly hurt.   
            local dmg = 0
            if self.contents==-5 then
                dmg = 10
            elseif self.contents==-4 then
                dmg = 4
            elseif air_time and progs:time()>air_time then
                -- drowning
                dmg = 2
            end

            if dmg>0 then
                if dmgtime < progs:time() then
                    dmgtime = progs:time() + 0.2
        
                    take_damage(self, nil, nil, dmg*self.water_level)
                end
            end
        end

        self.prethink=function(input)
            -- damping      
            angle[2]=angle[2]*0.8
            dangle = v_scale(dangle,0.6)
      
            water_move()

            -- underwater: change move params
            local jump_scale=1
            if self.water_level>1 then
                self.friction = 0.7
                self.gravity = 0.5
                -- avoid overpowered jump under water
                jump_scale = 0.08
            else
                self.friction = nil
                self.gravity = nil
            end
        
            if self.deadflag >= DEAD_DEAD then
                death_think()
                return
            end
            
            if self.deadflag == DEAD_DYING then
                self.mangles[2]=lerp(self.mangles[2],death_angle,0.8)
                self.eyepos=v_lerp(self.eyepos,{0,0,8},0.8)
                return
            end

            local acc={0,0,0}
            for action,move in pairs(moves) do
              if input:pressed(action) then
                acc=v_add(acc, move)
              end
            end
      
            dangle=v_add(dangle,{input.mdy/8,acc[1]/32,input.mdx/8})
            angle=v_add(angle,dangle,1/24)
          
            local a,dx,dz=angle[3],acc[2],acc[1]
            local c,s=cos(a),sin(a)            
            self.velocity=v_add(self.velocity,{s*dx-c*dz,c*dx+s*dz,((self.on_ground or self.water_level>1) and acc[3]*jump_scale or 0)},60)
            if self.fixangle then
                -- force angle
                angle = self.mangles
                self.fixangle = nil
            else                
                self.mangles = angle
            end

            -- action?
            if input:released("action") then
                local fwd,up = m_fwd(self.m),m_up(self.m)
                local eye_pos = v_add(self.origin,up,24)
                local aim_pos = v_add(eye_pos,fwd,48)
                
                local touched = progs:traceline(self,eye_pos,aim_pos)
                if touched then
                    progs:call(touched,"touch",self)
                end
            end

            if input:released("fire") then
                local fwd,up,right = m_fwd(self.m),m_up(self.m),m_right(self.m)
                local eye_pos = v_add(self.origin,up,16)
                local aim_pos = v_add(eye_pos,fwd,1024)
                
                --[[
                local fireball = progs:spawn()
                fireball.owner = self
                fireball.SOLID_TRIGGER = true
                fireball.MOVETYPE_FLY = true
                fireball.DRAW_NOT=true
                fireball.mins={-8,-8,-8}
                fireball.maxs={8,8,8}
                fireball.velocity = v_scale(fwd,1200)
                fireball.touch=function(other)
                    if other~=self then
                        progs:attach(fireball,"blast",blast)
                        progs:attach(fireball,"fadinglight",{
                            ttl={0.1,0.3},
                            radius={96,112}
                        })
                        progs:remove(fireball)
                    end
                end
                progs:setorigin(fireball,eye_pos)
                progs:attach(fireball,"trail",particles)
                progs:attach(fireball,"light",{
                    radius={64,64}
                })
                ]]
                
                weapon_anim=coroutine.create(function()                    
                    for i=1,6 do
                        self.weaponframe = i
                        wait_async(progs:time()+0.08)
                    end
                    self.weaponframe = 1
                end)
                
                progs:attach(self,"fadinglight",{
                    ttl={0.05,0.1},
                    radius={96,112}
                })

                for i=1,3 do
                    -- spread
                    local a,r=2*rnd(),64*rnd()
                    aim_pos=v_add(aim_pos,right,r*cos(a))
                    aim_pos=v_add(aim_pos,up,r*sin(a))
                    
                    -- immediate hit
                    local hit,hit_pos = progs:traceline(self,eye_pos,aim_pos)
                    -- todo: refactor
                    if hit then
                        local impact = progs:spawn()
                        impact.owner = self
                        impact.SOLID_NOT = true
                        impact.DRAW_NOT = true
                        impact.mins = {0,0,0}
                        impact.maxs = {0,0,0}
                        impact.nextthink = progs:time() + 5
                        impact.think=function()
                            progs:remove(impact)
                        end
                        progs:setorigin(impact,hit_pos)
        
                        if hit.die then
                            take_damage(hit, self, self, 10)
                            progs:attach(impact,"blast",blood)
                        else
                            progs:attach(impact,"blast",dust)
                        end
                    end
                end
            end
        end

        self.postthink=function()
            -- update weapon pos      
            if weapon_anim then
                if coroutine.status(weapon_anim)=="suspended" then
                    coroutine.resume(weapon_anim)
                else
                    weapon_anim = nil
                end
            end

            -- dampen stairs up "jump"
            self.eyepos=v_add(eye_pos,{0,0,self.eye_offset})
            self.eye_offset=lerp(self.eye_offset,0,0.4)
        end

        self.pain=function()
            -- basic pain feedback
            self.mangles[2]=0.05*(1-rnd(2))
        end

        self.die=function()
            if self.deadflag>DEAD_NO then
                return
            end

            self.deadflag = DEAD_DYING
            self.SOLID_NOT = true
            self.SOLID_SLIDEBOX = nil
            self.MOVETYPE_TOSS = true
            local velocity = self.velocity
            if velocity[3] < 10 then
                velocity[3] = velocity[3] + 100 + rnd()*200
            end
            death_angle = rnd()>0.5 and 0.25 or -0.25
        end

        self.switch_weapon=function(model)
            progs:attachmodel(self, model, "weapon")
            weapon_anim = nil
            self.weaponframe = 1
            
            --self.weapon = progs:attachmodel(model)
            --self.ammo[id] = ammo
        end
    end
end
return player