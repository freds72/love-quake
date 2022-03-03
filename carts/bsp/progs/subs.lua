local subs={}
local math3d=require("math3d")

function set_move_dir(self)
    local angle = self.angle
	if angle == -1 then
        print("up")
        self.movedir = {0,0,1}
	elseif angle == -2 then
        print("down")
        self.movedir = {0,0,-1}
	else
        print("move:"..angle)
		local m = make_m_from_euler(0,angle,0)
		self.movedir = m_fwd(m)
    end
	
	self.angles = {0,0,0}
end

function print_entity(self)
    for k,v in pairs(self) do
        print(k..":"..tostring(v))
    end
end

return subs