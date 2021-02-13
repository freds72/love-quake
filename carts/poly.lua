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
			if spans[y] then
				rectfill(x0,y,spans[y],y)
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

function tpoly(v)
	local p0,spans=v[#v],{}
	local x0,y0,w0=p0.x,p0.y,p0.w
	local u0,v0=p0.u*w0,p0.v*w0
	-- ipairs is slower for small arrays
	for i=1,#v do
		local p1=v[i]
		local x1,y1,w1=p1.x,p1.y,p1.w
		local u1,v1=p1.u*w1,p1.v*w1
		local _x1,_y1,_w1,_u1,_v1=x1,y1,w1,u1,v1
		if(y0>y1) x0,y0,x1,y1,w0,w1,u0,v0,u1,v1=x1,y1,x0,y0,w1,w0,u1,v1,u0,v0
		local dy=y1-y0
		local dx,dw,du,dv=(x1-x0)/dy,(w1-w0)/dy,(u1-u0)/dy,(v1-v0)/dy
		local cy0=y0\1+1
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
				-- backup current edge values
				local b,bu,bv,bw,a,au,av,aw=x0,u0,v0,w0,unpack(span)
				if(a>b) a,au,av,aw,b,bu,bv,bw=b,bu,bv,bw,unpack(span)
			 
				local x0,x1=a\1+1,b\1
				if(x1>127) x1=127
				if x0<=x1 then
					local dab=b-a
					local dau,dav,daw=(bu-au)/dab,(bv-av)/dab,(bw-aw)/dab
					-- sub-pix shift
					local sa=x0-a
					if(x0<0) au-=x0*dau av-=x0*dav aw-=x0*daw x0=0 sa=0
					au+=sa*dau
					av+=sa*dav
					aw+=sa*daw
					
					-- 4-pixel stride deltas
					dau<<=2
					dav<<=2
					daw<<=2

						-- faster but produces edge artifacts
						-- local du,dv=(bu/bw-au/aw)/dab,(bv/bw-av/aw)/dab

					-- clip right span edge
					poke(0x5f22,x1+1)

					for x=x0,x1,4 do
						local u,v=au/aw,av/aw
						aw+=daw
						tline(x,y,x+3,y,u,v,((dau-u*daw)>>2)/aw,((dav-v*daw)>>2)/aw)
						au+=dau
						av+=dav
					end
				end
			else
				spans[y]={x0,u0,v0,w0}
			end
			x0+=dx
			w0+=dw
			u0+=du
			v0+=dv
		end
		x0,y0,w0,u0,v0=_x1,_y1,_w1,_u1,_v1
	end
	--[[
	local v0,v1,v2,v3=
		v[1],
		v[2],
		v[3],
		v[4]
	line(v0.x,v0.y,v1.x,v1.y,7)
	line(v1.x,v1.y,v2.x,v2.y,7)
	line(v2.x,v2.y,v3.x,v3.y,7)
	line(v3.x,v3.y,v0.x,v0.y,7)
	]]
end

function mempoly(v,col)
	col&=0xf
	local c,c0,c1=col*0x11,col<<4,col
	local nv,nodes=#v,{}
	for i=1,#v do
		local v0,v1=v[i%nv+1],v[i]
		local x0,y0,x1,y1=v0.x>>1,v0.y>>1,v1.x>>1,v1.y>>1
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local cy0,dx=y0\1+1,(x1-x0)/(y1-y0)
		if(y0<0) x0-=y0*dx y0=0 cy0=0
		x0+=(cy0-y0)*dx
		if(y1>64) y1=64
		for y=cy0,y1 do
			local x=nodes[y]
			if x then
				local x0,x1=x,x0
				if(x0>x1) x0,x1=x1,x0
				if(x0<0) x0=0
				if(x1>64) x1=64
				if x1>=x0 then
					-- odd boundary?
					local off=x0\2
					local p,w=0x1000|y<<6|off,x1\2-off+1
					if (x0 & 1)!=0 then
						w-=1
						poke(p,@p & 0x0f | c0)
						p+=1
					end
					if x1&1==0 then
						w-=1
						poke(p+w,@(p+w) & 0xf0 | c1)
					end
					memset(p,c,w)         				
				end
			else
			nodes[y]=x0
			end
			x0+=dx					
		end			
	end
end