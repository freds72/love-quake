-- layout
local VBO_1 = 0
local VBO_2 = 1
local VBO_3 = 2
local VBO_X = 3
local VBO_Y = 4
local VBO_W = 5
local VBO_OUTCODE = 6
local VBO_U = 7
local VBO_V = 8

local vbo = require("engine.pool")("vertex_cache",9,7500)
local WireframeRasterizer={
    -- shared "memory" with renderer
    vbo = vbo,
    frame = 0,
    beginFrame=function(self)
        self.frame = self.frame + 1
    end,
    -- push a surface to rasterize
    addSurface=function(pts,n,_,c)
        local x0,y0=vbo[pts[n] + VBO_X],vbo[pts[n] + VBO_Y]
        for i=1,n do
            local p=pts[i]
            local x1,y1=vbo[p + VBO_X],vbo[p + VBO_Y]
            line(x0,y0,x1,y1,c or 8)
            x0,y0=x1,y1
        end
    end,
    addQuad=function(x0,y0,x1,y1,w,c)
        -- todo
    end,
    endFrame=function()
    end
}

return WireframeRasterizer