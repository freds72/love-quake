local doors=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("math3d")
    -- p8 compat
    local abs=math.abs

    -- internal helpers
    local function init(self)
        self.classname = "door"
        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true;
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    progs.func_door=function(self)
        -- init entity
        init(self)
        -- default values
        if not self.speed then
		    self.speed = 100
        end
	    if not self.wait then
		    self.wait = 3
        end
	    if not self.lip then
		    self.lip = 8
        end
	    if not self.dmg then
		    self.dmg = 2
        end

        set_move_dir(self)

        local state = 1 -- STATE_BOTTOM

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_add(
            self.pos1,
            self.movedir,
            abs(v_dot(self.movedir,self.size)) - self.lip)

        self.touch=function(other)
            if other.classname ~= "player" then
                return
            end            
            if state~=1 then
                return
            end
            state = 2
            calc_move(self, self.pos2, self.speed)
        end
    end
end
return doors