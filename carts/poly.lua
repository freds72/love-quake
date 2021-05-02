-- plain color polygon rasterization
-- credits: 
function polyfill(p,c)
	color(c)
	local miny,maxy,minx,maxx,mini,minix=32000,-32000,32000,-32000
	-- find extent
	for i,v in pairs(p) do
		local x,y=v.x,v.y
		if (x<minx) minix,minx=i,x
		if (x>maxx) maxx=x
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end

	-- find smallest iteration area
	if abs(minx-maxx)<abs(miny-maxy) then
		--data for left and right edges:
		local np,lj,rj,lx,rx,ly,ldy,ry,rdy=#p,minix,minix,minx,minx
		--step through scanlines.
		if(maxx>127) maxx=127
		if(minx<0) minx=-1
		for x=1+minx&-1,maxx do
			--maybe update to next vert
			while lx<x do
				local v0=p[lj]
				lj+=1
				if (lj>np) lj=1
				local v1=p[lj]
				local x0,x1=v0.x,v1.x
				lx=x1&-1
				ly=v0.y
				ldy=(v1.y-ly)/(x1-x0)
				--sub-pixel correction
				ly+=(x-x0)*ldy
			end   
			while rx<x do
				local v0=p[rj]
				rj-=1
				if (rj<1) rj=np
				local v1=p[rj]
				local x0,x1=v0.x,v1.x
				rx=x1&-1
				ry=v0.y
				rdy=(v1.y-ry)/(x1-x0)
				--sub-pixel correction
				ry+=(x-x0)*rdy
			end
			--do
			--	local ly,ry=ly&-1,ry&-1
			--	if(ry-ly>=1) rectfill(x,ly,x,ry)
			--end
			rectfill(x,ly,x,ry)
			ly+=ldy
			ry+=rdy
		end
		--if(prev_ly and prev_ry) rectfill(maxx,prev_ly,maxx,prev_ry,1)	
	else
		--data for left & right edges:
		local np,lj,rj,ly,ry,lx,ldx,rx,rdx=#p,mini,mini,miny,miny
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
			--do
			--	local lx,rx=lx&-1,rx&-1
			--	if(lx-rx>=1) rectfill(rx,y,lx-1,y)
			--end
			rectfill(rx,y,lx,y)
			lx+=ldx
			rx+=rdx
		end

		-- edges
		if false then
			color(0)
			local nv=#p
			for i,p1 in pairs(p) do			
				if p1.edge then
					local p0=p[i%nv+1]
					local x0,y0,x1,y1=p0.x-0.5,p0.y,p1.x-0.5,p1.y
					-- y major
					if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
					local cy0,cy1,dx=y0\1+1,y1\1,(x1-x0)/(y1-y0)
					if y1-cy0>1 then
						--rectfill(x0-0.5,y0,x0+(cy0-y0)*dx,y0,8) 
						x0+=(cy0-y0)*dx 
						x1+=(cy1-y1)*dx
					end
	
					line(x0,cy0,x1,cy1)
				end
			end
		end
	end
end

function polyfill2(p,c)	
	color(c)
	local nv,spans=#p,{}
	for i,p1 in pairs(p) do
		local p0=p[i%nv+1]
		local x0,y0,x1,y1=p0.x,p0.y,p1.x,p1.y
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local dx=(x1-x0)/(y1-y0)
		local cy0=y0\1+1
		if(y0<0) x0-=y0*dx y0=0 cy0=0
		-- sub-pix shift
		x0+=(cy0-y0)*dx
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				local x0=x0\1
				span\=1
				if(x0>span) x0,span=span,x0
				if(span-x0>=1) rectfill(x0,y,span-1,y)				
				--rectfill(x0,y,span,y)			
			else
				spans[y]=x0
			end
			x0+=dx
		end
	end

	-- edges
	if false then
		color(0)
		for i,p1 in pairs(p) do			
			if p1.edge then
				local p0=p[i%nv+1]
				local x0,y0,x1,y1=p0.x-0.5,p0.y,p1.x-0.5,p1.y
				-- y major
				if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
				local cy0,cy1,dx=y0\1+1,y1\1+1,(x1-x0)/(y1-y0)
				if(y1-cy0>1) x0+=(cy0-y0)*dx --x1+=(cy1-y1)*dx
					--rectfill(x0-0.5,y0,x0+(cy0-y0)*dx,y0,8) 

				line(x0,cy0,x1,cy1)
			end
		end
	end
end