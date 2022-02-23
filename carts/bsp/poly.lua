local poly={}

-- p8
local abs,flr,ceil=math.abs,math.floor,math.ceil
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot

local _spans={}
function clear_spans()
	_spans={}
end
local function spanfill(x0,x1,y,u,v,w,du,dv,dw,fn)	
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end
	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		_spans[y]={x0=x0,x1=x1,w=w,dw=dw}
		return
	end
	while span do
		local s0,s1=span.x0,span.x1
		
		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(x0,y,x1,y,u,v,w,du,dv,dw)
				local n={x0=x0,x1=x1,w=w,dw=dw,next=span}
				if old then
					-- chain to previous
					old.next=n
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
			local n={x0=x0,x1=x2,w=w,dw=dw,next=span}
			if old then 
				old.next=n				
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
			local dx,sdw=x0-s0+1,span.dw
			local sw=span.w+dx*sdw		
			
			if sw<w or (sw==w and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n={
						x0=s0,
						x1=x0-1,
						w=span.w,
						dw=sdw,
						next=span}	
					if old then
						old.next=n
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
				local n={x0=x0,x1=x2,w=w,dw=dw,next=span}
				if old then 
					old.next=n				
				else
					_spans[y]=n
				end
				
				-- any remaining "right" from current span?
				if s1-x1-1>=0 then
					-- "shrink" current span
					span.x0=x1+1
					span.w=span.w+(x1+1-s0)*sdw
				else
					-- drop current span
					n.next=span.next
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
		span=span.next
::continue::
	end
	-- new last?
	if x1-x0>=0 then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		-- end of spans
		old.next={x0=x0,x1=x1,w=w,dw=dw}
	end
end

local _texptr,_texw,_texh,_texscale
function push_texture(ptr,width,height,mip)
	_texscale=shl(1,mip)
	_texptr,_texw,_texh=ptr[mip+1],width/_texscale,height/_texscale
end
local _lightptr,_lightw,_lighth,_lightx,_lighty,_lbase
function push_lightmap(...)
	_lightptr,_lightw,_lighth,_lightx,_lighty=unpack{...}
end
function push_baselight(style)
	-- 255: pure black
	_lbase=flr(style/4)
end

function tline3d(x0,y0,x1,_,u,v,w,du,dv,dw)			
	local shade=_lbase
	for x=x0,x1 do
		local uw,vw=u/w,v/w
		if _lightptr then
			-- todo: cache lightmaps when needed
			local s,t=(uw - _lightx)/16,(vw - _lighty)/16
			local s0,s1,t0,t1=flr(s),ceil(s),flr(t),ceil(t)
			local l0=lerp(_lightptr[s0+t0*_lightw],_lightptr[s1+t0*_lightw],s%1)
			local l1=lerp(_lightptr[s0+t1*_lightw],_lightptr[s1+t1*_lightw],s%1)			
			--print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
			local light = lerp(l0,l1,t%1)
		
			shade = flr((0xff-light)/4)
			--_backbuffer[x+y0*480]=_palette[_colormap[15 +  shade*256] ]

			--[[
			local s,t=flr((uw - _lightx)/16),flr((vw - _lighty)/16)
			--print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
			local light = _lightptr[s+t*_lightw]
			shade = flr((0xff - light)/4)			
			]]
		end

		local s,t=flr(uw/_texscale)%_texw,flr(vw/_texscale)%_texh
		local coloridx=_texptr[s+t*_texw]
		_backbuffer[x+y0*480]=_palette[_colormap[coloridx + shade*256]]

		u=u+du
		v=v+dv
		w=w+dw
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

function polytex(p,np)
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
	local lj,rj,ly,ry,lx,lu,lv,lw,ldx,ldw,rx,ru,rv,rw,rdx,rdw=mini,mini,miny,miny
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
			lu=v0.u*lw
			lv=v0.v*lw
			ldx=(v1.x-lx)/dy
			ldu=(v1.u*v1.w-lu)/dy
			ldv=(v1.v*v1.w-lv)/dy
			ldw=(v1.w-lw)/dy
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
			local y0,y1=v0.y,v1.y
			local dy=y1-y0
			ry=flr(y1)
			rx=v0.x
			rw=v0.w
			ru=v0.u*rw
			rv=v0.v*rw
			rdx=(v1.x-rx)/dy
			rdu=(v1.u*v1.w-ru)/dy
			rdv=(v1.v*v1.w-rv)/dy
			rdw=(v1.w-rw)/dy
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

		spanfill(flr(x0),flr(x1)-1,y,u+sa*du,v+sa*dv,w+sa*dw,du,dv,dw,tline3d)

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
return poly