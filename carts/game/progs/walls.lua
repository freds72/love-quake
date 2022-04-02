local walls=function(progs)
    progs.func_wall=function(self)
        self.SOLID_BSP = true
        self.MOVETYPE_NONE = true
        -- set size and link into world
        progs:setmodel(self, self.model)

        self.use=function()
            -- kill
            self.use = nil

            -- switch texture
            self.sequence=2
        end
    end

    progs.func_bossgate=function(self)
        self.SOLID_BSP = true
        self.MOVETYPE_NONE = true
        -- set size and link into world
        progs:setmodel(self, self.model)

        -- todo: disapear when all four runes are collected
    end

    progs.func_illusionary=function(self)
        self.SOLID_NOT = true
        self.MOVETYPE_NONE = true;        
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

end
return walls