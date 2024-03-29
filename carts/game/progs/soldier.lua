local soldier=function(progs)

    progs:precache_model("progs/soldier.mdl")
    progs:precache_model("progs/ogre.mdl")
    local soldier_poses={
        mdl="progs/soldier.mdl",
        stand={random=true,length=8},
        run={random=true,length=8},
        death={length=10,loop_not=true},
        deathc={length=11,loop_not=true},
        death_poses={"death","deathc"}
    }

    local ogre_poses={
        mdl="progs/ogre.mdl",
        stand={random=true,length=9},        
        run={random=true,length=8},
        death={length=14,loop_not=true},
        bdeath={length=10,loop_not=true},
        death_poses={"death","bdeath"}
    }

    local function init_monster(self,poses)
        self.SOLID_SLIDEBOX = true
        self.MOVETYPE_NONE = true
        --self.MOVETYPE_WALK = true
        self.skin = 1     
        self.frame = "stand1"
        self.mangles = {0,0,self.angle or 0}
        self.health = 30
        progs:setmodel(self, poses.mdl)
        --self.velocity = {0,0,-18}
        --     
        local select_pose=function(name,ttl,think)    
            local pose=poses[name]
            assert(pose, "Unknown pose: "..name)

            local length,anim=pose.length,pose.random and flr(rnd(pose.length)) or 0
            local t0 = progs:time()
            
            -- first frame
            self.frame = name..((anim%length)+1)
            return function()
                anim = anim + 1
                if pose.loop_not then
                    anim = min(anim, length-1)
                end
                self.frame = name..((anim%length)+1)
                local t1 = progs:time()
                self.nextthink = t1 + ttl
                -- gives total elapsed time since last pose switch
                if think then
                    think(anim==length-1, t1-t0)
                end
            end
        end

        self.nextthink = progs:time() + 0.1
        self.think=select_pose(
            "stand",
            0.1,
            function(is_last_frame,t)
                if t>15 then
                    self.think = select_pose("run",0.1)
                end
            end)

        local dead
        self.die=function()
            if dead then
                return
            end
            -- avoid reentrancy
            dead=true
            self.think=select_pose(
                rnd(poses.death_poses),
                0.1,
                function(is_last_frame)
                    if is_last_frame then
                        self.SOLID_NOT = true
                        self.think = nil
                    end
                end)
        end
    end
    progs.monster_army=function(self)
        init_monster(self,soldier_poses)
    end
    progs.monster_ogre=function(self)
        init_monster(self,ogre_poses)
    end
end
return soldier