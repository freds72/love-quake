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
        set_defaults(self,{
            spawnflags=0,
            speed=100,
            wait=3,
            lip=8,
            dmg=2
        })

        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true

        -- set size and link into world
        progs:setmodel(self, self.model)        
    end

    -- classname bindings
    progs.func_door=function(self)
        -- constants
        local DOOR_START_OPEN = 1
        local DOOR_DONT_LINK = 4

        -- init entity
        init(self)

        set_move_dir(self)

        local state = 1 -- STATE_BOTTOM

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_add(
            self.pos1,
            self.movedir,
            abs(v_dot(self.movedir,self.size)) - self.lip)

        -- starts open?
        if band(self.spawnflags,DOOR_START_OPEN)~=0 then
            self.pos1,self.pos2=self.pos2,self.pos1
            progs:setorigin(self,self.pos1)
        end

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
                local mins,maxs=v_add(self.mins,{-8,-8,-8}),v_add(self.maxs,{8,8,8})
                --local mins,maxs=self.mins,self.maxs
                local link_mins,link_maxs=self.mins,self.maxs
                -- note: assumes doors are in closed position/origin = 0 0 0
                for _,door in pairs(doors) do
                    if  mins[1]<=door.maxs[1] and maxs[1]>=door.mins[1] and
                        mins[2]<=door.maxs[2] and maxs[2]>=door.mins[2] and
                        mins[3]<=door.maxs[3] and maxs[3]>=door.mins[3] then
                        -- overlap
                        door.owner = self
                        -- extend min/maxs
                        link_mins=v_min(link_mins, door.mins)
                        link_maxs=v_max(link_maxs, door.maxs)
                        add(linked_doors, door)
                    end                
                end
                -- spawn a big trigger field around
                local trigger = progs:spawn()
                trigger.MOVETYPE_NONE = true
                trigger.SOLID_TRIGGER = true
                trigger.DRAW_NOT = true
                trigger.owner = self
                trigger.mins = v_add(link_mins, {-60,-60,-8})                
                trigger.maxs = v_add(link_maxs, {60,60,8})                
                trigger.touch=function(other)
                    if self.touch then
                        self.touch(other)
                    end
                end
                progs:setorigin(trigger,self.origin)
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
                -- linked door (or trigger field)
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
        set_defaults(self,{
            speed=50,
            dmg = 2,
            wait = 5
        })
        set_move_dir(self)        

        local oldorigin = v_clone(self.origin)
        local state = 1

        local function fd_secret_move6()
            calc_move(self, oldorigin, self.speed, function()
                state = 1
            end)
        end
        -- Wait 1 second...
        local function fd_secret_move5()
            self.nextthink = progs:time() + 1.0
            self.think = fd_secret_move6            
        end
                
        -- Move backward...
        local function fd_secret_move4()
            calc_move(self, self.dest1, self.speed, fd_secret_move5)
        end

        -- Wait here until time to go back...
        local function fd_secret_move3()
            if band(self.spawnflags,SECRET_OPEN_ONCE)==0 then
                self.nextthink = progs:time() + self.wait
                self.think = fd_secret_move4
            end
        end

        -- Start moving sideways w/sound...
        local function fd_secret_move2()
            calc_move(self, self.dest2, self.speed, fd_secret_move3)
        end

        -- Wait after first movement...
        local function fd_secret_move1()
            self.nextthink = progs:time() + 1.0
            self.think = fd_secret_move2
        end 

        local function fd_secret_use()
            -- ??
            self.health = 10000
        
            -- exit if still moving around...
            if state~=1 then
                return
            end
            state = 2

            self.message = nil  -- no more message
        
            use_targets(self) -- fire all targets / killtargets
            
            self.velocity = {0,0,0}
        
            -- Make a sound, wait a little...
            self.nextthink = progs:time() + 0.1
        
            local temp = 1 - band(self.spawnflags,SECRET_1ST_LEFT) -- 1 or -1

            local v_right,v_fwd,v_up = makevectors(self.movedir)
            if band(self.spawnflags,SECRET_1ST_DOWN)~=0 then
                local len = abs(v_dot(v_up,self.size))
                self.dest1 = v_add(self.origin,v_up,-len)
            else
                local len = abs(v_dot(v_right,self.size))
                self.dest1 = v_add(self.origin,v_right,temp*len)
            end
        
            local t_length = abs(v_dot(v_fwd,self.size))
            self.dest2 = v_add(self.dest1,v_fwd,t_length)

            calc_move(self, self.dest1, self.speed, fd_secret_move1)            
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

        self.use=fd_secret_use
    end
end
return doors