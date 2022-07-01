local player=function(progs)

    progs:precache_model ("progs/v_shot.mdl")
    progs:precache_model ("progs/player.mdl")

    -- progs.info_player_start=function(self)
    --     self.SOLID_NOT = true
    --     self.MOVETYPE_NONE = true
    --     self.DRAW_NOT = true
    --     -- set size and link into world
    --     progs:setmodel(self, self.model)
    -- end

    progs.player=function(self)
        self.SOLID_SLIDEBOX=true
        -- todo: only if camera = self
        self.DRAW_NOT = true
        
        self.velocity={0,0,0}
        -- set size and link into world
        self.skin = 1     
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/player.mdl")

        -- moves
        local moves={
            up={0,1,0},
            down={0,-1,0},
            left={1,0,0},
            right={-1,0,0},
            jump={0,0,9}
        }

        local angle,dangle={0,0,0},{0,0,0}
        self.prethink=function(input)
            -- damping      
            angle[2]=angle[2]*0.8
            dangle = v_scale(dangle,0.6)

            -- todo: less friction not on ground
            self.velocity[1]=self.velocity[1]*0.8
            self.velocity[2]=self.velocity[2]*0.8      
      
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
                
                local touched = progs:traceline(self,eye_pos,aim_pos)
                -- todo: refactor
                if touched and touched.health then
                    touched.health = touched.health - 10
                    if touched.health<=0 then
                        progs:call(touched,"die",self)
                    end
                end
            end
        end

        self.postthink=function(input)
            -- update weapon pos            
        end

        self.hit=function(dmg,other)
        end

        self.die=function()
        end
    end
end
return player