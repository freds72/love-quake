local doors=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("math3d")
    -- p8 compat
    local abs,band=math.abs,bit.band
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

    progs.func_door_secret=function(self)
        local SECRET_OPEN_ONCE = 1      -- stays open
        local SECRET_1ST_LEFT = 2       -- 1st move is left of arrow
        local SECRET_1ST_DOWN = 4       -- 1st move is down from arrow
        local SECRET_NO_SHOOT = 8       -- only opened by trigger
        local SECRET_YES_SHOOT = 16     -- shootable even if targeted
        
        -- init entity
        init(self)
        self.speed = 50
        if not self.dmg then
		    self.dmg = 2
        end
        if not self.wait then
		    self.wait = 5 --  5 seconds before closing       
        end
        
        self.mangle = {0,0,0}
        self.angles = {0,0,0}

        local oldorigin = v_clone(self.origin)
        local state = 1

        local function fd_secret_use()
            self.health = 10000
        
            -- exit if still moving around...
            if state~=1 then
                return
            end
            
            self.message = nil  -- no more message
        
            use_targets(self) -- fire all targets / killtargets
            
            self.velocity = {0,0,0}
        
            -- Make a sound, wait a little...
            self.nextthink = progs:time() + 0.1
        
            local temp = 1 - band(self.spawnflags,SECRET_1ST_LEFT) -- 1 or -1

            local v_fwd,v_right,v_up = makevectors(unpack(self.mangle))
            
            if not self.t_width then
                if band(self.spawnflags,SECRET_1ST_DOWN)~=0 then
                    self.t_width = abs(v_dot(v_up,self.size))
                else
                    self.t_width = abs(v_dot(v_right,self.size))
                end
            end
                
            if  not self.t_length then
                self.t_length = abs(v_dot(v_fwd,self.size))
            end
        
            if band(self.spawnflags,SECRET_1ST_DOWN)~=0 then
                self.dest1 = v_add(self.origin,v_up,self.t_width)
            else
                self.dest1 = v_add(self.origin,v_right,self.t_width * temp)
            end

            self.dest2 = v_add(self.dest1,v_fwd,self.t_length)

            calc_move(self, self.dest1, self.speed, fd_secret_move1)            
        end
        
        -- Wait after first movement...
        local function fd_secret_move1()
            self.nextthink = progs:time() + 1.0
            self.think = fd_secret_move2
        end

        -- Start moving sideways w/sound...
        local function fd_secret_move2()
            calc_move(self, self.dest2, self.speed, fd_secret_move3)
        end

        -- Wait here until time to go back...
        local function fd_secret_move3()
            if band(self.spawnflags,SECRET_OPEN_ONCE)==0 then
                self.nextthink = progs:time() + self.wait
                self.think = fd_secret_move4
            end
        end
        
        -- Move backward...
        local function fd_secret_move4()
            calc_move(self, self.dest1, self.speed, fd_secret_move5)
        end

        -- Wait 1 second...
        local function fd_secret_move5()
            self.nextthink = progs:time() + 1.0
            self.think = fd_secret_move6            
        end
        
        local function fd_secret_move6()
            calc_move(self, oldorigin, self.speed, function()
                state = 1
            end)
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

            fd_secret_use()
        end
    end
end
return doors