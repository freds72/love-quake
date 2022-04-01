local buttons=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("math3d")
    -- p8 compat
    local abs=math.abs

    -- internal helpers
    local function init_button(self)
        self.sequence = 1
        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true;
        -- set size and link into world
        progs:setmodel(self, self.model)

        -- create trigger field
        local trigger = progs:spawn()
        trigger.MOVETYPE_NONE = true
        trigger.SOLID_TRIGGER = true
        trigger.DRAW_NOT = true
        trigger.owner = self
        trigger.mins = v_add(self.mins, {-8,-8,-8})                
        trigger.maxs = v_add(self.maxs, {8,8,8})                
        trigger.touch=function(other)
            if self.use then
                self.use(other)
            end
        end
        progs:setorigin(trigger,self.origin)        
    end

    -- classname bindings
    -- help: https://www.moddb.com/tutorials/quake-c-touch
    progs.func_button=function(self)
        -- init entity
        init_button(self)
        -- default values
        set_defaults(self,{
            speed=40,
            wait=1,
            lip=4
        })
        set_move_dir(self)

        local state = 1 -- STATE_BOTTOM

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_add(
            self.pos1,
            self.movedir,
            abs(v_dot(self.movedir,self.size)) - self.lip)

        self.use=function(other)
            if other.classname ~= "player" then
                return
            end            
            if state~=1 then
                return
            end
            state = 2

            -- texture
            self.sequence = 2
            -- trigger action (if any)
            use_targets(self)
            
            -- move            
            calc_move(self, self.pos2, self.speed, function()
                -- wait
                state = 3
                -- prepare for re-trigger
                if self.wait > 0 then
                    self.nextthink = progs:time() + self.wait
                    -- going reverse
                    self.think = function()
                        calc_move(self, self.pos1, self.speed, function()
                            state = 1
                            self.sequence = 1
                        end)
                    end
                end
            end)
        end
    end
end
return buttons