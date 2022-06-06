local frame=0
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
local _pool=require("engine.pool")("spans",5,12500)
local _spans={}

local _testTexture = {width=4,height=4,ptr={
	[0]=19,24,19,24,
	24,19,24,19,
	19,24,19,24,
	24,19,24,19
}}


-- span buffer
local function spanfill(tex,x0,x1,y,u,v,w,du,dv,dw,fn)	
	local _pool=_pool
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end

	-- fn = overdrawfill

	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		fn(tex,x0,y,x1,y,u,v,w,du,dv,dw)
		_spans[y]=_pool:pop5(x0,x1,w,dw,-1)
		return
	end

	-- loop while valid address
	while span>=0 do		
		local s0,s1=_pool[span],_pool[span+1]

		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(tex,x0,y,x1,y,u,v,w,du,dv,dw)
				local n=_pool:pop5(x0,x1,w,dw,span)
				if old then
					-- chain to previous
					_pool[old+4]=n
				else
					-- new first
					_spans[y]=n
				end
				return
			end

			-- nnnn?????????
			--     xxxxxxx
			-- clip + display left
			local x2=s0-1
			local dx=x2-x0
			fn(tex,x0,y,x2,y,u,v,w,du,dv,dw)
			local n=_pool:pop5(x0,x2,w,dw,span)
			if old then 
				_pool[old+4]=n				
			else
				_spans[y]=n
			end
			old=n

			x0=s0
			--assert(x1-x0>=0,"empty right seg")
			u=u+dx*du
			v=v+dx*dv
			w=w+dx*dw
			-- check remaining segment
			goto continue
		elseif s1>=x0 then
			--     ??nnnn????
			--     xxxxxxx	

			--     ??nnnn?
			--     xxxxxxx	
			-- totally hidden (or not!)
			local dx,sdw=x0-s0,_pool[span+3]
			local sw=_pool[span+2]+dx*sdw		
			
			if sw-w<-1e-6 or (sw-w<0.00001 and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n=_pool:pop5(
						s0,
						x0-1,
						_pool[span+2],
						sdw,
						span)
					if old then
						_pool[old+4]=n
					else
						-- new first
						_spans[y]=n
					end
					old=n
				end
				-- middle ("new")
				--     ??nnnnn???
				--     xxxxxxx			
				-- draw only up to s1
				local x2=s1<x1 and s1 or x1
				fn(tex,x0,y,x2,y,u,v,w,du,dv,dw)					
				local n=_pool:pop5(x0,x2,w,dw,span)
				if old then 
					_pool[old+4]=n	
				else
					-- new first
					_spans[y]=n
				end
				old=n

				-- any remaining "right" from current span?
				local dx=s1-x1-1
				if dx>0 then
					-- "shrink" current span
					_pool[span]=x1+1
					_pool[span+2]=_pool[span+2]+(x1+1-s0)*sdw
				else
					-- drop current span
					_pool[old+4]=_pool[span+4]
					span=old
				end					
			end

			if s1>=x1 then
				--     ///////
				--     xxxxxxx	
				return
			end
			--         ///nnn
			--     xxxxxxx
			-- clip incomping segment
			--assert(dx>=0,"empty right (incoming) seg")
			-- 
			local dx=s1+1-x0
			x0=s1+1
			u=u+dx*du
			v=v+dx*dv
			w=w+dx*dw

			--            nnnn
			--     xxxxxxx	
			-- continue + test against other spans
		end
		old=span	
		span=_pool[span+4]
::continue::
	end
	-- new last?
	if x1-x0>=0 then
		fn(tex,x0,y,x1,y,u,v,w,du,dv,dw)
		-- end of spans		
		_pool[old+4]=_pool:pop5(x0,x1,w,dw,-1)
	end
end

local WireframeRasterizer={
    frame = 0,
    -- shared "memory" with renderer
    vbo = vbo,
    beginFrame=function(self)
        self.frame = self.frame + 1
    end,
    -- push a surface to rasterize
    addSurface=function(p,np,texture)
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
    
        local tline=tline3d   
        local mipscale,umin,vmin=texture.scale,texture.umin,texture.vmin
        local miny,maxy,mini=math.huge,-math.huge
        -- find extent
        for i=1,np do
            local y,w=vbo[p[i] + VBO_Y],vbo[p[i] + VBO_W]
            if y<miny then
                mini,miny=i,y
            end
            if y>maxy then
                maxy=y
            end
        end

        --data for left & right edges:
        local lj,rj,ly,ry,lx,lu,lv,lw,ldx,ldu,ldv,ldw,rx,ru,rv,rw,rdx,rdu,rdv,rdw=mini,mini,miny,miny
        if maxy>=270 then
            maxy=270-1
        end
        if miny<0 then
            miny=-1
        end
        for y=flr(miny)+1,maxy do
            --maybe update to next vert
            while ly<y do
                local v0=p[lj]
                lj=lj+1
                if lj>np then lj=1 end
                local v1=p[lj]
                local y0,y1=vbo[v0+VBO_Y],vbo[v1+VBO_Y]
                local dy=y1-y0
                ly=flr(y1)
                lx=vbo[v0 + VBO_X]
                lw=vbo[v0 + VBO_W]
                lu=(vbo[v0 + VBO_U]/mipscale - umin) * lw
                lv=(vbo[v0 + VBO_V]/mipscale - vmin) * lw
                ldx=(vbo[v1 + VBO_X]-lx)/dy
                local w1=vbo[v1 + VBO_W]
                ldu=((vbo[v1 + VBO_U]/mipscale - umin) * w1 - lu)/dy
                ldv=((vbo[v1 + VBO_V]/mipscale - vmin) * w1 - lv)/dy
                ldw=(w1-lw)/dy
                --sub-pixel correction
                local cy=y-y0
                lx=lx+cy*ldx
                lu=lu+cy*ldu
                lv=lv+cy*ldv
                lw=lw+cy*ldw
            end   
            while ry<y do
                local v0=p[rj]
                rj=rj-1
                if rj<1 then rj=np end
                local v1=p[rj]
                local y0,y1=vbo[v0 + VBO_Y],vbo[v1 + VBO_Y]
                local dy=y1-y0
                ry=flr(y1)
                rx=vbo[v0 + VBO_X]
                rw=vbo[v0 + VBO_W]
                ru=(vbo[v0 + VBO_U]/mipscale - umin)*rw 
                rv=(vbo[v0 + VBO_V]/mipscale - vmin)*rw 
                rdx=(vbo[v1 + VBO_X]-rx)/dy
                local w1=vbo[v1 + VBO_W]
                rdu=((vbo[v1 + VBO_U]/mipscale - umin) * w1 - ru)/dy
                rdv=((vbo[v1 + VBO_V]/mipscale - vmin) * w1 - rv)/dy
                rdw=(w1-rw)/dy
                --sub-pixel correction
                local cy=y-y0
                rx=rx+cy*rdx
                ru=ru+cy*rdu
                rv=rv+cy*rdv
                rw=rw+cy*rdw
            end
        
            local dx=lx-rx
            local du,dv,dw=(lu-ru)/dx,(lv-rv)/dx,(lw-rw)/dx
            -- todo: faster to clip polygon?
            local x0,x1,u,v,w=rx,lx,ru,rv,rw
            if x0<0 then
                u=u-x0*du v=v-x0*dv w=w-x0*dw x0=0
            end
            --sub-pixel correction
            local sa=1-x0%1
            if x1>480 then
                x1=480
            end
    
            spanfill(texture,flr(x0),flr(x1)-1,y,u+sa*du,v+sa*dv,w+sa*dw,du,dv,dw,tline)

            lx=lx+ldx
            lu=lu+ldu
            lv=lv+ldv
            lw=lw+ldw
            rx=rx+rdx
            ru=ru+rdu
            rv=rv+rdv
            rw=rw+rdw
        end
    end,
    endFrame=function()
        _pool:reset()
        for y in pairs(_spans) do
            _spans[y]=nil
        end  
    end
}

return WireframeRasterizer