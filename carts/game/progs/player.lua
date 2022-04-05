local player=function(progs)

    progs.player=function(self)
        self.SOLID_SLIDEBOX=true
        self.eyepos = {0,0,22}

        -- find a suitable pos
        
        self.pre_think=function()
            -- ??
        end

        self.think=function()
        end

        self.post_think=function()
            -- ??
        end

        self.hit=function(dmg,other)
        end

        self.die=function()
        end
    end
end
return player