-- plain color polygon rasterization
function polyfill(v,c)	
	color(c)

	local nv,spans=#v,{}
	-- ipairs is slower for small arrays
	for i=1,nv do
		local p0,p1=v[i%nv+1],v[i]
		local x0,y0,x1,y1=p0.x,p0.y,p1.x,p1.y
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local cy0,dx=y0\1+1,(x1-x0)/(y1-y0)
		if(y0<0) x0-=y0*dx y0=0 cy0=0
		-- sub-pix shift
		x0+=(cy0-y0)*dx
		if(y1>127) y1=127
		for y=cy0,y1 do
			local x1=spans[y]
			if x1 then
				rectfill(x0,y,x1,y)
			else
				spans[y]=x0
			end
			x0+=dx
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
