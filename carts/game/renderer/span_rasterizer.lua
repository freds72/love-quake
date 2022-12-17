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
-- dedicated vbo for alpha/transparent surfaces
local _vbo_btf = require("engine.pool")("vertex_cache_btf",9,1200)
local _vboptr=vbo:ptr(0)
local _vboptr_btf=_vbo_btf:ptr(0)

local _pool=require("engine.pool")("spans",5,25000)
local _ptr=_pool:ptr(0)
local _spans={}
local _transparent_surfaces = {}

local _testTexture = {width=4,height=4,ptr={
	[0]=19,24,19,24,
	24,19,24,19,
	19,24,19,24,
	24,19,24,19
}}

local flr=flr

-- span buffer
local function spanfill(x0,x1,y,u,v,w,du,dv,dw,fn)	
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end
	local _pool,_ptr=_pool,_ptr

	-- fn = overdrawfill

	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		_spans[y]=_pool:pop5(x0,x1,w,dw,-1)
		return
	end

	-- loop while valid address
	while span>=0 do		
		local s0,s1=_ptr[span],_ptr[span+1]

		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(x0,y,x1,y,u,v,w,du,dv,dw)
				local n=_pool:pop5(x0,x1,w,dw,span)
				if old then
					-- chain to previous
					_ptr[old+4]=n
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
			fn(x0,y,x2,y,u,v,w,du,dv,dw)
			local n=_pool:pop5(x0,x2,w,dw,span)
			if old then 
				_ptr[old+4]=n				
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
			local dx,sdw=x0-s0,_ptr[span+3]
			local sw=_ptr[span+2]+dx*sdw		
			
			-- use scaled precision for abutting spans (see Christer Ericson)
			-- use absolute distance for other planes
			if sw-w<-0.00001 or (abs(sw-w)<=1e-5*max(abs(sw),max(abs(w),1)) and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n=_pool:pop5(
						s0,
						x0-1,
						_ptr[span+2],
						sdw,
						span)
					if old then
						_ptr[old+4]=n
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
				fn(x0,y,x2,y,u,v,w,du,dv,dw)					
				local n=_pool:pop5(x0,x2,w,dw,span)
				if old then 
					_ptr[old+4]=n	
				else
					-- new first
					_spans[y]=n
				end
				old=n

				-- any remaining "right" from current span?
				local dx=s1-x1-1
				if dx>0 then
					-- "shrink" current span
					_ptr[span]=x1+1
					_ptr[span+2]=_ptr[span+2]+(x1+1-s0)*sdw
				else
					-- drop current span
					_ptr[old+4]=_ptr[span+4]
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
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		-- end of spans		
		_ptr[old+4]=_pool:pop5(x0,x1,w,dw,-1)
	end
end

local function polytex(p,np,texture,tline)
	tline = tline or tline3d
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

	local mipscale,umin,vmin=texture.scale,texture.umin,texture.vmin
	local miny,maxy,mini=32000,-32000
	-- find extent
	for i=1,np do
		local pi=_vboptr + p[i]
		local y,w=pi[VBO_Y],pi[VBO_W]
		if y<miny then
			mini,miny=i,y
		end
		if y>maxy then
			maxy=y
		end
	end

	-- set active texture
	tput(texture)

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
			local p0,p1=_vboptr + v0,_vboptr + v1
			local y0,y1=p0[VBO_Y],p1[VBO_Y]
			local dy=y1-y0
			ly=flr(y1)
			lx=p0[VBO_X]
			lw=p0[VBO_W]
			lu=(p0[VBO_U]/mipscale - umin) * lw
			lv=(p0[VBO_V]/mipscale - vmin) * lw
			ldx=(p1[VBO_X]-lx)/dy
			local w1=p1[VBO_W]
			ldu=((p1[VBO_U]/mipscale - umin) * w1 - lu)/dy
			ldv=((p1[VBO_V]/mipscale - vmin) * w1 - lv)/dy
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
			local p0,p1=_vboptr + v0,_vboptr + v1
			local y0,y1=p0[VBO_Y],p1[VBO_Y]
			local dy=y1-y0
			ry=flr(y1)
			rx=p0[VBO_X]
			rw=p0[VBO_W]
			ru=(p0[VBO_U]/mipscale - umin)*rw 
			rv=(p0[VBO_V]/mipscale - vmin)*rw 
			rdx=(p1[VBO_X]-rx)/dy
			local w1=p1[VBO_W]
			rdu=((p1[VBO_U]/mipscale - umin) * w1 - ru)/dy
			rdv=((p1[VBO_V]/mipscale - vmin) * w1 - rv)/dy
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

		spanfill(flr(x0),flr(x1)-1,y,u+sa*du,v+sa*dv,w+sa*dw,du,dv,dw,tline)

		lx=lx+ldx
		lu=lu+ldu
		lv=lv+ldv
		lw=lw+ldw
		rx=rx+rdx
		ru=ru+rdu
		rv=rv+rdv
		rw=rw+rdw
    end
end

local SpanRasterizer={
    frame = 0,
    -- shared "memory" with renderer
    vbo = vbo,
    beginFrame=function(self)
        self.frame = self.frame + 1
    end,
    -- push a surface to rasterize
    addSurface=function(p,np,texture)
		if texture.transparent then
			-- copy poly data
			local poly={}
			for i=1,np do
				poly[i]=_vbo_btf:copy(_vboptr + p[i])
			end
			add(_transparent_surfaces,{
				poly=poly,
				np=np,
				texture=texture})
			return
		end
    
		polytex(p,np,texture)
    end,
	addQuad=function(x0,y0,x1,y1,w,c)
		if y1>=270 then
			y1=270-1
		  end
		if y0<0 then
			y0=-1
		  end
		if x0<0 then
			x0=0
		end
		if x1>480 then
			x1=480
		end
		x0=flr(x0)
		x1=flr(x1)-1
		-- visible?
		if x0>480 or x1<0 or y0>270 or y1<0 then
			return
		end
		for y=1+flr(y0),y1 do
			spanfill(x0,x1,y,c,0,w,0,0,0,line)
		end
	end,	
    endFrame=function()
		-- draw alpha surfaces
		local ptr=_vboptr
		_vboptr = _vboptr_btf
		for i=#_transparent_surfaces,1,-1 do
			local surf=_transparent_surfaces[i]
			polytex(surf.poly,surf.np,surf.texture,tline3d_trans)
		end
		_vboptr = ptr

		_pool:reset()
		_vbo_btf:reset()

        for y in pairs(_spans) do
            _spans[y]=nil
        end  

		for k in pairs(_transparent_surfaces) do
			_transparent_surfaces[k]=nil
		end
    end
}

return SpanRasterizer