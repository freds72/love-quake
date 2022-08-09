local items=function(progs)

    -- p8 compat
    local band=bit.band

    progs:precache_model("maps/b_shell0.bsp")
    progs:precache_model("maps/b_bh10.bsp")
    progs:precache_model("maps/b_bh100.bsp")
    progs:precache_model("maps/b_bh25.bsp")

    local H_ROTTEN = 1
    local H_MEGA = 2

    local IT_KEY1 = 0x20000
    local IT_KEY2 = 0x40000

    local function start_item(self)
        self.nextthink = progs:time() + 0.2
        -- plants the object on the floor
        self.think = function()
            self.FL_ITEM = true
            self.SOLID_TRIGGER = true
            self.MOVETYPE_TOSS = true
            self.velocity = {0,0,0}
            progs:setorigin(self, v_add(self.origin, {0,0,6}))
            progs:drop_to_floor(self)
        end
    end

    progs.item_shells=function(self)
        -- set size and link into world
        progs:setmodel(self, "maps/b_shell0.bsp")

        self.touch=function()
            progs:remove(self)
            
            -- todo:    
            printh("got shells")        
        end

        start_item(self)
    end

    progs.item_health=function(self)
        local flags = self.spawnflags or 0
        
        if band(flags,H_ROTTEN)~=0 then
            progs:setmodel(self, "maps/b_bh10.bsp")
            self.noise = "items/r_item1.wav"
            self.healamount = 15
            self.healtype = 0
        elseif band(flags,H_MEGA)~=0 then
            progs:setmodel(self, "maps/b_bh100.bsp")
            self.noise = "items/r_item2.wav"
            self.healamount = 100
            self.healtype = 2
        else
            progs:setmodel(self, "maps/b_bh25.bsp")
            self.noise = "items/health1.wav"
            self.healamount = 25
            self.healtype = 1
        end
        
        self.touch=function(other)
            progs:remove(self)

            if other.classname ~= "player" then
                return
            end

            -- todo: sound
            take_heal(other, self.healamount)
            
            -- linked actions?
            use_targets(self)
        end

        start_item(self)
    end

    local function init_key(self)
        self.touch = function(other)
            if other.classname ~= "player" then
                return
            end
            if other.health <= 0 then
                return
            end
            -- already in inventory
            if band(other.items,self.items)~=0 then
                return
            end
        
            progs:print("You got the "..self.netname)
        
            -- sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
            other.items = bor(other.items,self.items)
        
            self.SOLID_NOT = true
            self.DRAW_NOT = true
        
            use_targets(self, other) --fire all targets / killtargets
        end
        self.mins= {-16,-16,-24}
        self.maxs = {16,16,32}
    end

    progs.item_key1=function(self)
        self.frame = "frame1"
        self.skin = 1

        if progs.world.worldtype == 0 then
            progs:precache_model ("progs/w_s_key.mdl")
            progs:setmodel (self, "progs/w_s_key.mdl")
            self.netname = "silver key"
        elseif progs.world.worldtype == 1 then
            progs:precache_model ("progs/m_s_key.mdl")
            progs:setmodel (self, "progs/m_s_key.mdl")
            self.netname = "silver runekey"
        elseif progs.world.worldtype == 2 then
            progs:precache_model ("progs/b_s_key.mdl")
            progs:setmodel (self, "progs/b_s_key.mdl")
            self.netname = "silver keycard"
        end
        -- key_setsounds();
        self.items = IT_KEY1
        init_key(self)
        start_item(self)
        --StartItem ();
    end

    progs.item_key2=function(self)
        self.frame = "frame1"
        self.skin = 1
        if progs.world.worldtype == 0 then
            progs:precache_model ("progs/w_g_key.mdl")
            progs:setmodel (self, "progs/w_g_key.mdl")
            self.netname = "gold key"
        elseif progs.world.worldtype == 1 then
            progs:precache_model ("progs/m_g_key.mdl")
            progs:setmodel (self, "progs/m_g_key.mdl")
            self.netname = "gold runekey"
        elseif progs.world.worldtype == 2 then
            progs:precache_model ("progs/b_g_key.mdl")
            progs:setmodel (self, "progs/b_g_key.mdl")
            self.netname = "gold keycard"
        end
       
        -- key_setsounds();
        init_key(self)
        self.items = IT_KEY2
        start_item(self)
        -- StartItem ();
    end
end
return items