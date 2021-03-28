-- plain color polygon rasterization
function polyfill(p,c)
	--color(c)
	local miny,maxy,mini=32000,-32000
	for i,v in pairs(p) do
		local y=v.y
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end

	--data for left & right edges:
	local np,li,lj,ri,rj,ly,ry,lx,ldx,rx,rdx=#p,mini,mini,mini,mini,miny-1,miny-1

	--step through scanlines.
	for y=max(0,ceil(miny)),min(ceil(maxy)-1,127) do
		--maybe update to next vert
		while ly<y do
			li=lj
			lj+=1
			if (lj>np) lj=1
			local v0,v1=p[li],p[lj]
			local y0,y1=v0.y,v1.y
			ly=ceil(y1)-1
			lx=v0.x
			ldx=(v1.x-lx)/(y1-y0)
			--sub-pixel correction
			lx+=(y-y0)*ldx
		end   
		while ry<y do
			ri=rj
			rj-=1
			if (rj<1) rj=np
			local v0,v1=p[ri],p[rj]
			local y0,y1=v0.y,v1.y
			ry=ceil(y1)-1
			rx=v0.x
			rdx=(v1.x-rx)/(y1-y0)
			--sub-pixel correction
			rx+=(y-y0)*rdx
		end
		rectfill(lx,y,rx,y,c)
		lx+=ldx
		rx+=rdx
	end
end

function polyfill(p,c)
	color(c)
	local miny,maxy,mini=32000,-32000
	local minx,maxx,minix=32000,-32000
	for i,v in pairs(p) do
		local x,y=v.x,v.y
		if (x<minx) minix,minx=i,x
		if (x>maxx) maxx=x
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end

	--
	if abs(minx-maxx)<abs(miny-maxy) then
		--data for left & right edges:
		local np,li,lj,ri,rj,lx,rx,ly,ldy,ry,rdy=#p,minix,minix,minix,minix,minx-1,minx-1

		--step through scanlines.
		for x=max(0,ceil(minx)),min(ceil(maxx)-1,127) do
			--maybe update to next vert
			while lx<x do
				li=lj
				lj+=1
				if (lj>np) lj=1
				local v0,v1=p[li],p[lj]
				local x0,x1=v0.x,v1.x
				lx=ceil(x1)-1
				ly=v0.y
				ldy=(v1.y-ly)/(x1-x0)
				--sub-pixel correction
				ly+=(x-x0)*ldy
			end   
			while rx<x do
				ri=rj
				rj-=1
				if (rj<1) rj=np
				local v0,v1=p[ri],p[rj]
				local x0,x1=v0.x,v1.x
				rx=ceil(x1)-1
				ry=v0.y
				rdy=(v1.y-ry)/(x1-x0)
				--sub-pixel correction
				ry+=(x-x0)*rdy
			end
			rectfill(x,ly,x,ry)
			--pset(x,ly,0)
			--pset(x,ry,0)
			ly+=ldy
			ry+=rdy
		end
	else
		--data for left & right edges:
		local np,li,lj,ri,rj,ly,ry,lx,ldx,rx,rdx=#p,mini,mini,mini,mini,miny-1,miny-1

		--step through scanlines.
		for y=max(0,ceil(miny)),min(ceil(maxy)-1,127) do
			--maybe update to next vert
			while ly<y do
				li=lj
				lj+=1
				if (lj>np) lj=1
				local v0,v1=p[li],p[lj]
				local y0,y1=v0.y,v1.y
				ly=ceil(y1)-1
				lx=v0.x
				ldx=(v1.x-lx)/(y1-y0)
				--sub-pixel correction
				lx+=(y-y0)*ldx
			end   
			while ry<y do
				ri=rj
				rj-=1
				if (rj<1) rj=np
				local v0,v1=p[ri],p[rj]
				local y0,y1=v0.y,v1.y
				ry=ceil(y1)-1
				rx=v0.x
				rdx=(v1.x-rx)/(y1-y0)
				--sub-pixel correction
				rx+=(y-y0)*rdx
			end
			rectfill(lx,y,rx,y)
			--pset(lx,y,0)
			--pset(rx,y,0)
			lx+=ldx
			rx+=rdx
		end
	end
end

function polyline(v,c)
	color(c)
	local nv=#v
	for i,p1 in pairs(v) do
		local p0=v[i%nv+1]
		line(p0.x,p0.y,p1.x,p1.y)
	end
end

function tpoly(v,c)
	color(c)
	local nv,spans=#v,{}
	-- ipairs is slower for small arrays
	for i=1,#v do
		local p0,p1=v[i%nv+1],v[i]
		local x0,y0,w0,x1,y1,w1=p0.x,p0.y,p0.w,p1.x,p1.y,p1.w
		local u0,v0,u1,v1=p0.u*w0,p0.v*w0,p1.u*w1,p1.v*w1
		if(y0>y1) x0,y0,x1,y1,w0,w1,u0,v0,u1,v1=x1,y1,x0,y0,w1,w0,u1,v1,u0,v0
		local dy=y1-y0
		local cy0,dx,dw,du,dv=y0\1+1,(x1-x0)/dy,(w1-w0)/dy,(u1-u0)/dy,(v1-v0)/dy
		if(y0<0) x0-=y0*dx w0-=y0*dw u0-=y0*du v0-=y0*dv y0=0 cy0=0
		-- sub-pix shift
		local sy=cy0-y0
		x0+=sy*dx
		w0+=sy*dw
		u0+=sy*du
		v0+=sy*dv
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				local a,aw,au,av,b,bw,bu,bv=x0,w0,u0,v0,unpack(span)
				if(a>b) a,aw,au,av,b,bw,bu,bv=b,bw,bu,bv,a,aw,au,av
				local ca,cb=a\1+1,b\1
				if ca<=cb then
					-- perspective correct mapping
					local sa=ca-a
					local dab=b-a
					local dau,dav=(bu-au)/dab,(bv-av)/dab
					tline(ca,y,cb,y,(au+sa*dau)/aw,(av+sa*dav)/aw,dau/aw,dav/aw)
				end
			else
				spans[y]={x0,w0,u0,v0}
			end
			x0+=dx
			w0+=dw
			u0+=du
			v0+=dv
		end
	end
end
