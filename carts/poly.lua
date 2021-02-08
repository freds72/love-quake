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