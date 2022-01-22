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
		--rectfill(rx,y,lx,y)
		spanfill(y,rx,lx)
		lx+=ldx
		rx+=rdx
	end
end


local spans={}
function spanfill(y,x0,x1)
	-- sort
	-- rectfill(x0,y,x1,y,7)
	x0&=-1
	x1=(x1&-1)-1
	--rectfill(x0,y,x1,y,8)
	local span,old=spans[y]
	-- empty scanline?
	if not span then
		if(x1-x0<0) return
		rectfill(x0,y,x1,y)
		spans[y]={x0=x0,x1=x1}
		return
	end
	while span do
		local s0,s1=span.x0,span.x1
		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				rectfill(x0,y,x1,y)
				local n={x0=x0,x1=x1,next=span}
				if old then
					-- chain to previous
					old.next=n
				else
					-- new first
					spans[y]=n
				end
				return
			end

			-- nnnn?????????
			--     xxxxxxx
			-- clip + display left
			local x2=s0-1
			if x2-x0>=0 then
				rectfill(x0,y,x2,y)
				local n={x0=x0,x1=x2,next=span}
				if old then 
					old.next=n
				else
					spans[y]=n
				end
			end
			if s1>=x1 then
				-- ////nn?????
				--     xxxxxxx	
				-- visible part already drawn
				return
			end
			-- ////?????nnnn
			--     xxxxxxx	
			-- clip + test against other spans
			x0=s1+1
			if(x1-x0<0) return				
		else
			if s1>=x1 then
				--     ??nnnn?
				--     xxxxxxx	
				-- totally hidden
				return
			end

			--            nnnn
			--     xxxxxxx	
			-- continue + test against other spans
			if s1>=x0 then
				--     ?????nnnnn
				--     xxxxxxx	
				-- clip + test against other spans
				x0=s1+1
				if(x1-x0<0) return
			end
		end
		old=span	
		span=span.next
	end
	-- new last?
	if x1-x0>=0 then
		rectfill(x0,y,x1,y)
		-- end of spans
		old.next={x0=x0,x1=x1}
	end
end

function tline3d(x0,y,x1,_,u0,u1,v0,v1,w0,w1)
	local a,b,dx=x0&-1,(x1&-1)-1,x1-x0
	local du,dv,dw=(u1-u0)/dx,(v1-v0)/dx,(w1-w0)/dx
	-- todo: faster to clip polygon?
	if(x0<0) u0-=x0*du v0-=x0*dv w0-=x0*dw x0=0 a=0 dx=b
	local sa=0--a-x0
	u0+=sa*du
	v0+=sa*dv
	w0+=sa*dw	

	local stride=(w1-w0)<<3
	if (stride^^(stride>>31))<1 then
		-- "flat" line: direct rendering
		poke(0x5f22,128)
		local u,v=u0/w0,v0/w0
		tline(a,y,b,y,u,v,(u1/w1-u)/dx,(v1/w1-v)/dx)
	else
		-- 8-pixel stride deltas
		du<<=3
		dv<<=3
		dw<<=3
		
		-- clip right span edge
		if(b>136) b=136
		poke(0x5f22,b+1)
		for x=a,b,8 do
			local u,v=u0/w0,v0/w0
			w0+=dw			
			tline(x,y,x+7,y,u,v,((du-u*dw)>>3)/w0,((dv-v*dw)>>3)/w0)
			u0+=du
			v0+=dv
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

		tline3d(rx,y,lx,y,ru,lu,rv,lv,rw,lw)

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