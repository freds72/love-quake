local player=function(progs)

    progs:precache_model ("progs/player.mdl")

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
        self.dmgtime = 0
        self.deadflag = DEAD_NO
        -- todo: compute
        self.waterlevel = 1

        self.velocity={0,0,0}
        -- set size and link into world
        self.skin = 1     
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/player.mdl")
        -- from mesh
        self.eyepos = self.model.eyepos

        -- moves
        local moves={
            up={0,1,0},
            down={0,-1,0},
            left={1,0,0},
            right={-1,0,0},
            jump={0,0,9}
        }

        local angle,dangle={0,0,0},{0,0,0}

        local death_angle=0
        local water_move=function()
            if self.health < 0 then
                return
            end

            -- todo: add water level support
            -- todo: add falling damage

            local dmg = 2
            if self.contents==-5 then
                dmg = 10
            elseif self.contents==-4 then
                dmg = 4
            end

            if self.contents<-1 then
                if self.dmgtime < progs:time() then
                    self.dmgtime = progs:time() + 0.2
        
                    take_damage(self, nil, nil, dmg*self.waterlevel)
                end
            end
        end

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

        self.prethink=function(input)
            -- damping      
            angle[2]=angle[2]*0.8
            dangle = v_scale(dangle,0.6)
      
            water_move()
            
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
            self.velocity=v_add(self.velocity,{s*dx-c*dz,c*dx+s*dz,(self.on_ground and acc[3] or 0)},60)
            self.mangles = angle

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
                local fwd,up = m_fwd(self.m),m_up(self.m)
                local eye_pos = v_add(self.origin,up,16)
                local aim_pos = v_add(eye_pos,fwd,1024)
                
                local fireball = progs:spawn()
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

                -- immediate hit
                local touched = progs:traceline(self,eye_pos,aim_pos)
                -- todo: refactor
                if touched and touched.die then
                    take_damage(touched, self, self, 10)
                end
            end
        end

        self.postthink=function(input)
            -- update weapon pos            
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
    end
end
return player