local soldier=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model("progs/soldier.mdl")
    local poses={
        stand=8,
        run=8,
        death=10
    }

    progs.monster_army=function(self)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_NONE = true
        self.skin = 1     
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        progs:setmodel(self, "progs/soldier.mdl")

        --     
        local select_pose=function(pose,ttl,think)    
            local count,anim=poses[pose],0
            local t0 = progs:time()
            assert(count, "Unknown pose: "..pose)
            -- first frame
            self.frame = pose..((anim%count)+1)
            return function()
                anim = anim+1   
                self.frame = pose..((anim%count)+1)
                local t1=progs:time()
                self.nextthink = t1 + ttl
                -- gives total elapsed time since last pose switch
                if think then
                    think(anim, t1-t0)
                end
            end
        end

        self.nextthink = progs:time() + 0.1
        self.think=select_pose(
            "stand",
            0.1,
            function(frame,t)
                if t>15 then
                    self.think = select_pose("run",0.1)
                end
            end)

        self.use=function()
            -- avoid reentrancy
            self.use=nil
            self.think=select_pose(
                "death",
                0.1,
                function(frame)
                    if frame==9 then
                        self.SOLID_NOT = true
                        self.think = nil
                    end
                end)
        end
    end
end
return soldier