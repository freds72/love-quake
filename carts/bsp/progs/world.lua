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

    progs.worldspawn=function(self)
        progs.world={
            name = self.message,
            worldtype=self.worldtype
        }
		-- force origin
		self.origin = {0,0,0}	
        self.SOLID_BSP = true
        progs:setmodel(self, 0)
    end
end
return world