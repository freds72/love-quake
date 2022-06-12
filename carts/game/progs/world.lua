local world=function(progs)
    
    -- Setup light animation tables. 'a' is total darkness, 'z' is maxbright.
	-- 0 normal
	progs:lightstyle(0, "m")
	
	-- 1 FLICKER (first variety)
	progs:lightstyle(1, "mmnmmommommnonmmonqnmmo")
	
	-- 2 SLOW STRONG PULSE
	progs:lightstyle(2, "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba")
	
	-- 3 CANDLE (first variety)
	progs:lightstyle(3, "mmmmmaaaaammmmmaaaaaabcdefgabcdefg")
	
	-- 4 FAST STROBE
	progs:lightstyle(4, "mamamamamama")
	
	-- 5 GENTLE PULSE 1
	progs:lightstyle(5,"jklmnopqrstuvwxyzyxwvutsrqponmlkj")
	
	-- 6 FLICKER (second variety)
	progs:lightstyle(6, "nmonqnmomnmomomno")
	
	-- 7 CANDLE (second variety)
	progs:lightstyle(7, "mmmaaaabcdefgmmmmaaaammmaamm")
	
	-- 8 CANDLE (third variety)
	progs:lightstyle(8, "mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa")
	
	-- 9 SLOW STROBE (fourth variety)
	progs:lightstyle(9, "aaaaaaaazzzzzzzz")
	
	-- 10 FLUORESCENT FLICKER
	progs:lightstyle(10, "mmamammmmammamamaaamammma")

	-- 11 SLOW PULSE NOT FADE TO BLACK
	progs:lightstyle(11, "abcdefghijklmnopqrrqponmlkjihgfedcba")
	
	-- styles 32-62 are assigned by the light program for switchable lights

	-- 63 testing
	progs:lightstyle(63, "a")

	-- particle ramps
	progs:rampstyle(1,{0x6f, 0x6d, 0x6b, 0x69, 0x67, 0x65, 0x63, 0x61})
	progs:rampstyle(2,{0x6f, 0x6e, 0x6d, 0x6c, 0x6b, 0x6a, 0x68, 0x66})
	progs:rampstyle(3,{0x6d, 0x6b, 6, 5, 4, 3})
    
    progs.info_intermission=function(self)
        self.SOLID_NOT = true
        self.MOVETYPE_NONE = true
        self.DRAW_NOT = true
        -- set size and link into world
		if self.mangle then
			local x,y,z=unpack(split(self.mangle," "))
			self.mangles = {x/180,y/180,z/180}
		end
        progs:setmodel(self, self.model)
    end

    progs.worldspawn=function(self)
        progs.world={
            name = self.message,
            worldtype=self.worldtype
        }
		-- force origin
		self.origin = {0,0,0}	
        self.SOLID_BSP = true
        progs:setmodel(self, "*0")
    end
end
return world