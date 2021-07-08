-- plain color polygon rasterization
function polyfill(p,c)
	color(c)
	local nv,spans=#p,{}
	for i,p1 in pairs(p) do
		local p0=p[i%nv+1]
		local x0,y0,x1,y1=p0.x,p0.y,p1.x,p1.y
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local cy0,dx=(y0&-1)+1,(x1-x0)/(y1-y0)
		if(y0<0) x0-=y0*dx y0=0 cy0=0
		-- sub-pix shift
		x0+=(cy0-y0)*dx
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				rectfill(x0,y,span,y)				
				--rectfill(x0,y,span,y)			
			else
				spans[y]=x0
			end
			x0+=dx
		end
	end
end

function polytex_ymajor(v,uvs,slope)

 local n,nodes,offset=#v,{},(slope<<7)&-1
 for i,p1 in pairs(v) do
  local p0,uv0,uv1=v[i%n+1],uvs[i%n+1],uvs[i]
	 local x0,w0,x1,w1=p0.x,p0.w,p1.x,p1.w
		local u0,v0,u1,v1=uv0[1]*w0,uv0[2]*w0,uv1[1]*w1,uv1[2]*w1
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
	  local span=nodes[y]
	  if span then
				local x0,u0,v0,x1,u1,v1=x0,u0/w0,v0/w0,span[1],span[2],span[3]
				if(x0>x1) x0,x1,u0,v0,u1,v1=x1,x0,u1,v1,u0,v0
				local ddx=((x1+0x1.ffff)&-1)-(x0&-1)
				clip(x0,0,ddx,128)		
				local ddu,ddv=(u1-u0)/ddx,(v1-v0)/ddx
				tline(0,y,128,y+offset,u0-x0*ddu,v0-x0*ddv,ddu,ddv)
	  else
	   nodes[y]={x0,u0/w0,v0/w0}
	  end
	  x0+=dx
			w0+=dw
			u0+=du
			v0+=dv
  end
 end
	clip()
end

function polytex_xmajor(v,uvs,slope)
 local n,nodes,offset=#v,{},(slope<<7)&-1

	for i,p1 in pairs(v) do
  local p0=v[i%n+1] 
  local p0,uv0,uv1=v[i%n+1],uvs[i%n+1],uvs[i]
		local y0,w0,y1,w1=p0.y,p0.w,p1.y,p1.w
		local u0,v0,u1,v1=uv0[1]*w0,uv0[2]*w0,uv1[1]*w1,uv1[2]*w1
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
	  local span=nodes[x]
	  if span then
				local y0,u0,v0,y1,u1,v1=y0,u0/w0,v0/w0,span[1],span[2],span[3]
				if(y0>y1) y0,y1,u0,v0,u1,v1=y1,y0,u1,v1,u0,v0
				local ddy=((y1+0x1.ffff)&-1)-(y0&-1)
				clip(0,y0,128,ddy)
				-- line(x,0,x+offset,128)
				--rectfill(x,y0,x,span,8)
				local ddu,ddv=(u1-u0)/ddy,(v1-v0)/ddy
				tline(x,0,x+offset,128,u0-y0*ddu,v0-y0*ddv,ddu,ddv)
	  else
	   nodes[x]={y0,u0/w0,v0/w0}
	  end
	  y0+=dy
			w0+=dw
			u0+=du
			v0+=dv
  end
 end
	clip()
end
