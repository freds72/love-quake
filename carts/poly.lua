-- plain color polygon rasterization
function polyfill(p,np,c)
	color(c)
	local miny,maxy,mini=32000,-32000
	-- find extent
	for i=1,np do
		local v=p[i]
		local y=v.y
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end

	--data for left & right edges:
	local lj,rj,ly,ry,lx,ldx,rx,rdx=mini,mini,miny,miny
	--step through scanlines.
	if(maxy>127) maxy=127
	if(miny<0) miny=-1
	for y=1+miny&-1,maxy do
		--maybe update to next vert
		while ly<y do
			local v0=p[lj]
			lj+=1
			if (lj>np) lj=1
			local v1=p[lj]
			local y0,y1=v0.y,v1.y
			ly=y1&-1
			lx=v0.x
			ldx=(v1.x-lx)/(y1-y0)
			--sub-pixel correction
			lx+=(y-y0)*ldx
		end   
		while ry<y do
			local v0=p[rj]
			rj-=1
			if (rj<1) rj=np
			local v1=p[rj]
			local y0,y1=v0.y,v1.y
			ry=y1&-1
			rx=v0.x
			rdx=(v1.x-rx)/(y1-y0)
			--sub-pixel correction
			rx+=(y-y0)*rdx
		end
		local a,b=rx\1,lx\1-1
		if(b-a>=0) rectfill(a,y,b,y)
		--spanfill(y,rx,lx)
		lx+=ldx
		rx+=rdx
	end
end


local _spans={}
function spanfill(x0,x1,y,u,v,w,du,dv,dw)
	if(x1<0 or x0>127) return
	if(x1-x0<0) return
	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		tline3d(x0,y,x1,y,u,v,w,du,dv,dw)
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
				tline3d(x0,y,x1,y,u,v,w,du,dv,dw)
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
			tline3d(x0,y,x2,y,u,v,w,du,dv,dw)
			local n={x0=x0,x1=x2,w=w,dw=dw,next=span}
			if old then 
				old.next=n				
			else
				_spans[y]=n
			end
			x0=s0
			--assert(x1-x0>=0,"empty right seg")
			u+=dx*du
			v+=dx*dv
			w+=dx*dw
			-- check remaining segment
			old=n
			goto continue
		elseif s1>=x0 then
			--     ??nnnn????
			--     xxxxxxx	

			--     ??nnnn?
			--     xxxxxxx	
			-- totally hidden (or not!)
			local dx=x0-s0+1
			local sw=span.w+dx*span.dw			
			
			if sw<w or (sw==w and dw>span.dw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n={
						x0=s0,
						x1=x0-1,
						w=span.w,
						dw=span.dw,
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
				tline3d(x0,y,x2,y,u,v,w,du,dv,dw)					
				local n={x0=x0,x1=x2,w=w,dw=dw,next=span}
				if old then 
					old.next=n				
				else
					_spans[y]=n
				end
				
				-- any remaining "right" from current span?
				dx=s1-x1-1
				if dx>=0 then
					dx=x1+1-s0
					-- "shrink" current span
					span.x0=x1+1
					span.w+=dx*span.dw
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
			u+=dx*du
			v+=dx*dv
			w+=dx*dw

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
		tline3d(x0,y,x1,y,u,v,w,du,dv,dw)
		-- end of spans
		old.next={x0=x0,x1=x1,w=w,dw=dw}
	end
end

function tline3d(x0,y,x1,_,u,v,w,du,dv,dw)
	if dw==0 then
		-- "flat" line: direct rendering
		poke(0x5f22,128)
		tline(x0,y,x1,y,u/w,v/w,du/w,dv/w)		
	else
		-- 8-pixel stride deltas
		du<<=3
		dv<<=3
		dw<<=3
		
		-- clip right span edge
		--if(x1>136) x1=136
		poke(0x5f22,x1+1)
		for x=x0,x1,8 do
			-- perspective correct texel
			local tu,tv=u/w,v/w
			w+=dw			
			tline(x,y,x+7,y,tu,tv,((du-tu*dw)>>3)/w,((dv-tv*dw)>>3)/w)
			u+=du
			v+=dv
		end
	end
end

function polytex(p,np)
	local miny,maxy,mini=32000,-32000
	-- find extent
	for i=1,np do
		local v=p[i]
		local y=v.y
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end

	--data for left & right edges:
	local lj,rj,ly,ry,lx,lw,lu,lv,ldx,ldw,ldu,ldv,rx,rw,ru,rv,rdx,rdw,rdu,rdv=mini,mini,miny,miny
	--step through scanlines.
	if(maxy>127) maxy=127
	if(miny<0) miny=-1
	for y=1+miny&-1,maxy do
		--maybe update to next vert
		while ly<y do
			local v0=p[lj]
			lj+=1
			if (lj>np) lj=1
			local v1=p[lj]
			local y0,y1=v0.y,v1.y
			local dy=y1-y0
			ly=y1&-1
			lx=v0.x
			lw=v0.w
			lu=v0.u*lw
			lv=v0.v*lw
			ldx=(v1.x-lx)/dy
			ldw=(v1.w-lw)/dy
			ldu=(v1.u*v1.w-lu)/dy
			ldv=(v1.v*v1.w-lv)/dy
			--sub-pixel correction
			local cy=y-y0
			lx+=cy*ldx
			lw+=cy*ldw
			lu+=cy*ldu
			lv+=cy*ldv
		end   
		while ry<y do
			local v0=p[rj]
			rj-=1
			if (rj<1) rj=np
			local v1=p[rj]
			local y0,y1=v0.y,v1.y
			local dy=y1-y0
			ry=y1&-1
			rx=v0.x
			rw=v0.w
			ru=v0.u*rw
			rv=v0.v*rw
			rdx=(v1.x-rx)/dy
			rdw=(v1.w-rw)/dy
			rdu=(v1.u*v1.w-ru)/dy
			rdv=(v1.v*v1.w-rv)/dy
			--sub-pixel correction
			local cy=y-y0
			rx+=cy*rdx
			rw+=cy*rdw
			ru+=cy*rdu
			rv+=cy*rdv
		end

		local a,dx=rx&-1,lx-rx
		local du,dv,dw=(lu-ru)/dx,(lv-rv)/dx,(lw-rw)/dx
		-- todo: faster to clip polygon?
		local x,u,v,w=rx,ru,rv,rw
		if(x<0) u-=x*du v-=x*dv w-=x*dw x=0 a=0
		local sa=1-x%1
		spanfill(a,min((lx&-1)-1,127),y,u+sa*du,v+sa*dv,w+sa*dw,du,dv,dw)
		--rectfill(a,y,min(lx\1-1,127),y,w*16)

		lx+=ldx
		lw+=ldw
		lu+=ldu
		lv+=ldv
		rx+=rdx
		rw+=rdw
		ru+=rdu
		rv+=rdv
	end
	-- reset clip
	poke(0x5f22,128)	
end