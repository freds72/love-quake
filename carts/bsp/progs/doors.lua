local doors=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("math3d")
    -- p8 compat
    local abs=math.abs
    local add=table.insert

    -- internal helpers
    local function init(self)
        -- easier to find siblings
        self.classname = "door"

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

        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true;
        -- set size and link into world
        progs:setmodel(self, self.model)
    end

    -- classname bindings
    progs.func_door=function(self)
        -- init entity
        init(self)

        set_move_dir(self)

        local state = 1 -- STATE_BOTTOM

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_add(
            self.pos1,
            self.movedir,
            abs(v_dot(self.movedir,self.size)) - self.lip)

        local linked_doors={}

        -- remote triggered doors don't need to be linked
        if not self.targetname then
            -- wait until everything has already been set
            self.nextthink = progs:time() + 0.1
            self.think=function()
                if self.owner then
                    -- already linked
                    return
                end
                local doors = progs:find(self, "classname", self.classname)
                for _,door in pairs(doors) do
                    local mins,maxs=make_v(door.maxs,self.mins),make_v(self.maxs,door.mins)
                    if 
                        mins[1]<=0 and mins[2]<=0 and mins[3]<=0 and
                        maxs[1]<=0 and maxs[2]<=0 and maxs[3]<=0 then
                        -- overlap
                        door.owner = self
                        add(linked_doors, door)
                    end                
                end
            end
        end

        self.use=function()
            if state~=1 then
                return
            end
            state = 2
            calc_move(self, self.pos2, self.speed,function()
                state = 3
                -- wait?
                if self.wait > 0 then
                    self.nextthink = progs:time() + self.wait
                    -- going reverse
                    self.think = function()
                        calc_move(self, self.pos1, self.speed, function()
                            state = 1
                        end)
                    end
                end
            end)

            for _,other in pairs(linked_doors) do
                other.use()
            end
        end

        self.touch=function(other)
            if self.targetname then
                -- not triggered by touch

                -- any "supporting" message?
                if self.message then
                    progs:print(self.message)
                end
                return                
            end

            if self.owner then
                -- linked door
                self.owner.touch(other)
                return
            end
            if other.classname ~= "player" then
                return
            end 
            self.use()           
        end        
    end
end
return doors