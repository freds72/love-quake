local maths3d={}

-- maths & cam
function lerp(a,b,t)
	return a*(1-t)+b*t
end

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
	return {
		v[1]*scale,
		v[2]*scale,
		v[3]*scale}
end
function v_add(v,dv,scale)
	scale=scale or 1
	return {
		v[1]+scale*dv[1],
		v[2]+scale*dv[2],
		v[3]+scale*dv[3]}
end
function v_lerp(a,b,t,uv)
  local ax,ay,az,u,v,l=a[1],a[2],a[3],a.u,a.v,a.l
	return {
    ax+(b[1]-ax)*t,
    ay+(b[2]-ay)*t,
    az+(b[3]-az)*t,
    u=uv and u+(b.u-u)*t,
    v=uv and v+(b.v-v)*t,
	-- light?
	l=l and l+(b.l-l)*t
  }
end

function v_cross(a,b)
	local ax,ay,az=a[1],a[2],a[3]
	local bx,by,bz=b[1],b[2],b[3]
	return {ay*bz-az*by,az*bx-ax*bz,ax*by-ay*bx}
end
-- safe for overflow (to some extent)
function v_len(v)
	local x,y,z=v[1],v[2],v[3]
  -- pick major
  local d=max(max(abs(x),abs(y)),abs(z))
  if d==0 then return 0 end
  -- adjust
  x=x/d
  y=y/d
  z=z/d
  -- actuel len
  return sqrt(x*x+y*y+z*z)*d
end

function v_normz(v)
  local d=v_len(v)
	return {v[1]/d,v[2]/d,v[3]/d},d
end

-- matrix functions
function m_clone(a)
	local m={}
	for k,v in pairs(a) do
		m[k]=v
	end
	return m
end

-- matrix vector multiply
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]}	
end
-- vector matrix multiply
function m_x_n(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[5]*y+m[9]*z,m[2]*x+m[6]*y+m[10]*z,m[3]*x+m[7]*y+m[11]*z}
end

function make_m_from_euler(x,y,z)
	local a,b = cos(x),-sin(x)
	local c,d = cos(y),-sin(y)
	local e,f = cos(z),-sin(z)
  
    -- zyx order
	local ae,af,be,bf = a * e, a * f, b * e, b * f
	return {
		c * e, c * f, - d ,0,
		be * d - af, bf * d + ae,  b * c, 0,
		ae * d + bf, af * d - be, a * c, 0,
		0,0,0,1}
end

function make_m_look_at(up,fwd)
	local right=v_normz(v_cross(fwd,up))
	up=v_cross(right,fwd)
	return {
		right[1],right[2],right[3],0,
		fwd[1],fwd[2],fwd[3],0,
		up[1],up[2],up[3],0,
		0,0,0,1
	}
end

-- returns basis vectors from matrix
function m_right(m)
	return {m[1],m[2],m[3]}
end
function m_fwd(m)
	return {m[5],m[6],m[7]}
end
function m_up(m)
	return {m[9],m[10],m[11]}
end
function m_set_pos(m,v)
	m[13]=v[1]
	m[14]=v[2]
	m[15]=v[3]
end

-- optimized 4x4 matrix mulitply
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

-- inline matrix vector multiply invert
-- inc. position
function m_inv_x_v(m,v)
	local x,y,z=v[1]-m[13],v[2]-m[14],v[3]-m[15]
	return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
end
function m_inv_x_n(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
end


function make_m_from_v_angle(up,angle)
	local fwd={-sin(angle),0,cos(angle)}
	local right=v_normz(v_cross(up,fwd))
	fwd=v_cross(right,up)
	return {
		right[1],right[2],right[3],0,
		up[1],up[2],up[3],0,
		fwd[1],fwd[2],fwd[3],0,
		0,0,0,1
	}
end

function v_tostring(v)
	return "("..v[1].." "..v[2].." "..v[3]..")"
end

-- returns if 2 3d boxes overlap
function bbox_overlap(mins,maxs,other_mins,other_maxs)
	local x0,y0,z0,x1,y1,z1=mins[1],mins[2],mins[3],maxs[1],maxs[2],maxs[3]    
	return x0<=other_maxs[1] and x1>=other_mins[1] and
		   y0<=other_maxs[2] and y1>=other_mins[2] and
		   z0<=other_maxs[3] and z1>=other_mins[3]
end

function v_min(a,b)
	return {
		min(a[1],b[1]),
		min(a[2],b[2]),
		min(a[3],b[3])
	}
end
function v_max(a,b)
	return {
		max(a[1],b[1]),
		max(a[2],b[2]),
		max(a[3],b[3])
	}
end


return maths3d