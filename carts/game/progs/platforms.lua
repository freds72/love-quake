local platforms=function(progs)
    local subs = require("progs/subs")(progs)
    local maths = require("engine.maths3d")

    local STATE_TOP     = 0
    local STATE_BOTTOM  = 1
    local STATE_UP      = 2
    local STATE_DOWN    = 3
    local PLAT_LOW_TRIGGER = 1

    -- internal helpers
    local function init(self)
        -- easier to find siblings
        self.classname = "plat"

        -- default values
        set_defaults(self,{
            spawnflags=0,
            speed=150,
            dmg=2,
            velocity={0,0,0},
            height=0
        })

        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true
        self.MOVING_BSP = true
        
        -- set size and link into world
        progs:setmodel(self, self.model)  
    end


    -- classname bindings
    progs.func_plat=function(self)
        -- init entity
        init(self)

        set_move_dir(self)

        local state = STATE_UP

        self.pos1 = v_clone(self.origin)
        self.pos2 = v_clone(self.origin)
        if  self.height>0 then
            self.pos2[3] = self.origin[3] - self.height
        else
            self.pos2[3] = self.origin[3] - self.size[3] + 8
        end

        -- forward decl
        local plat_hit_bottom,plat_hit_top,plat_go_down,plat_go_up,plat_use,plat_trigger_use,plat_center_touch

        -- 
        local function plat_spawn_inside_trigger()       
            --
            -- middle trigger
            --	
            local trigger = progs:spawn()
            trigger.MOVETYPE_NONE = true
            trigger.SOLID_TRIGGER = true
            trigger.DRAW_NOT = true
            trigger.owner = self
            trigger.touch = plat_center_touch
            local tmin = v_add(self.mins,{25,25,0})
            local tmax = v_add(self.maxs,{25,25,-8},-1)

            tmin[3] = tmax[3] - (self.pos1[3] - self.pos2[3] + 8)
            if band(self.spawnflags,PLAT_LOW_TRIGGER)~=0 then
                tmax[3] = tmin[3] + 8
            end

            if self.size[1] <= 50 then
                tmin[1]= (self.mins[1] + self.maxs[1]) / 2
                tmax[1]= tmin[1] + 1;
            end
            if self.size[2] <= 50 then
                tmin[2] = (self.mins[2] + self.maxs[2]) / 2
                tmax[2] = tmin[2] + 1
            end
            trigger.mins = tmin
            trigger.maxs = tmax
            progs:setorigin(trigger,self.origin)
        end

        plat_hit_bottom=function()
            state = STATE_BOTTOM
        end
        
        plat_hit_top=function()
            state = STATE_TOP
            self.think = plat_go_down
            self.nextthink = self.ltime + 3
        end

        plat_go_down=function ()
            state = STATE_DOWN
            calc_move(self, self.pos2, self.speed, plat_hit_bottom)
        end
        
        plat_go_up=function()
            state = STATE_UP
            calc_move(self, self.pos1, self.speed, plat_hit_top)
        end

        plat_use=function ()
            self.use=nil
            if state~=STATE_UP then
                return
            end
            plat_go_down()
        end 

        plat_trigger_use=function ()
            if self.think then
                return
            end
            plat_go_down()
        end

        plat_center_touch = function(other)
            if other.classname ~= "player" then
                return
            end
                
            if other.health and other.health <= 0 then
                return
            end
        
            if state == STATE_BOTTOM then
                plat_go_up()
            elseif state == STATE_TOP then
                self.nextthink = self.ltime + 1	-- delay going down
            end
        end

        local plat_crush=function(other)
            take_damage(other, self, self, 1, "squish")
            
            if state == STATE_UP then
                plat_go_down()
            elseif state == STATE_DOWN then
                plat_go_up()
            else
                assert(false,"invalid plat state: "..state)
            end
        end

        if self.height>0 then
		    self.pos2[3] = self.origin[3] - self.height
	    else
		    self.pos2[3] = self.origin[3] - self.size[3] + 8
        end

        self.blocked = plat_crush
        self.use = plat_trigger_use

        plat_spawn_inside_trigger() -- the "start moving" trigger	

        -- remote triggered plat
        if self.targetname then
            state = STATE_UP
            self.use = plat_use
        else
            progs:setorigin(self, self.pos2)
		    state = STATE_BOTTOM
        end
    end

    -- moving platforms
    progs.func_train=function(self)
        if not self.target then
            progs:objerror("func_train without a target")
        end

        -- default values
        set_defaults(self,{
            spawnflags=0,
            speed=100,
            dmg=2,
            velocity={0,0,0},
            attack_finished=0
        })

        self.SOLID_BSP = true
        self.MOVETYPE_PUSH = true
        self.MOVING_BSP = true
        
        -- set size and link into world
        progs:setmodel(self, self.model)  

        local train_next,func_train_find
        
        local train_blocked=function(other)
            if progs:time() < self.attack_finished then
                return
            end
            self.attack_finished = progs:time() + 0.5
            
            take_damage(other, self, self, self.dmg, "squish")
        end
        
        local train_use = function()
            if self.think ~= func_train_find then
                return  -- already activated
            end
            train_next()
        end
        
        local train_wait = function()
            if self.wait~=0 then
                self.nextthink = self.ltime + self.wait
                --sound (self, CHAN_NO_PHS_ADD+CHAN_VOICE, self.noise, 1, ATTN_NORM);
            else
                self.nextthink = self.ltime + 0.1
            end
            
            self.think = train_next
        end
        
        train_next = function()
            local target = progs:find(self,"targetname", self.target)[1]
            assert(target,"func_train target not found: "..self.target)
            self.target = target.target
            if not self.target then
                progs:objerror("train_next: no next target")
            end
            if target.wait~=0 then
                self.wait = target.wait
            else
                self.wait = 0
            end

            -- sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
            calc_move(self, v_add(target.origin,self.mins,-1), self.speed, train_wait)
        end
        
        func_train_find = function()        
            local target = progs:find(self, "targetname", self.target)[1]
            assert(target,"func_train target not found: "..self.target)
            self.target = target.target
            progs:setorigin(self, v_add(target.origin,self.mins,-1))

            if not self.targetname then            
                -- not triggered, so start immediately
                self.nextthink = self.ltime + 0.1
                self.think = train_next
            end
        end
                
        --[[
        if (self.sounds == 0)
        {
            self.noise = ("misc/null.wav");
            precache_sound ("misc/null.wav");
            self.noise1 = ("misc/null.wav");
            precache_sound ("misc/null.wav");
        }
    
        if (self.sounds == 1)
        {
            self.noise = ("plats/train2.wav");
            precache_sound ("plats/train2.wav");
            self.noise1 = ("plats/train1.wav");
            precache_sound ("plats/train1.wav");
        }
        ]]

        self.cnt = 1
        self.blocked = train_blocked
        self.use = train_use
        self.classname = "train"
    
        -- start trains on the second frame, to make sure their targets have had
        -- a chance to spawn
        self.nextthink = self.ltime + 0.1
        self.think = func_train_find            
    end
end
return platforms