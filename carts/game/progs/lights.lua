local lights=function(progs)

    -- p8 compat
    local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot

    progs.light = function(self)
        local on_off = band(self.spawnflags or 0,1)==1
        self.SOLID_NOT = true
        progs:setmodel(self)

        self.use = function()
            local id = tonumber(self.style)
            if id<32 then
                return
            end

            progs:lightstyle(id,on_off and "m" or "a")
            on_off = not on_off
        end
    end
end
return lights