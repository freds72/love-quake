local subs=function(progs)
    local math3d=require("math3d")

    function set_move_dir(self)
        local angle = self.angle
        if angle == -1 then
            -- up
            self.movedir = {0,0,1}
        elseif angle == -2 then
            -- down
            self.movedir = {0,0,-1}
        else
            --local m = make_m_from_euler(0,2*3.1415*angle/360,0)
            angle = 2*3.1415*angle/360
            self.movedir = {
                math.cos(angle),
                math.sin(angle),
                0
            }
        end
        
        self.angles = {0,0,0}
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
            self.origin = v_clone(tdest)
            self.velocity = nil            
            if func then
                func()
            end
        end
    end

    function print_entity(self)
        for k,v in pairs(self) do
            print(k..":"..tostring(v))
        end
    end
end

return subs