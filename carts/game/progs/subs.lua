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
            local angle=math.pi*angle/180
            self.movedir={math.cos(angle),math.sin(angle),0}
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
        self.nextthink = progs:time() + traveltime
        self.think = function(self)
            progs:setorigin(self,tdest)
            self.velocity = nil   
            -- chain additional logic?         
            if func then
                func()
            end
        end
    end

    function print_entity(self)
        print("---- "..self.classname.." -----")
        for k,v in pairs(self) do
            print(k..":"..tostring(v))
        end
    end

    -- find all targets from the given entity and "use" them
    -- optional random flag to pick only target
    function use_targets(self,other,random)
        if self.killtarget then
            local targets = progs:find(self,"targetname", self.killtarget)
            print("killing:"..self.killtarget.." matches: "..#targets)
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
                print("picking entity: "..i.."/"..#targets)
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
end

return subs