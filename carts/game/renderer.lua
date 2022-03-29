local renderer={}
local appleCake = require("lib.AppleCake")()  
local ffi=require 'ffi'
local logging = require("logging")

-- p8
local abs,flr,ceil=math.abs,math.floor,math.ceil
local add=table.insert
local cos,sin=math.cos,math.sin
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local function mid(x, a, b)
	return max(a, min(b, x))
  end

local _backbuffer
function start_frame(buf)
	_backbuffer = buf
end
-- "vbo" cache
local _pool=require("pool")("spans",5,2500)
local _spans={}
function end_frame()	
	-- used state
	--print(_pool:stats())
	-- reclaim all spans
	_pool:reset()
	--print(_pool:stats())
	-- reset 
	for k in pairs(_spans) do
		_spans[k]=nil
	end
end

local function spanfill(x0,x1,y,u,v,w,du,dv,dw,fn)	
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end

	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		_spans[y]=_pool:pop(x0,x1,w,dw,-1)
		return
	end

	while span>0 do		
		local s0,s1=_pool[span],_pool[span+1]

		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(x0,y,x1,y,u,v,w,du,dv,dw)
				local n=_pool:pop(x0,x1,w,dw,span)
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
			fn(x0,y,x2,y,u,v,w,du,dv,dw)
			local n=_pool:pop(x0,x2,w,dw,span)
			if old then 
				_pool[old+4]=n				
			else
				_spans[y]=n
			end
			x0=s0
			--assert(x1-x0>=0,"empty right seg")
			u=u+dx*du
			v=v+dx*dv
			w=w+dx*dw
			-- check remaining segment
			old=n
			goto continue
		elseif s1>=x0 then
			--     ??nnnn????
			--     xxxxxxx	

			--     ??nnnn?
			--     xxxxxxx	
			-- totally hidden (or not!)
			local dx,sdw=x0-s0+1,_pool[span+3]
			local sw=_pool[span+2]+dx*sdw		
			
			if sw-w<-0.00001 or (abs(sw-w)<0.00001 and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n=_pool:pop(
						s0,
						x0-1,
						_pool[span+2],
						sdw,
						span)
					if old then
						_pool[old+4]=n
					else
						_spans[y]=n
					end
					old=n
				end
				-- middle ("new")
				local x2=x1
				if s1<x1 then
					--     ??nnnnn???
					--     xxxxxxx			
					-- draw only up to s1
					x2=s1
				end
				fn(x0,y,x2,y,u,v,w,du,dv,dw)					
				local n=_pool:pop(x0,x2,w,dw,span)
				if old then 
					_pool[old+4]=n	
				else
					_spans[y]=n
				end
				
				-- any remaining "right" from current span?
				if s1-x1-1>=0 then
					-- "shrink" current span
					_pool[span]=x1+1
					_pool[span+2]=_pool[span+2]+(x1+1-s0)*sdw
				else
					-- drop current span
					_pool[n+4]=_pool[span+4]
					span=n
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
		_pool[old+4]=_pool:pop(x0,x1,w,dw,-1)
	end
end

local _texptr,_texw,_texh,_texscale
local _texture_cache={}
local _params={}
function push_param(name,value)
	_params[name] = value
end
function push_texture(texture,mip)	
	if texture.sky then
		-- always render sky texture in full
		mip = 0
	end
	_texscale=shl(1,mip)
	-- rebase to 1
	_texw,_texh=texture.width/_texscale,texture.height/_texscale
	-- dynamic texture?
	if texture.swirl then
		local cache = _texture_cache[texture]
		if not cache then
			-- create entry
			local mips={}
			for i=0,3 do
				local w,h=shr(texture.width,i),shr(texture.height,i)
				add(mips,ffi.new("unsigned char[?]",w*h))
			end
			cache={
				mips=mips,
				-- frame time per mip
				frame={}
			}
			_texture_cache[texture] = cache
		end
		mip = mip + 1
		_texptr=cache.mips[mip]
		local t=_params.t
		-- refresh image?
		if cache.frame[mip]~=t then
			-- copy texture
			cache.frame[mip]=t

			-- see: https://fdossena.com/?p=quakeFluids/i.md
			local src=texture.mips[mip]
			t=t*0.8
			for u=0,_texw-1 do
				local tu=u/_texw
				for v=0,_texh-1 do
					local tv=v/_texh
					-- 2* to make sure it rolls over the whole texture space
					local s,t=flr((tu + 0.1*sin(t+(2*3.1415*tv)))*_texw)%_texw,flr((tv + 0.1*sin(t+(2*3.1415*tu)))*_texh)%_texh
					_texptr[u + v*_texw] = src[s + t*_texw]
				end
			end
		end
	else
		_texptr=texture.mips[mip+1]
	end
end

local _lightptr,_lightw,_lighth,_lightx,_lighty,_lbase
function push_lightmap(...)
	_lightptr,_lightw,_lighth,_lightx,_lighty=unpack{...}
end
function push_baselight(style)
	-- 255: pure black
	_lbase=style
end
function push_viewmatrix(m)
	_viewmatrix=m
end

local _gamma = 0
function tline3d(x0,y0,x1,_,u,v,w,du,dv,dw)	
	local shade=63-flr(mid(_lbase[1] * 63,0,63))
	for x=x0,x1 do
		local uw,vw=u/w,v/w
		if _lightptr then
			shade=0
			local s,t=(uw - _lightx)/16,(vw - _lighty)/16
			local s0,s1,t0,t1=flr(s),ceil(s),flr(t),ceil(t)
			local s0t0,s0t1,s1t0,s1t1=s0+t0*_lightw,s0+t1*_lightw,s1+t0*_lightw,s1+t1*_lightw
			s=s%1
			t=t%1
			for i=0,3 do
				local scale = _lbase[i+1]
				if scale>0 then
					local ofs=i*_lighth*_lightw							
					-- todo: cache lightmaps when needed
					--print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
					local a=_lightptr[ofs + s0t0] * (1-s) + _lightptr[ofs + s1t0] * s
					local b=_lightptr[ofs + s0t1] * (1-s) + _lightptr[ofs + s1t1] * s
					local light = a*(1-t) + b*t
				
					-- light is additive
					-- rebase 0-255 to 0-63
					shade = shade + (scale*light)/4
					--_backbuffer[x+y0*480]=_palette[_colormap[15 +  shade*256] ]

					--[[
					local s,t=flr((uw - _lightx)/16),flr((vw - _lighty)/16)
					--print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
					local light = _lightptr[s+t*_lightw]
					shade = flr((0xff - light)/4)			
					]]
				end
			end
			shade = 63 - flr(mid(shade,0,63))
		end
		-- todo: fix gamma
		shade = mid(shade-_gamma,0,63)

		local s,t=flr(uw/_texscale)%_texw,flr(vw/_texscale)%_texh
		local coloridx=_texptr[s+t*_texw]
		--if (x+y0)%2==0 then
		_backbuffer[x+y0*480]=_palette[_colormap[coloridx + shade*256]]
		--else
		-- _backbuffer[x+y0*480]=_palette[_colormap[_texscale*8+15]]
		--end
		
		u=u+du
		v=v+dv
		w=w+dw
	end
end

function mode7(x0,y0,x1)	
	-- sky normal in camera space
	local n,d=_params.sky,_params.sky_distance
	local htw,offsetx,offsety=_texw/2,_params.t*32,_params.t*24
	local texscale = _texscale * 16
	for x=x0,x1 do
		-- intersection with sky plane
		local e={-(x-480/2)/270,-1,(y0-270/2)/270}
		local ne=v_dot(n,e)
		if ne~=0 then
			-- simili fisheye
			-- ne=ne*ne
			-- project point back into world space
			local p=m_inv_x_v(_viewmatrix,v_scale(e,d/ne))
			-- front 
			local s,t=flr((p[1]+offsetx)/texscale)%htw,flr((p[2]+offsety)/texscale)%_texh
			local coloridx=_colormap[_texptr[s+t*_texw]]
			if coloridx==0 then
				-- background
				local s,t=flr((p[1]+offsetx/2)/texscale)%htw + htw,flr((p[2]+offsety/2)/texscale)%_texh
				coloridx=_colormap[_texptr[s+t*_texw]]
			end
			_backbuffer[x+y0*480]=_palette[coloridx]
		end
	end
end

function polyfill(p,np,c)
	-- convert to real color
	c=_palette[c]

	local miny,maxy,mini=math.huge,-math.huge
	-- find extent
	for i=1,np do
		local v=p[i]
		local y=v.y
		if y<miny then
      mini,miny=i,y
    end
		if y>maxy then
      maxy=y
    end
	end

	--data for left & right edges:
	local lj,rj,ly,ry,lx,lw,ldx,ldw,rx,rw,rdx,rdw=mini,mini,miny,miny
	--step through scanlines.
	if maxy>=270 then
    maxy=270-1
  end
	if miny<0 then
    miny=-1
  end
	for y=1+flr(miny),maxy do
		--maybe update to next vert
		while ly<y do
			local v0=p[lj]
			lj=lj+1
			if lj>np then lj=1 end
			local v1=p[lj]
			local y0,y1=v0.y,v1.y
			local dy=y1-y0
			ly=flr(y1)
			lx=v0.x
			lw=v0.w
			ldx=(v1.x-lx)/dy
			ldw=(v1.w-lw)/dy
			--sub-pixel correction
			local cy=y-y0
			lx=lx+cy*ldx
			lw=lw+cy*ldw
		end   
		while ry<y do
			local v0=p[rj]
			rj=rj-1
			if rj<1 then rj=np end
			local v1=p[rj]
			local y0,y1=v0.y,v1.y
			local dy=y1-y0
			ry=flr(y1)
			rx=v0.x
			rw=v0.w
			rdx=(v1.x-rx)/dy
			rdw=(v1.w-rw)/dy
			--sub-pixel correction
			local cy=y-y0
			rx=rx+cy*rdx
			rw=rw+cy*rdw
		end
  
		--rectfill(a,y,min(lx\1-1,127),y,w*16)
    	for x=max(flr(rx),0),min(flr(lx),480)-1 do
    	  _backbuffer[x+y*480]=c
    	end

		lx=lx+ldx
		lw=lw+ldw
		rx=rx+rdx
		rw=rw+rdw
	end
end

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
local _vbo
function push_vbo(vbo)
	logging.debug("Assign VBO: "..vbo:stats())
	_vbo = vbo
end

local _profilepolytex
function polytex(p,np,sky)
	_profilepolytex = appleCake.profileFunc(nil, _profilepolytex)

	local tline=sky and mode7 or tline3d
	local vbo = _vbo
	local miny,maxy,mini=math.huge,-math.huge
	-- find extent
	for i=1,np do
		local y=vbo[p[i] + VBO_Y]
		if y<miny then
      		mini,miny=i,y
    	end
		if y>maxy then
      		maxy=y
    	end
	end

	--data for left & right edges:
	local lj,rj,ly,ry,lx,lu,lv,lw,ldx,ldu,ldv,ldw,rx,ru,rv,rw,rdx,rdu,rdv,rdw=mini,mini,miny,miny
	--step through scanlines.
	if maxy>=270 then
    	maxy=270-1
  	end
	if miny<0 then
	    miny=-1
  	end
	for y=1+flr(miny),maxy do
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
			lu=vbo[v0 + VBO_U]*lw
			lv=vbo[v0 + VBO_V]*lw
			ldx=(vbo[v1 + VBO_X]-lx)/dy
			ldu=(vbo[v1 + VBO_U] * vbo[v1 + VBO_W]-lu)/dy
			ldv=(vbo[v1 + VBO_V] * vbo[v1 + VBO_W]-lv)/dy
			ldw=(vbo[v1 + VBO_W]-lw)/dy
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
			ru=vbo[v0 + VBO_U]*rw
			rv=vbo[v0 + VBO_V]*rw
			rdx=(vbo[v1 + VBO_X]-rx)/dy
			rdu=(vbo[v1 + VBO_U]*vbo[v1 + VBO_W]-ru)/dy
			rdv=(vbo[v1 + VBO_V]*vbo[v1 + VBO_W]-rv)/dy
			rdw=(vbo[v1 + VBO_W]-rw)/dy
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
	_profilepolytex:stop()
end

return renderer