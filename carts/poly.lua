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


function polytex_ymajor(v,n,slope)
	local nodes_x,nodes_u,nodes_v,offset={},{},{},(slope<<7)&-1
	for i=1,n do
		local p0,p1=v[i%n+1],v[i]
		local x0,w0,x1,w1=p0.x,p0.w,p1.x,p1.w
		local u0,v0,u1,v1=p0.u*w0,p0.v*w0,p1.u*w1,p1.v*w1
		local y0,y1=p0.y-x0*slope,p1.y-x1*slope

		if(y0>y1) x0,y0,w0,x1,y1,w1,u0,v0,u1,v1=x1,y1,w1,x0,y0,w0,u1,v1,u0,v0
		local dy=y1-y0
		local cy0,dx,dw,du,dv=(y0&-1)+1,(x1-x0)/dy,(w1-w0)/dy,(u1-u0)/dy,(v1-v0)/dy
		-- sub-pix shift
		local sy=cy0-y0
		if(offset>0) then
			local ymin=y0+offset
			if(ymin<0) x0-=ymin*dx w0-=ymin*dw u0-=ymin*du v0-=ymin*dv cy0=-offset sy=0
			if(y1>127) y1=127
		else
			if(y0<0) x0-=y0*dx w0-=y0*dw u0-=y0*du v0-=y0*dv cy0=0 sy=0
			if(y1+offset>127) y1=127-offset
		end
		x0+=sy*dx  
		w0+=sy*dw
		u0+=sy*du
		v0+=sy*dv
				
		for y=cy0,y1 do
			local x1=nodes_x[y]
			if x1 then
				local x0,u0,v0,u1,v1=x0,u0/w0,v0/w0,nodes_u[y],nodes_v[y]
				if(x0>x1) x0,x1,u0,v0,u1,v1=x1,x0,u1,v1,u0,v0
				local ddx=((x1+0x1.ffff)&-1)-(x0&-1)
				clip(x0+1,0,ddx,127)		
				local ddu,ddv=(u1-u0)/ddx,(v1-v0)/ddx
				tline(0,y,127,y+offset,u0-x0*ddu,v0-x0*ddv,ddu,ddv)
			else
				nodes_x[y]=x0
				nodes_u[y]=u0/w0
				nodes_v[y]=v0/w0
			end
			x0+=dx
			w0+=dw
			u0+=du
			v0+=dv
		end
	end
	clip()
end

function polytex_xmajor(v,n,slope)
	local nodes_y,nodes_u,nodes_v,offset={},{},{},(slope<<7)&-1
	for i=1,n do
		local p0,p1=v[i%n+1],v[i]
		local y0,w0,y1,w1=p0.y,p0.w,p1.y,p1.w
		local u0,v0,u1,v1=p0.u*w0,p0.v*w0,p1.u*w1,p1.v*w1
		local x0,x1=p0.x-y0*slope,p1.x-y1*slope
		
		if(x0>x1) x0,y0,w0,x1,y1,w1,u0,v0,u1,v1=x1,y1,w1,x0,y0,w0,u1,v1,u0,v0
		local dx=x1-x0
		local cx0,dy,dw,du,dv=(x0&-1)+1,(y1-y0)/dx,(w1-w0)/dx,(u1-u0)/dx,(v1-v0)/dx
		--if(i==2) printh("start\t"..v0.."("..dw..")".."\t"..v1.."("..w1..")")
		-- sub-pix shift
		local sx=cx0-x0
		if offset>0 then
			local xmin=x0+offset
			if(xmin<0) y0-=xmin*dy w0-=xmin*dw u0-=xmin*du v0-=xmin*dv cx0=-offset sx=0
			if(x1>127) x1=127
		else
			if(x0<0) y0-=x0*dy w0-=x0*dw u0-=x0*du v0-=x0*dv cx0=0 sx=0
			if(x1+offset>127) x1=127-offset
		end
		y0+=sx*dy  
		w0+=sx*dw
		u0+=sx*du
		v0+=sx*dv

		for x=cx0,x1 do
			local y1=nodes_y[x]
			if y1 then
				local y0,u0,v0,u1,v1=y0,u0/w0,v0/w0,nodes_u[x],nodes_v[x]
				if(y0>y1) y0,y1,u0,v0,u1,v1=y1,y0,u1,v1,u0,v0
				local ddy=((y1+0x1.ffff)&-1)-(y0&-1)
				clip(0,y0+1,127,ddy)
				local ddu,ddv=(u1-u0)/ddy,(v1-v0)/ddy
				tline(x,0,x+offset,127,u0-y0*ddu,v0-y0*ddv,ddu,ddv)
			else
				nodes_y[x]=y0
				nodes_u[x]=u0/w0
				nodes_v[x]=v0/w0
			end
			y0+=dy
			w0+=dw
			u0+=du
			v0+=dv
		end
	end
	clip()
end

function polyline(p,np,c)
	color(c)
	for i=1,np do
		local v0,v1=p[i],p[i%np+1]	
		line(v0.x,v0.y,v1.x,v1.y)
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

		local a,b,au,av,aw=rx,lx,ru,rv,rw
		local dab=b-a
		local dau,dav,daw=(lu-ru)/dab,(lv-rv)/dab,(lw-rw)/dab
		if(a<0) au-=a*dau av-=a*dav aw-=a*daw a=0
		local sa=1-a%1
		au+=sa*dau
		av+=sa*dav
		aw+=sa*daw

		-- faster but produces edge artifacts
		-- local du,dv=(bu/bw-au/aw)/dab,(bv/bw-av/aw)/dab
	
		-- 8-pixel stride deltas
		dau<<=3
		dav<<=3
		daw<<=3
		
		-- clip right span edge
		if(b>127) b=127
		poke(0x5f22,b+1)
		for x=a,b,8 do
			local u,v=au/aw,av/aw
			aw+=daw			
			tline(x,y,x+7,y,u,v,((dau-u*daw)>>3)/aw,((dav-v*daw)>>3)/aw)
			au+=dau
			av+=dav
		end
		
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