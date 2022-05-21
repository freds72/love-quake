-- textured 3d demo
-- by freds72

-- globals
local cam
local tiles = {width=4,height=4,ptr={
	[0]=19,24,19,24,
	24,19,24,19,
	19,24,19,24,
	24,19,24,19
}}

-- helper functions
function lerp(a,b,t)
	return a*(1-t)+b*t
end

-- vector helpers
local v_up={0,1,0}

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_scale(v,scale)
	v[1]=v[1]*scale
	v[2]=v[2]*scale
	v[3]=v[3]*scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	return {
		v[1]+scale*dv[1],
		v[2]+scale*dv[2],
		v[3]+scale*dv[3]}
end
-- safe vector length
function v_len(v)
	local x,y,z=v[1],v[2],v[3]
	local d=max(max(abs(x),abs(y)),abs(z))
	if d<0.001 then return 0 end
	x=x/d
	y=y/d
	z=z/d
	return d*sqrt(x*x+y*y+z*z)
end
function v_normz(v)
	local x,y,z=v[1],v[2],v[3]
	local d=x*x+y*y+z*z
	if d>0.001 then
		d=sqrt(d)
		return {x/d,y/d,z/d}
	end
	return v
end

function v_lerp(a,b,t)
	return {
		lerp(a[1],b[1],t),
		lerp(a[2],b[2],t),
		lerp(a[3],b[3],t)
	}
end
function v_cross(a,b)
	local ax,ay,az=a[1],a[2],a[3]
	local bx,by,bz=b[1],b[2],b[3]
	return {ay*bz-az*by,az*bx-ax*bz,ax*by-ay*bx}
end

-- inline matrix invert
-- inc. position
function m_inv_x_v(m,v)
	local x,y,z=v[1]-m[13],v[2]-m[14],v[3]-m[15]
	return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
end

-- returns foward vector from matrix
function m_fwd(m)
	return {m[9],m[10],m[11]}
end
-- returns up vector from matrix
function m_up(m)
	return {m[5],m[6],m[7]}
end
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]}
end

function m_x_m(a,b)
	local a11,a12,a13,a21,a22,a23,a31,a32,a33=a[1],a[5],a[9],a[2],a[6],a[10],a[3],a[7],a[11]
	local b11,b12,b13,b14,b21,b22,b23,b24,b31,b32,b33,b34=b[1],b[5],b[9],b[13],b[2],b[6],b[10],b[14],b[3],b[7],b[11],b[15]

	return {
			a11*b11+a12*b21+a13*b31,a21*b11+a22*b21+a23*b31,a31*b11+a32*b21+a33*b31,0,
			a11*b12+a12*b22+a13*b32,a21*b12+a22*b22+a23*b32,a31*b12+a32*b22+a33*b32,0,
			a11*b13+a12*b23+a13*b33,a21*b13+a22*b23+a23*b33,a31*b13+a32*b23+a33*b33,0,
			a11*b14+a12*b24+a13*b34+a[13],a21*b14+a22*b24+a23*b34+a[14],a31*b14+a32*b24+a33*b34+a[15],1
		}
end

function make_m_from_euler(x,y,z)
	local a,b = cos(x),-sin(x)
	local c,d = cos(y),-sin(y)
	local e,f = cos(z),-sin(z)

	-- yxz order
	local ce,cf,de,df=c*e,c*f,d*e,d*f
 	return {
 		ce+df*b,a*f,cf*b-de,0,
  		de*b-cf,a*e,df+ce*b,0,
  		a*d,-b,a*c,0,
  		0,0,0,1}
end

function prepare_model(model)
	for _,f in pairs(model.f) do
		-- de-reference vertex indices
		for i=1,4 do
			f[i]=model.v[f[i]]
		end

		-- normal
		f.n=v_normz(
				v_cross(
					make_v(f[1],f[4]),
					make_v(f[1],f[2])))
		-- fast viz check
		f.cp=v_dot(f.n,f[1])
	end
	return model
end

-- models
local cube_model=prepare_model({
		v={
			{0,0,0},
			{1,0,0},
			{1,0,1},
			{0,0,1},
			{0,1,0},
			{1,1,0},
			{1,1,1},
			{0,1,1},
		},
		-- faces + vertex uv's
		f={
			{1,4,3,2,uv={0,0,4,0,4,4,0,4}},
			{1,2,6,5,uv={2,0,4,0,4,2,2,2}},
			{2,3,7,6,uv={0,0,2,0,2,2,0,2}},
			{3,4,8,7,uv={2,0,4,0,4,2,2,2}},
			{4,1,5,8,uv={0,0,2,0,2,2,0,2}},
			{5,6,7,8,uv={0,2,2,2,2,4,0,4}},
		}
	})

function make_cam(x0,y0,focal)
	local yangle,zangle=0,0
	local dyangle,dzangle=0,0

	return {
		pos={0,0,0},
		control=function(self,dist)
			if btn(0) then dyangle=dyangle+1 end
			if btn(1) then dyangle=dyangle-1 end
			if btn(2) then dzangle=dzangle+1 end
			if btn(3) then dzangle=dzangle-1 end
			yangle=yangle+dyangle/128+0.01
			zangle=zangle+dzangle/128+0.005
			-- friction
			dyangle=dyangle*0.8
			dzangle=dzangle*0.8

			local m=make_m_from_euler(zangle,yangle,0)
			local pos=m_fwd(m)
			v_scale(pos,dist)

			-- inverse view matrix
			-- only invert orientation part
			m[2],m[5]=m[5],m[2]
			m[3],m[9]=m[9],m[3]
			m[7],m[10]=m[10],m[7]		

			self.m=m_x_m(m,{
				1,0,0,0,
				0,1,0,0,
				0,0,1,0,
				-pos[1],-pos[2],-pos[3],1
			})
			
			self.pos=pos
		end,
		project=function(self,verts)
			local n,f=0.1,2
			for i,v in pairs(verts) do
				local x,y,z=v[1],v[2],v[3]
				z=z*f/(f-n)+f*n/(f-n)
				local w=focal/z
				verts[i]={x=x0+x*w,y=y0-y*w,w=w,u=v.u*w,v=v.v*w}
			end
			return verts
		end
	}
end

function draw_model(model,m,cam)
	-- cam pos in object space
	local cam_pos=m_inv_x_v(m,cam.pos)
	
	-- object to world
	-- world to cam
	m=m_x_m(cam.m,m)

	for _,face in pairs(model.f) do
		-- is face visible?
		if v_dot(face.n,cam_pos)>face.cp then
			local verts={}
			for k=1,4 do
				-- transform to world
				local p=m_x_v(m,face[k])
				-- attach u/v coords to output
				p.u=face.uv[2*k-1]
				p.v=face.uv[2*k]
				verts[k]=p
			end
			-- transform to camera & draw			
			polytex(cam:project(verts))
		end
	end
end


function _init()
	cam=make_cam(480/2,270/2,96.5)
end

function _update()
	cam:control(2)
end

function _draw()
	cls()

	local m={
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		-0.5,-0.5,-0.5,1}
	draw_model(cube_model,m,cam)
end

-->8

function polytex(v)
 local p0,nodes=v[#v],{}
 local x0,y0,w0,u0,v0=p0.x,p0.y,p0.w,p0.u,p0.v
 for i=1,#v do
	local p1=v[i] 
	local x1,y1,w1,u1,v1=p1.x,p1.y,p1.w,p1.u,p1.v
	local _x1,_y1,_u1,_v1,_w1=x1,y1,u1,v1,w1
	if y0>y1 then
		x0,y0,x1,y1,w0,w1,u0,v0,u1,v1=x1,y1,x0,y0,w1,w0,u1,v1,u0,v0
	end
	local dy=y1-y0
	local cy0,dx,dw,du,dv=flr(y0)+1,(x1-x0)/dy,(w1-w0)/dy,(u1-u0)/dy,(v1-v0)/dy
	-- sub-pix shift
	local sy=cy0-y0
	if y0<0 then
		x0=x-y0*dx u0=u0-y0*du v0=v0-y0*dv w0=w0-y0*dw cy0=0 sy=0
	end
	x0=x0+sy*dx
	u0=u0+sy*du
	v0=v0+sy*dv
	w0=w0+sy*dw

	if y1>269 then y1=269 end
	for y=cy0,flr(y1) do
		local span=nodes[y]
		if span then
			-- backup current edge values
			local b,bu,bv,bw,a,au,av,aw=x0,u0,v0,w0,unpack(span)
			if a>b then
				a,au,av,aw,b,bu,bv,bw=b,bu,bv,bw,unpack(span)
			end
			
			local x0,x1=flr(a)+1,flr(b)
			if x1>479 then x1=479 end
			if x0<=x1 then
				local dab=b-a
				local dau,dav,daw=(bu-au)/dab,(bv-av)/dab,(bw-aw)/dab
				-- sub-pix shift
				local sa=x0-a
				if x0<0 then au=au-x0*dau av=av-x0*dav aw=aw-x0*daw x0=0 sa=0 end
				au=au+sa*dau
				av=av+sa*dav
				aw=aw+sa*daw
				tline3d(tiles,flr(x0),y,flr(x1),y,au,av,aw,dau,dav,daw)				
			end
		else
			nodes[y]={x0,u0,v0,w0}
		end
		x0=x0+dx
		u0=u0+du
		v0=v0+dv
		w0=w0+dw
  end
  x0=_x1
  y0=_y1
  u0=_u1
  v0=_v1
  w0=_w1
 end
end
