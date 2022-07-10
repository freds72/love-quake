local subs=function(progs)
    local maths3d=require("engine.maths3d")

    function set_move_dir(self)
        local angle = self.angle or 0
        if angle == -1 then
            -- up
            self.movedir = {0,0,1}
        elseif angle == -2 then
            -- down
            self.movedir = {0,0,-1}
        else
            local angle=angle/180
            self.movedir={cos(angle),sin(angle),0}
        end
        
        self.angles = {0,0,0}
        -- kill "move" angle
        self.angle = nil
    end

    function calc_move(self, tdest, tspeed, func)
        if not tspeed then
            progs:objerror("No speed is defined!")
        end
            
        -- set destdelta to the vector needed to move
        local vdestdelta = make_v(self.origin, tdest)
        
        -- calculate length of vector
        local len = v_len(vdestdelta)
        
        -- divide by speed to get time to reach dest
        local traveltime = len / tspeed

        if traveltime < 0.03 then
            traveltime = 0.03
        end    

        -- scale the destdelta vector by the time spent traveling to get velocity
        self.velocity = v_scale(vdestdelta, 1/traveltime)

        -- set nextthink to trigger a think when dest is reached
        self.nextthink = self.ltime + traveltime
        self.think = function()
            progs:setorigin(self,tdest)
            self.velocity = {0,0,0}
            -- chain additional logic?         
            if func then
                func()
            end
        end
    end

    -- convert entity to string
    function e_tostring(self)
        local s="---- "..tostring(self.classname).."["..tostring(self).."] -----\n"
        for k,v in pairs(self) do
            if type(v)=="table" and #v==3 then
                s=s..k..":"..v_tostring(v)
            else
                s=s..k..":"..tostring(v)
            end
            s=s.."\n"
        end
        return s
    end

    -- find all targets from the given entity and "use" them
    -- optional random flag to pick only target
    function use_targets(self,other,random)
        if self.killtarget then
            local targets = progs:find(self,"targetname", self.killtarget)
            printh("killing:"..self.killtarget.." matches: "..#targets)
            for i=1,#targets do
                progs:remove(targets[i])
            end
        end

        if self.target then
            local targets = progs:find(self,"targetname", self.target, "use")
            if random then            
                if #targets==0 then
                    return
                end
                local i = flr(rnd(1,#targets))
                targets[i].use(other)
            else
                for i=1,#targets do
                    targets[i].use(other)
                end
            end
        end    
    end

    function makevectors(fwd)
        local m=make_m_look_at({0,0,1},fwd)
        return m_right(m),m_fwd(m),m_up(m)
    end

    -- apply the given key/value collection to self
    function set_defaults(self,defaults)
        for k,v in pairs(defaults) do
            self[k] = self[k] or v
        end    
    end

    function killed(self, attacker)
        self.health = max(self.health,-99)

        if self.MOVETYPE_PUSH or self.MOVETYPE_NONE then
            -- doors, triggers, etc
            self.die(attacker)
            return
        end

        self.touch = nil
        self.die()
    end

    function take_damage(ent, inflictor, attacker, damage)
        if not ent.health then
            return
        end
        -- do the damage
        ent.health = ent.health - damage
        
        if ent.health <= 0 then
            killed(ent, attacker)
            return
        end

        if ent.pain then
            ent.pain(attacker, damage)
        end
    end

    function take_heal(ent, healamount, ignore)
        -- already dead?
	    if ent.health <= 0 then
		    return
        end

	    if (not ignore) and (ent.health >= ent.max_health) then
		    return
        end
	    local healamount = ceil(healamount)

	    ent.health = ent.health + healamount
	    if (not ignore) and (ent.health >= ent.max_health) then
		    ent.health = ent.max_health
        end
		
        ent.health=min(ent.health, 250)
	    return true
    end
end

return subs