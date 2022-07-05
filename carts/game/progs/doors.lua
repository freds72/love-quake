local doors=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("engine.maths3d")

    local STATE_TOP     = 0
    local STATE_BOTTOM  = 1
    local STATE_UP      = 2
    local STATE_DOWN    = 3
    
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
            dmg=2,
            health=0,
            velocity={0,0,0},
            attack_finished=0
        })

        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true
        self.MOVING_BSP = true
        
        -- set size and link into world
        progs:setmodel(self, self.model)  
    end

    -- classname bindings
    progs.func_door=function(self)
        -- constants
        local DOOR_START_OPEN = 1
        local DOOR_DONT_LINK = 4
        local DOOR_TOGGLE = 32

        -- init entity
        init(self)

        set_move_dir(self)

        self.state = STATE_BOTTOM

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

        local door_blocked,door_hit_top,door_hit_bottom,door_go_down,door_go_up,door_fire,door_use,door_trigger_touch,door_killed,door_touch

        door_blocked=function(other)
            -- todo: fix goalentity
            take_damage(other, self, self.goalentity, self.dmg, "squish")

            -- if a door has a negative wait, it would never come back if blocked,
            -- so let it just squash the object to death real fast
            if self.wait >= 0 then
                if self.state == STATE_DOWN then
                    door_go_up ()
                else
                    door_go_down ()
                end
            end
        end

        door_hit_top=function()
            -- sound (self, CHAN_NO_PHS_ADD+CHAN_VOICE, self.noise1, 1, ATTN_NORM);
            self.state = STATE_TOP

            if band(self.spawnflags, DOOR_TOGGLE)~=0 then
                return         -- don't come down automatically
            end
            
            local oself=self

            self.think = function() self=oself door_go_down() end
            self.nextthink = self.ltime + self.wait
        end
        
        door_hit_bottom=function()
            -- sound (self, CHAN_NO_PHS_ADD+CHAN_VOICE, self.noise1, 1, ATTN_NORM);
            self.state = STATE_BOTTOM
        end
        
        door_go_down=function()
            -- sound (self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
            if self.max_health then
                -- self.takedamage = DAMAGE_YES;
                self.health = self.max_health
            end
            
            self.state = STATE_DOWN
            local oself=self
            calc_move(self, self.pos1, self.speed, function() self=oself door_hit_bottom() end)
        end
        
        door_go_up=function()
            if self.state == STATE_UP then
                return         -- allready going up
            end
        
            if self.state == STATE_TOP then
                -- reset top wait time
                self.nextthink = self.ltime + self.wait
                return
            end
            
            --sound (self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);

            self.state = STATE_UP
            local oself=self
            calc_move(self, self.pos2, self.speed, function() self=oself door_hit_top() end)
        
            use_targets(self) -- fire all targets / killtargets
        end

        door_fire=function()
            -- play use key sound  
            --[[      
            if self.items then
                sound (self, CHAN_VOICE, self.noise4, 1, ATTN_NORM)
            end
            ]]
        
            self.message = nil
            local oself=self
            if band(self.spawnflags,DOOR_TOGGLE)~=0 then
                if self.state == STATE_UP or self.state == STATE_TOP then
                    local door=self.owner
                    while door do
                        self=door
                        door_go_down()
                        door = door.enemy
                    end
                    self=oself
                    return
                end
            end
            
            -- trigger all paired doors
            local door=self.owner
            while door do
                self=door
                door_go_up()
                door = door.enemy
            end
            self=oself
        end
                
        door_use=function()
            --assert(self.owner,"invalid door owner: "..e_tostring(self))
            self.message = nil -- door message are for touch only
            self.owner.message = nil
        
            local oself=self
            self = self.owner
            door_fire()
            self = oself
        end        
        
        door_trigger_touch=function(other)
            if other.health <= 0 then
                return
            end
        
            if progs:time() < self.attack_finished then
                return
            end
            self.attack_finished = progs:time() + 1
        
            local oself = self
            self = self.owner
            door_use()
            self = oself
        end
                
        door_killed=function()
            local oself = self
            self = self.owner
            self.health = self.max_health
            --self.takedamage = DAMAGE_NO;    // wil be reset upon return
            door_use()
            self = oself
        end

        door_touch=function(other)
            if other.classname ~= "player" then
                return
            end 
            if self.owner.attack_finished > progs:time() then
                return
            end

            self.owner.attack_finished = progs:time() + 2

            if self.owner.message then
                progs:print(self.owner.message)
            end
            
            -- door is triggered by something
            if self.targetname then
                return
            end

            -- key door stuff
            --[[
            if (!self.items)
                return;
            ]]

            -- todo: item management

            self.touch = nil
            if self.enemy then
                -- kill touch for linked door
                self.enemy.touch = nil
            end
            door_use()
        end

        self.blocked = door_blocked
        self.use = door_use
        self.touch = door_touch

        -- wait until everything has already been set
        self.nextthink = progs:time() + 0.1
        self.think=function()
            if self.owner then
                -- already linked
                return
            end
            -- cannot be linked
            if band(self.spawnflags,DOOR_DONT_LINK)~=0 then
                self.owner = self
                return
            end

            local doors = progs:find(self, "classname", self.classname)
            local mins,maxs=v_add(self.mins,{-8,-8,-8}),v_add(self.maxs,{8,8,8})
            --local mins,maxs=self.mins,self.maxs
            local link_mins,link_maxs=self.mins,self.maxs
            -- note: assumes doors are in closed position/origin = 0 0 0
            local prev=self
            self.owner = self
            for _,door in pairs(doors) do
                -- overlap?
                if  mins[1]<=door.maxs[1] and maxs[1]>=door.mins[1] and
                    mins[2]<=door.maxs[2] and maxs[2]>=door.mins[2] and
                    mins[3]<=door.maxs[3] and maxs[3]>=door.mins[3] then
                    -- link to "master" door
                    door.owner = self
                    -- create linked door chain
                    prev.enemy = door
                    if door.health>0 then
                        self.health = door.health
                    end
                    if door.targetname then
                        self.targetname = door.targetname
                    end
                    if door.message then
                        self.message = door.message
                    end
                    -- extend min/maxs
                    link_mins=v_min(link_mins, door.mins)
                    link_maxs=v_max(link_maxs, door.maxs)
                    -- move on
                    prev = door
                end                
            end

            -- cannot be self triggered
			if self.health>0 or self.targetname then
                return
            end
            -- todo: items
            --[[
            if self.items then
                return
            end
            ]]
            
            -- spawn a big trigger field around
            local trigger = progs:spawn()
            trigger.MOVETYPE_NONE = true
            trigger.SOLID_TRIGGER = true
            trigger.DRAW_NOT = true
            trigger.owner = self
            trigger.mins = v_add(link_mins, {-60,-60,-8})                
            trigger.maxs = v_add(link_maxs, {60,60,8})                
            trigger.touch = door_trigger_touch
            progs:setorigin(trigger,{0,0,0})
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
            wait = 5,
            attack_finished=0
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
            self.nextthink = self.ltime + 1.0
            self.think = fd_secret_move6            
        end
                
        -- Move backward...
        local function fd_secret_move4()
            calc_move(self, self.dest1, self.speed, fd_secret_move5)
        end

        -- Wait here until time to go back...
        local function fd_secret_move3()
            if band(self.spawnflags,SECRET_OPEN_ONCE)==0 then
                self.nextthink = self.ltime + self.wait
                self.think = fd_secret_move4
            end
        end

        -- Start moving sideways w/sound...
        local function fd_secret_move2()
            calc_move(self, self.dest2, self.speed, fd_secret_move3)
        end

        -- Wait after first movement...
        local function fd_secret_move1()
            self.nextthink = self.ltime + 1.0
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
            self.nextthink = self.ltime + 0.1
        
            local temp = 1 - band(self.spawnflags,SECRET_1ST_LEFT) -- 1 or -1

            local v_right,v_fwd,v_up = makevectors(self.movedir)
            if band(self.spawnflags,SECRET_1ST_DOWN)~=0 then
                -- magic +2 to avoid sticking into walls (why???)
                local len = abs(v_dot(v_up,self.size)) + 2
                self.dest1 = v_add(self.origin,v_up,-len)
            else
                local len = abs(v_dot(v_right,self.size)) + 2
                self.dest1 = v_add(self.origin,v_right,temp*len)
            end
        
            local len = abs(v_dot(v_fwd,self.size))
            self.dest2 = v_add(self.dest1,v_fwd,len)

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

        self.blocked=function(other)
            if progs:time() < self.attack_finished then
                return
            end
            self.attack_finished = progs:time() + 0.5
            take_damage(other, self, self, self.dmg, "squish")
        end
    end
end
return doors