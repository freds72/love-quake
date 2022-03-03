local triggers=function(progs)
    local subs = require("progs/subs")
    local maths = require("math3d")
    -- p8 compat
    local abs=math.abs

    -- internal helpers
    local function init_button(self)
        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true;
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    -- help: https://www.moddb.com/tutorials/quake-c-touch
    progs.func_button=function(self)
        print_entity(self)

        -- init entity
        init_button(self)
        -- default values
        if not self.speed then
		    self.speed = 40
        end
	    if not self.wait then
		    self.wait = 1
        end
	    if not self.lip then
		    self.lip = 4
        end

        set_move_dir(self)

        self.state = 1 -- STATE_BOTTOM

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_add(
            self.pos1,
            self.movedir,
            abs(v_dot(self.movedir,self.size)) - self.lip)

        self.touch=function(other)
            if other.classname ~= "player" then
                return
            end            
            print("button touched by: "..other.classname.." from:"..v_tostring(self.pos1).." to:"..v_tostring(self.pos2))
            -- todo: move
        end
        self.use=function(other)
            print("button touched by: "..other.classname)
        end
    end
end
return triggers