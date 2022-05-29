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
            action={0,0,6.2}
        }

        self.prethink=function(input)
            self.velocity[1]=self.velocity[1]*0.8
            self.velocity[2]=self.velocity[2]*0.8      
      
            local acc={0,0,0}
            for action,move in pairs(moves) do
              if input:pressed(action) then
                acc=v_add(acc, move)
              end
            end
      
            local a,dx,dz=0,acc[2],acc[1]
            local c,s=cos(2*3.1415*a/360),sin(2*3.1415*a/360)
            self.velocity=v_add(self.velocity,{s*dx-c*dz,c*dx+s*dz,(self.on_ground and acc[3] or 0)-0.5})
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