pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- sbuffer
-- @freds72
-- unit test for span buffer
--
#include poly.lua

-- s-buffer demo
-- by mahkoe

function _init()
	palt(0,false)
end

tot = 0
cnt = 0

shape_sel = 6

cur_mat = {
	1, 0, 0, 0,
	0, -1, 0, 0,
	0, 0, -1, 0
}

-- obtained from:
-- https://www.andre-gaschler.com/rotationconverter/
roll_fwd = {
  1.0000000,  0.0000000,  0.0000000, 0,
  0.0000000,  0.9993908,  0.0348995, 0,
  0.0000000, -0.0348995,  0.9993908, 0
}
roll_bwd = {
  1.0000000,  0.0000000,  0.0000000, 0,
  0.0000000,  0.9993908, -0.0348995, 0,
  0.0000000,  0.0348995,  0.9993908, 0
}
yaw_lt = {
  0.9993908,  0.0000000,  0.0348995, 0,
  0.0000000,  1.0000000,  0.0000000, 0,
 -0.0348995,  0.0000000,  0.9993908, 0
}
yaw_rt = {
  0.9993908,  0.0000000, -0.0348995, 0,
  0.0000000,  1.0000000,  0.0000000, 0,
  0.0348995,  0.0000000,  0.9993908, 0
}

function rst_mat()
	cur_mat = {
		1, 0, 0, 0,
		0, -1, 0, 0,
		0, 0, -1, 0
	}
end

function _update()
	if (btnp(🅾️)) then
		shape_sel -= 1
		rst_mat()
	end
	if (shape_sel < 1) then
		shape_sel = #all_shapes
	end
	if (btnp(❎)) then
		shape_sel += 1
		rst_mat()
	end
	if (shape_sel > #all_shapes) then
		shape_sel = 1
	end
	
	if (btn(⬆️)) then
		cur_mat = matmul(
			roll_fwd, cur_mat
		)
	end
	
	if (btn(⬇️)) then
		cur_mat = matmul(
			roll_bwd, cur_mat
		)
	end
	
	if (btn(⬅️)) then
		cur_mat = matmul(
			yaw_lt, cur_mat
		)
	end
	
	if (btn(➡️)) then
		cur_mat = matmul(
			yaw_rt, cur_mat
		)
	end
end

function _draw()
	cls(0)
	
	--sbuf_clr()
    _spans={}
	-- due to accumulated precision
	-- errors, once in a while it's
	-- nice to reset the matrix
	
	if (flr(t())%120 == 0 and rot_en) then
		cur_mat = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0
		}
	end
	
	verts = all_verts[shape_sel]
	cols = all_cols[shape_sel]
	shape = all_shapes[shape_sel]
		
	local shaded = 
		shade_lst(verts,cur_mat)
	local disp=persp_lst(shaded)
		
	non_culled = 0
	
	for i,v in ipairs(shape) do
		--[[if (stat(1) >= 0.9) then
			cursor(8,90)
			print("too many polys!",8)
			print("need to quit early...",8)
			print("i managed "..non_culled)
			tot += non_culled
			cnt += 1
			print("(avg: "..tot/cnt..")")
			if (tot > 0x6000) then
				tot /= 200
				cnt /= 200
			end
			break
		end]]--
		local p = getpoly(disp,v)
        --[[
		local rc = scanpoly(p)
		if (rc) then
			non_culled += 1
			local c = 
				cols[i][1]*16 +
				cols[i][2]
			local orig = getpoly(
				shaded,v
			)
			local br = brightness(
				orig, some_light
			)
			poly2sbuf(b_tbl[br],c)
		end
        ]]
        local c = 
            cols[i][1]*16 +
            cols[i][2]
        local orig = getpoly(
            shaded,v
        )
        local br = brightness(
            orig, some_light
        )            
    	fillp(b_tbl[br])
        polyfill(p,#p,c)
	end
	
	draw_sbuf()
	
	--fillp()
	--rectfill(60,116,127,127,0x70)
	cursor(2,2)
	print([[
🅾️❎     - select shape
⬆️⬇️⬅️➡️ - rotate]], 8)
	
	if (shape_sel == 6) then
		print([[
https://opengameart.org/
content/5-low-poly-animals]],11)
		
	end
end
-->8
--fillpoly

--global variables modified by
--scanpoly (and read by 
--fillpoly)
lts = {}
rts = {}
zlts = {}
zrts = {}
miny,maxy = 0,0

--helper function used by 
--scanpoly. not meant to be
--called by library user
function is_cw(pts)
	local n = #pts
	--try to pick points evenly
	--distributed around the shape
	local v2 = n\3
	if (v2 < 2) v2 = 2
	local v3 = 2*n\3
	if (v3 <= v2) v3 = v2+1
	local dx1 = pts[v2].x-pts[1].x
	local dy1 = pts[v2].y-pts[1].y
	local dx2 = pts[v3].x-pts[1].x
	local dy2 = pts[v3].y-pts[1].y
	local ret=(dx1*dy2 > dx2*dy1)
	return ret
end

--helper function used by 
--scanpoly. not meant to be
--called by library user
function scanln(p1,p2,arr,zarr)
	local x = p1.x
	local dx = abs(p2.x-p1.x)
	local dy = abs(p2.y-p1.y)
	local z = p1.z
	local dz = (p2.z-p1.z)/dy
	local n = 0
	local sy = 1
	if (p2.y < p1.y) sy = -1
	local sx = 1
	if (p2.x < p1.x) sx = -1
	local istep = sx*(dx\dy)
	local nstep = dx%dy
	for y = p1.y,p2.y,sy do
		--if (y>=0 and y <=127) then
			arr[y] = x
			zarr[y] = z
		--end
		x += istep
		n += nstep
		if (n >= dy) then
			x += sx
			n -= dy
		end
		z += dz
	end	
end

--scan points of a polygon.
--doesn't draw anything; need
--to call fillpoly for that.
--instead, fills lts and rts
--arrays and sets miny,maxy
function scanpoly(pts)
	local n = #pts
	
	--if (n<2 or is_cw(pts)) then
	--	return false
	--end
	
	wrap = function(x)
		if (x > n) then
			x-=n
		elseif (x < 1) then
			x+=n
		end
		return x
	end
	
	-- find index of min/max y
	local imin,imax = 1,1
	miny = pts[1].y
	maxy = pts[1].y
	
	for i=2,n do
		if (pts[i].y > maxy) then
			maxy = pts[i].y
			imax = i
		elseif (pts[i].y < miny) then
			miny = pts[i].y
			imin = i
		end
	end
		
	-- scan lines into lts or rts
	-- array (declared at top of
	-- this tab)
	local li,lf = imin,imax
	local ri,rf = imin,imax
	
	-- check special case for flat
	-- top/bottom
	local tmp = wrap(imin+1)
	if (pts[tmp].y==miny) ri=tmp
	tmp = wrap(imax+1)
	if (pts[tmp].y==maxy) lf=tmp
	
	
	-- scan left lines
	local idx = li
	while (idx~=lf) do
		nxt=wrap(idx+1)
		--dbg("adding "..idx.." to lefts")
		scanln(pts[idx],pts[nxt],lts,zlts)
		idx=nxt
	end
	
	-- scan right lines
	idx = ri
	while (idx~=rf) do
		nxt=wrap(idx-1)
		--dbg("adding "..idx.." to rights")
		scanln(pts[idx],pts[nxt],rts,zrts)
		idx=nxt
	end
	
	-- check for backface cull
	local ytst = (miny+maxy)\2
	if (lts[ytst] > rts[ytst]+1) then
		return false
	end
	
	return true
end

b_tbl = {
	0x0000, -- all dark
	0x0001, -- 1/16 light
	0x8020, -- 2/16 light
	0x080a, -- 3/16 light
	0x050a, -- 4/16 light
	0x5250, -- 5/16 light
	0x8525, -- 6/16 light
	0x25a5, -- 7/16 light
	0xa5a5, -- 8/16 light
	0xa5ad, -- 9/16 light
	0xada7, -- 10/16 light
	0xfada, -- 11/16 light
	0xfaf5, -- 12/16 light
	0x5f7f, -- 13/16 light
	0xdf7f, -- 14/16 light
	0xfeff, -- 15/16 light
	0xffff  -- all light
}

--lt: light colour idx
--dk: dark colour idx
--b: brightness, 1-17 inclusive
--assumes that you have already
--scanned the points of the
--polygon
function fillpoly(lt,dk,b)
	dk = dk or lt
	b = b or 9
	
	fillp(b_tbl[b])
	
	-- prevent overdraw for vert-
	-- ically adjacent polys by
	-- skipping first y
	local col = dk + 16*lt
	for y = miny+1,maxy do
		--if (lts[y]<rts[y]) then
			line(
				lts[y]+1,y,
				rts[y],y,
				col
			)
		--end
	end
end
-->8
-- 3d stuff

-- some vector functions

function mvmul(m,v)
	local a,b,c=v[1],v[2],v[3]
	return {
		m[1]*a+m[2]*b+m[3]*c+m[4],
		m[5]*a+m[6]*b+m[7]*c+m[8],
		m[9]*a+m[10]*b+m[11]*c+m[12]
	}
end

function matmul(a,b)
	local u=mvmul(a,{b[1],b[5],b[9]})
	local v=mvmul(a,{b[2],b[6],b[10]})
	local w=mvmul(a,{b[3],b[7],b[11]})
	
	return {
		u[1],v[1],w[1],a[4]+b[4],
		u[2],v[2],w[2],a[8]+b[8],
		u[3],v[3],w[3],a[12]+b[12]
	}
end

function vmag(v)
	return sqrt(
		v[1]*v[1] + 
		v[2]*v[2] +
		v[3]*v[3]
	)
end

function cross(a,b)
	return {
		a[2]*b[3]-a[3]*b[2],
		a[3]*b[1]-a[1]*b[3],
		a[1]*b[2]-a[2]*b[1]
	}
end

function dot(a,b)
	return (
		a[1]*b[1] + 
		a[2]*b[2] +
		a[3]*b[3]
	)
end

function vsub(a,b)
	return {
		a[1] - b[1],
		a[2] - b[2],
		a[3] - b[3]
	}
end

function nrm(v)
	local magi = 1/vmag(v)
	return {
		v[1]*magi,
		v[2]*magi,
		v[3]*magi
	}
end

some_light = nrm({
	2,5,7
})

--assumes l is normalized
function brightness(pts,l)
	local dv1 = vsub(pts[2],pts[1])
	local dv2 = vsub(pts[3],pts[1])
	
	local n = nrm(cross(dv1,dv2))
	
	local b = -dot(n,l)
		
	local sh = flr(b*17 + 0.5)
	if (sh > 17) then
		sh = 17
	elseif (sh < 1) then
		sh = 1
	end
	
	return sh
end

fov = 5
scl = 32
sf = scl*fov
function persp(v)
	local s = sf/(fov+v[3])
	return {
		x = flr(v[1]*s + 63),
		y = flr(v[2]*s + 63),
		z = v[3],
        w = s
	}
end

function persp_lst(lst)
	local ret = {}
	for i,v in ipairs(lst) do
		ret[i]=persp(v)
	end
	return ret
end

--i just made up a random 
--rotation and used this:
--https://www.andre-gaschler.com/rotationconverter/
--this should rotate 2 degrees
--around the axis <1,-1,-1>
some_rot = {
   0.9995939,  0.0199462, -0.0203523, 0,
  -0.0203523,  0.9995939, -0.0199462, 0,
   0.0199462,  0.0203523,  0.9995939, 0
}
--this should rotate 1 degree
--around the axis <1,2,3>
some_rot2 = {
	 0.9998586, -0.0139713,  0.0093613, 0,
	 0.0140148,  0.9998912, -0.0045991, 0,
	-0.0092961,  0.0047296,  0.9999456, 0
}

function shade_lst(lst,m) 
	local ret = {}
	local pos = 1
	for i,pt in ipairs(lst) do
		local v = mvmul(m,pt)
		ret[i]=v
	end
	
	return ret
end

function getpoly(lst,inds) 
	local ret = {}
	for i,v in ipairs(inds) do
		ret[i]=lst[v]
	end
	
	return ret
end
-->8
-- shapes

-- cube
cube_verts = {
	{-1,-1,-1}, -- 1: lt,back,bot
	{-1,-1, 1}, -- 2: lt,back,top
	{-1, 1,-1}, -- 3: lt,front,bot
	{-1, 1, 1}, -- 4: lt,front,top
	{ 1,-1,-1}, -- 5: rt,back,bot
	{ 1,-1, 1}, -- 6: rt,back,top
	{ 1, 1,-1}, -- 7: rt,front,bot
	{ 1, 1, 1}  -- 8: rt,front,top
}

cube = {
	{5,1,3,7}, --bottom face
	{2,6,8,4}, --top face
	{4,8,7,3}, --front face
	{8,6,5,7}, --right face
	{6,2,1,5}, --back face
	{2,4,3,1}  --left face
}

cube_cols = {
	{11,3}, -- green
	{14,2}, -- pink/purple
	{9,4},  -- orange/brown
	{12,1}, -- blue
	{7,6},  -- white
	{10,9}  -- yellow/orange
}

-- cylinder
cyl_n = 24
cyl_a = 1/cyl_n

cyl_verts = {}
cyl_cols = {}
cyl = {}

for ang = 0,1-cyl_a/2,cyl_a do
	add(
		cyl_verts,
		{cos(ang),-sin(ang),1}
	)
	add(
		cyl_verts,
		{cos(ang),-sin(ang),-1}
	)
end

cyl_top = {}
cyl_bot = {}
for i = 1,cyl_n do
	add(cyl_top,2*i-1)
	add(cyl_bot,2*(cyl_n-i+1))
end

add(cyl, cyl_top)
add(cyl, cyl_bot)

for i = 1,cyl_n-1 do
	add(cyl, {
		2*i, 2*i + 2,
		2*i + 1, 2*i - 1
	})
end


add(cyl, {
	2*cyl_n, 2,
	1, 2*cyl_n - 1
})

for i = 1,2*(cyl_n+1) do
	add(cyl_cols, {12,1})
end

-- icosahedron

h = 0.618034

-- too difficult to explain in a
-- comment. just look at the
-- wikipedia page.
icos_verts = {
	{-h, 0, 1}, -- 1
	{ h, 0, 1}, -- 2
	{ h, 0,-1}, -- 3
	{-h, 0,-1}, -- 4
	{ 0,-1, h}, -- 5
	{ 0, 1, h}, -- 6
	{ 0, 1,-h}, -- 7
	{ 0,-1,-h}, -- 8
	{-1, h, 0}, -- 9
	{ 1, h, 0}, -- 10
	{ 1,-h, 0}, -- 11
	{-1,-h, 0}  -- 12
}

icos = {
	{5,2,1},
	{5,1,12},
	{5,12,8},
	{5,8,11},
	{5,11,2},
	
	{1,2,6},
	{12,1,9},
	{8,12,4},
	{11,8,3},
	{2,11,10},
	
	{1,6,9},
	{12,9,4},
	{8,4,3},
	{11,3,10},
	{2,10,6},

	{7,9,6},
	{7,4,9},
	{7,3,4},
	{7,10,3},
	{7,6,10}
}

icos_cols = {}
for i = 1,#icos do
	add(icos_cols,{7,1})
end

-- sphere

sphere_m = 8
sphere_n = 16
sphere_verts = {}
sphere_cols = {}
sphere = {}

-- top and bottom caps
add(sphere_verts,{0,0,1})
add(sphere_verts,{0,0,-1})

-- rings
dphi = 1/sphere_n
dtha = 0.5/sphere_m
for tha = dtha,(1-dtha)/2,dtha do
	local s = sin(tha - 0.25)
	local c = cos(0.25 - tha)
	for phi = 0,1-dphi/2,dphi do
		local x = c*cos(phi)
		local y = -c*sin(phi)
		add(sphere_verts,{
			x,y,s
		})
	end
end

sphere = {}
for i = 0,sphere_n-2 do
	add(sphere, {
		3+i, 3+i+1, 1
	})
	
	for j = 1,sphere_m-2 do
		add(sphere, {
			3+j*sphere_n+i,
			3+j*sphere_n+i+1,
			3+(j-1)*sphere_n+i+1,
			3+(j-1)*sphere_n+i,
		})
	end
	
	add(sphere, {
		4+(sphere_m-2)*sphere_n+i,
		3+(sphere_m-2)*sphere_n+i,
		2
	})
end

add(sphere, {
	2+sphere_n, 3, 1
})
for j = 1,sphere_m-2 do
	add(sphere, {
		2+(j+1)*sphere_n,
		3+j*sphere_n,
		3+(j-1)*sphere_n,
		2+j*sphere_n,
	})
end
add(sphere, {
	3+(sphere_m-2)*sphere_n,
	2+(sphere_m-1)*sphere_n,
	2
})

for i = 1,#sphere do
	add(sphere_cols,{11,3})
end


-- square chain link

h = 0.5
link_verts = {
	{ 1, 1, h},
	{-1, 1, h},
	{-1,-1, h},
	{ 1,-1, h},
	
	{ h, h, h},
	{-h, h, h},
	{-h,-h, h},
	{ h,-h, h},
	
	{ 1, 1,-h},
	{-1, 1,-h},
	{-1,-1,-h},
	{ 1,-1,-h},
	
	{ h, h,-h},
	{-h, h,-h},
	{-h,-h,-h},
	{ h,-h,-h},
}

link = {
	{1,5,8,4},
	{2,6,5,1},
	{3,7,6,2},
	{4,8,7,3},
	
	{9,12,16,13},
	{12,11,15,16},
	{11,10,14,15},
	{10,9,13,14},
	
	{2,1,9,10},
	{1,4,12,9},
	{4,3,11,12},
	{3,2,10,11},
	
	{5,6,14,13},
	{6,7,15,14},
	{7,8,16,15},
	{8,5,13,16}
}

link_cols = {}
for i = 1,#link do
	add(link_cols,{14,2})
end

-- globals

all_verts = {
	cube_verts,
	cyl_verts,
	icos_verts,
	sphere_verts,
	link_verts
}
all_cols = {
	cube_cols,
	cyl_cols,
	icos_cols,
	sphere_cols,
	link_cols
}
all_shapes = {
	cube,
	cyl,
	icos,
	sphere,
	link
}
-->8
--sbuf

-- assumes segments do not pass
-- through each other

sbuf = {}

function sbuf_clr()
	for i = 0,127 do
		sbuf[i] = {}
	end
end

-- take seg from l->r and chop
-- to l->newr
function seg_chopr(sg, newr)
	local dx = newr-sg.rx
	local dz = dx*sg.gradz
	sg.rx = newr
	sg.rz += dz
end

-- take seg from l->r and chop
-- to newl->r
function seg_chopl(sg, newl)
	local dx = newl-sg.lx
	local dz = dx*sg.gradz
	sg.lx = newl
	sg.lz += dz
end

function seg_cpy(sg)
	return {
		lx = sg.lx, lz = sg.lz,
		rx = sg.rx, rz = sg.rz,
		gradz = sg.gradz,
		b = sg.b, c = sg.c
	}
end

function sbuf_add(y,seg)
	local lx = seg.lx
	local rx = seg.rx
		
	local orig = sbuf[y]
	
	-- this function constructs a
	-- replacement to the original
	-- array of segments
	local repl = {}
	local i = 1
	local n = #orig
	
	-- copy all segments that are
	-- completely left of the new
	-- segment
	while (i <= n) do
		if (orig[i].rx >= lx) break
		repl[i]=orig[i]
		i += 1
	end
	
	local pos = i
	
	-- now do all the old segments
	-- that have an x-conflict with
	-- the new segment
	while (i <= n) do
		local o = orig[i]
		
		if (o.lx > rx) break
		
		if (seg == nil) break
		
		-- check if new seg is behind
		-- (or in front) of orig[i]
		
		-- must be a better way...
		local d = 0
		local e = 0
		if (lx < o.lx) then
			d =	seg.lz+(o.lx-lx)*seg.gradz
			e = o.lz
		elseif (rx > o.rx) then
			d = seg.lz+(o.rx-lx)*seg.gradz
			e = o.rz
		else
			d = -(o.lz+(lx-o.lx)*o.gradz)
			e = -seg.lz
		end
				
		if (d >= e) then
			-- old is in front of new
			if (seg.lx < o.lx) then
				local c = seg_cpy(seg)
				seg_chopr(c, o.lx-1)
				repl[pos]=c
				pos=pos+1
			end
			repl[pos]=o -- keep old
			pos=pos+1
			seg_chopl(seg,o.rx+1)
			if (seg.lx>seg.rx) then
				seg = nil
			end
		else
			-- new is in front of old
			local c = seg_cpy(o)
			if (o.lx < seg.lx) then
				seg_chopr(o, seg.lx-1)
				repl[pos]=o
				pos=pos+1
			end
			
			if (c.rx > seg.rx) then
				repl[pos]=seg
				pos=pos+1
				seg_chopl(c, seg.rx+1)
				seg = nil
				repl[pos]=c
				pos=pos+1
				i=i+1
				break
			end
		end
		
		i += 1
	end	
	
	-- add remaining portion (if
	-- any) of seg
	if (seg) then
		repl[pos]=seg
		pos=pos+1
	end
	
	-- now do all segments that are
	-- completely to the right of
	-- the new segment
	
	while (i <= n) do
		repl[pos]=orig[i]
		pos=pos+1
		i += 1
	end
	
	sbuf[y] = repl
end

-- reads scanned poly in lts,
-- rts, miny, maxy
function poly2sbuf(b,c)
	if (miny < 0) miny = 0
	if (maxy > 127) maxy = 127
	
	for y = miny,maxy do

		-- some helper vars
		local lx = lts[y]+1
		local lz = zlts[y]
		local rx = rts[y]
		local rz = zrts[y]
		
		-- reject anything invisible
		if (rx < 0 or lx > 127) goto skip
		if (lx > rx) then
			goto skip
		end
		
		local dx = rx-lx
		local dz = rz-lz
		-- need to check for degenerate
		-- case when dx = 0. ugly.
		-- if dx is 0, then this seg
		-- is only a single pixel; it 
		-- makes sense to say gradz=0
		local gradz = 0
		if (dx != 0) gradz = dz / dx
	
		-- make new segment struct
		local seg = {
			lx = lx, lz = lz,
			rx = rx, rz = rz,
			gradz = gradz,
			b = b, c = c
		}
		sbuf_add(y,seg)
		::skip::
	end
end

function draw_sbuf()
	for y = 0,127 do
		for s in all(sbuf[y]) do
			fillp(s.b)
			line(s.lx,y,s.rx,y,s.c)
		end
	end
end
-->8
-- fox

-- from:
-- https://opengameart.org/content/5-low-poly-animals
-- (i used regex find-replace
-- to generate this lua code)

-- this ruins the framerate,
-- plus, all those small polys
-- highlihgt a lot of bugs in
-- the rendering. but it kinda
-- works!

fox_verts = {
 {-0.012287, 0.574287, 1.539076},
 {-0.011645, 0.500682, 0.261516},
 {-0.325263, 0.390364, 0.270270},
 {-0.358212, 0.456498, 1.539535},
 {0.333524, 0.461858, 1.529494},
 {0.000365, 0.605710, -0.628508},
 {-0.364376, 0.318427, 2.053243},
 {-0.011816, 0.510833, 2.053957},
 {-0.519215, 0.101453, 0.289757},
 {0.325914, 0.328601, 2.046678},
 {0.301897, 0.390995, 0.276543},
 {-0.292532, 0.550028, -0.632545},
 {0.293263, 0.549979, -0.625276},
 {-0.572122, 0.152999, 1.523370},
 {-0.572830, -0.105012, 2.037537},
 {-0.553059, -0.370689, 1.976562},
 {-0.339655, -0.685356, 1.883794},
 {-0.011773, -0.753726, 1.876101},
 {0.337812, -0.689755, 1.876950},
 {0.549751, -0.362029, 1.982364},
 {0.549199, -0.101046, 2.040785},
 {0.547423, 0.161484, 1.513517},
 {0.003838, 0.628402, -0.908376},
 {0.303748, 0.570980, -0.892816},
 {-0.550088, -0.259951, 1.454336},
 {-0.337631, -0.540930, 1.391744},
 {-0.011819, -0.633418, 1.382112},
 {0.334403, -0.537286, 1.396247},
 {0.546352, -0.221620, 1.447713},
 {-0.520004, -0.480273, 0.278991},
 {-0.473611, 0.251563, -0.635606},
 {0.495581, 0.094332, 0.311057},
 {0.474175, 0.252318, -0.620581},
 {-0.296378, 0.571039, -0.900256},
 {0.780710, 0.691578, -0.901174},
 {-0.326013, -0.542136, 0.641573},
 {-0.012715, -0.617796, 0.778640},
 {0.300551, -0.590920, 0.647770},
 {0.392565, -0.594413, 0.248588},
 {-0.475434, -0.142918, -0.616163},
 {-0.772959, 0.691721, -0.920435},
 {0.005952, 0.471692, -1.081036},
 {0.154857, 0.423606, -1.073464},
 {0.488798, 0.267588, -0.860688},
 {-0.294075, -0.235498, -0.623213},
 {0.472623, -0.136539, -0.586228},
 {-0.482227, 0.267672, -0.872731},
 {-0.143105, 0.423636, -1.077158},
 {0.354273, 0.297735, -1.056002},
 {-0.000991, -0.328754, -0.620359},
 {0.291658, -0.224841, -0.596473},
 {0.487599, 0.018725, -0.802312},
 {-0.483312, 0.012967, -0.825718},
 {0.006879, 0.325997, -1.156865},
 {-0.108102, 0.288928, -1.153874},
 {0.121743, 0.288904, -1.151024},
 {0.275570, 0.191809, -1.137554},
 {0.315663, -0.165768, -1.001271},
 {-0.298551, -0.235600, -0.794074},
 {0.301597, -0.229821, -0.777332},
 {-0.342403, 0.297805, -1.064638},
 {-0.261839, 0.191863, -1.144216},
 {0.008321, 0.086292, -1.236222},
 {0.080254, 0.063250, -1.231259},
 {0.245787, -0.165733, -1.095335},
 {0.218009, 0.012140, -1.219837},
 {0.001964, -0.341428, -0.785004},
 {0.137568, -0.277922, -0.990118},
 {-0.305289, -0.165705, -1.008969},
 {-0.233209, -0.165684, -1.101273},
 {-0.063719, 0.063265, -1.233044},
 {0.108406, -0.252247, -1.086731},
 {0.155908, -0.201161, -1.196280},
 {-0.128007, -0.277895, -0.993410},
 {0.004713, -0.320754, -0.986660},
 {-0.096455, -0.252226, -1.089271},
 {-0.209883, 0.012184, -1.225142},
 {0.008774, -0.007029, -1.306206},
 {-0.039357, -0.022414, -1.304083},
 {0.056834, -0.022424, -1.302890},
 {0.143983, -0.062725, -1.294688},
 {0.005923, -0.285287, -1.084065},
 {0.058201, -0.234616, -1.190893},
 {0.135976, -0.204844, -1.272863},
 {-0.146887, -0.201130, -1.200034},
 {0.010255, -0.079524, -1.431820},
 {-0.027628, -0.091633, -1.430148},
 {0.048082, -0.091641, -1.429210},
 {0.007223, -0.250911, -1.188644},
 {0.053581, -0.242849, -1.267166},
 {-0.043680, -0.234606, -1.192156},
 {-0.132765, -0.062697, -1.298119},
 {0.011876, -0.128886, -1.562995},
 {-0.016046, -0.137811, -1.561764},
 {0.125669, -0.123361, -1.422644},
 {0.039758, -0.137817, -1.561072},
 {0.125428, -0.217177, -1.403915},
 {0.008171, -0.257364, -1.265163},
 {0.047695, -0.248881, -1.399275},
 {-0.125124, -0.204817, -1.276100},
 {-0.111091, -0.123337, -1.425579},
 {0.012443, -0.172224, -1.609091},
 {-0.002089, -0.176869, -1.608449},
 {0.111212, -0.161198, -1.556054},
 {0.026954, -0.176872, -1.608090},
 {-0.037172, -0.242840, -1.268291},
 {0.009813, -0.260991, -1.397603},
 {-0.093339, -0.161178, -1.558590},
 {0.111034, -0.238914, -1.542321},
 {0.058414, -0.189040, -1.605549},
 {0.039472, -0.262281, -1.539076},
 {-0.028015, -0.248874, -1.400213},
 {0.011550, -0.271206, -1.537845},
 {-0.111332, -0.217153, -1.406850},
 {-0.093517, -0.238893, -1.544857},
 {-0.034855, -0.189031, -1.606706},
 {0.058321, -0.229487, -1.598402},
 {-0.016331, -0.262275, -1.539768},
 {0.012274, -0.246294, -1.596002},
 {0.026806, -0.241649, -1.596643},
 {-0.034947, -0.229477, -1.599558},
 {-0.002237, -0.241646, -1.597003},
 {-0.365744, -0.420088, 1.971418},
 {0.326581, -0.372234, 1.979419},
 {-0.388742, 0.104448, 2.662778},
 {-0.011822, 0.180564, 2.700572},
 {0.366002, 0.104448, 2.662778},
 {-0.389167, -0.648948, 2.341946},
 {0.366082, -0.630198, 2.349994},
 {-0.368590, -0.332575, 3.208502},
 {-0.011272, -0.255601, 3.250579},
 {0.345944, -0.333167, 3.208737},
 {-0.368957, -0.880978, 2.942539},
 {0.345577, -0.881570, 2.942774},
 {-0.198146, -0.708357, 3.519961},
 {-0.011710, -0.668194, 3.541915},
 {0.174674, -0.708666, 3.520083},
 {-0.198338, -0.994495, 3.381190},
 {0.174483, -0.994804, 3.381312},
 {-0.077081, -0.886398, 3.628628},
 {-0.011910, -0.872358, 3.636303},
 {0.053243, -0.886506, 3.628670},
 {-0.077148, -0.986421, 3.580119},
 {0.053176, -0.986529, 3.580161},
 {-0.011983, -0.949823, 3.664337},
 {-0.019245, -0.415755, 1.971978},
 {-0.011370, -0.604739, 2.360786},
 {-0.011690, -0.881274, 2.942657},
 {-0.011928, -0.994649, 3.381251},
 {-0.011986, -0.986475, 3.580140},
 {-0.483276, -0.588866, 0.155237},
 {-0.252989, -0.620621, 0.122154},
 {0.190090, -0.636465, 0.173712},
 {-0.010923, -0.575259, 0.151583},
 {-0.010139, -0.503700, 0.002581},
 {-0.475589, -0.463913, -0.060641},
 {-0.250228, -0.514018, -0.096456},
 {0.187329, -0.491326, -0.041080},
 {0.423487, -0.445822, 0.010859},
 {-0.480890, -0.833600, -0.111647},
 {-0.485681, -0.912468, 0.054177},
 {-0.283140, -0.944793, 0.039831},
 {-0.288870, -0.923827, -0.147280},
 {-0.426800, -1.554636, -0.047619},
 {-0.420109, -1.440021, 0.052224},
 {-0.263090, -1.443686, 0.037251},
 {-0.270662, -1.564658, -0.054813},
 {-0.424559, -1.609918, 0.027031},
 {-0.422888, -1.519086, 0.066644},
 {-0.265954, -1.522404, 0.050748},
 {-0.268478, -1.620056, 0.019282},
 {-0.294427, -1.680334, -0.071684},
 {-0.413190, -1.673147, -0.067608},
 {-0.292332, -1.712850, -0.009184},
 {-0.411095, -1.705663, -0.005107},
 {-0.312728, -1.721951, -0.068398},
 {-0.392157, -1.717144, -0.065672},
 {-0.311327, -1.743698, -0.026598},
 {-0.390756, -1.738891, -0.023872},
 {0.427826, -0.817228, -0.104921},
 {0.436143, -0.938964, 0.046685},
 {0.230118, -0.971503, 0.026765},
 {0.226697, -0.888627, -0.153876},
 {0.361551, -1.480873, -0.295770},
 {0.361758, -1.431538, -0.132705},
 {0.196420, -1.431356, -0.139339},
 {0.197664, -1.493074, -0.297563},
 {0.364696, -1.566881, -0.249945},
 {0.364819, -1.519626, -0.150651},
 {0.199480, -1.519361, -0.158062},
 {0.200811, -1.578973, -0.251339},
 {0.222000, -1.589122, -0.366604},
 {0.346550, -1.579984, -0.365593},
 {0.224411, -1.653436, -0.330201},
 {0.348960, -1.644297, -0.329190},
 {0.241624, -1.626812, -0.388533},
 {0.324923, -1.620700, -0.387856},
 {0.243236, -1.669825, -0.364187},
 {0.326535, -1.663713, -0.363510},
 {0.521834, -0.673909, 1.803373},
 {0.365761, -0.723344, 1.767063},
 {0.508766, -0.505728, 1.409415},
 {0.357141, -0.575724, 1.367136},
 {0.467917, -0.945915, 1.374269},
 {0.486228, -1.006054, 1.563417},
 {0.323559, -1.053592, 1.569033},
 {0.307976, -1.025527, 1.348000},
 {0.420484, -1.382602, 1.736869},
 {0.429341, -1.245100, 1.789453},
 {0.279392, -1.242700, 1.794601},
 {0.271972, -1.388150, 1.743580},
 {0.416248, -1.536674, 1.745596},
 {0.430738, -1.344842, 1.812255},
 {0.280829, -1.341476, 1.815003},
 {0.267741, -1.541805, 1.752251},
 {0.281611, -1.594959, 1.647016},
 {0.417675, -1.592271, 1.640382},
 {0.282495, -1.668405, 1.680367},
 {0.418559, -1.665717, 1.673733},
 {0.299177, -1.634866, 1.618374},
 {0.390176, -1.633068, 1.613937},
 {0.299768, -1.683987, 1.640679},
 {0.390768, -1.682189, 1.636242},
 {-0.523941, -0.669092, 1.809193},
 {-0.366992, -0.721311, 1.781252},
 {-0.512020, -0.511971, 1.400749},
 {-0.360648, -0.578445, 1.368470},
 {-0.472071, -0.943674, 1.395893},
 {-0.483044, -1.036001, 1.592825},
 {-0.320959, -1.085846, 1.571257},
 {-0.315114, -1.008322, 1.365013},
 {-0.413751, -1.465646, 1.628679},
 {-0.417597, -1.341037, 1.707604},
 {-0.267375, -1.340698, 1.706070},
 {-0.265081, -1.470828, 1.626031},
 {-0.407867, -1.620748, 1.643348},
 {-0.419333, -1.435407, 1.703161},
 {-0.269564, -1.431825, 1.696324},
 {-0.259205, -1.624968, 1.640770},
 {-0.279330, -1.682109, 1.538681},
 {-0.415556, -1.680274, 1.540583},
 {-0.277607, -1.754250, 1.574738},
 {-0.413834, -1.752415, 1.576640},
 {-0.298397, -1.723144, 1.512718},
 {-0.389505, -1.721917, 1.513990},
 {-0.297245, -1.771392, 1.536833},
 {-0.388353, -1.770164, 1.538105},
}
fox = {
 {2,3,4,1},
 {1,5,11,2},
 {2,6,12,3},
 {1,4,7,8},
 {3,9,14,4},
 {5,1,8,10},
 {6,2,11,13},
 {4,14,15,7},
 {7,15,16,17,123},
 {3,12,31,9},
 {22,5,10,21},
 {5,22,32,11},
 {6,23,34,12},
 {13,24,23,6},
 {14,25,16,15},
 {26,27,18,17},
 {27,28,19,18},
 {29,22,21,20},
 {14,9,30,25},
 {13,11,32,33},
 {24,13,35},
 {26,36,37,27},
 {28,27,37,38},
 {29,39,32,22},
 {30,9,31,40,156,151},
 {30,36,26,25},
 {31,12,41},
 {13,33,35},
 {12,34,41},
 {23,42,48,34},
 {24,43,42,23},
 {44,24,35},
 {38,39,29,28},
 {30,151,152,36},
 {31,47,53,40},
 {47,31,41},
 {33,44,35},
 {34,47,41},
 {43,24,44,49},
 {46,52,44,33},
 {34,48,61,47},
 {48,42,54,55},
 {42,43,56,54},
 {43,49,57,56},
 {49,44,52,58},
 {40,53,59,45},
 {51,60,52,46},
 {47,61,69,53},
 {61,48,55,62},
 {54,63,71,55},
 {56,64,63,54},
 {49,58,65,57},
 {57,66,64,56},
 {52,60,58},
 {69,61,62,70},
 {55,71,77,62},
 {57,65,66},
 {71,63,78,79},
 {63,64,80,78},
 {66,81,80,64},
 {71,79,92,77},
 {79,78,86,87},
 {78,80,88,86},
 {79,87,101,92},
 {87,86,93,94},
 {81,95,88,80},
 {86,88,96,93},
 {87,94,108,101},
 {94,93,102,103},
 {95,104,96,88},
 {93,96,105,102},
 {94,103,116,108},
 {105,96,104,110},
 {124,146,123,17,18,19},
 {10,124,19,20,21},
 {10,8,126,127},
 {147,129,134,148},
 {146,124,129,147},
 {8,7,125,126},
 {7,123,128,125},
 {124,10,127,129},
 {125,128,133,130},
 {126,125,130,131},
 {129,127,132,134},
 {127,126,131,132},
 {123,146,147,128},
 {128,147,148,133},
 {62,77,70},
 {53,69,59},
 {152,151,161,162},
 {156,157,163,160},
 {158,51,46,159},
 {156,40,45,157},
 {161,160,164,165},
 {151,156,160,161},
 {157,152,162,163},
 {167,166,170,171},
 {160,163,167,164},
 {163,162,166,167},
 {162,161,165,166},
 {169,168,171,170},
 {165,164,168,169},
 {167,171,174,172},
 {166,165,169,170},
 {172,174,178,176},
 {171,168,175,174},
 {164,167,172,173},
 {168,164,173,175},
 {177,176,178,179},
 {173,172,176,177},
 {175,173,177,179},
 {174,175,179,178},
 {38,153,39},
 {181,185,184,180},
 {158,183,182,153},
 {187,191,190,186},
 {180,184,187,183},
 {183,187,186,182},
 {182,186,185,181},
 {189,190,191,188},
 {185,189,188,184},
 {187,192,194,191},
 {186,190,189,185},
 {192,196,198,194},
 {191,194,195,188},
 {184,193,192,187},
 {188,195,193,184},
 {197,199,198,196},
 {193,197,196,192},
 {195,199,197,193},
 {194,198,199,195},
 {32,39,159,46,33},
 {159,180,183,158},
 {39,181,180,159},
 {153,182,181,39},
 {201,206,205,200},
 {202,204,207,203},
 {205,209,208,204},
 {200,205,204,202},
 {203,207,206,201},
 {211,215,214,210},
 {204,208,211,207},
 {207,211,210,206},
 {206,210,209,205},
 {213,214,215,212},
 {209,213,212,208},
 {211,216,218,215},
 {210,214,213,209},
 {216,220,222,218},
 {215,218,219,212},
 {208,217,216,211},
 {212,219,217,208},
 {221,223,222,220},
 {217,221,220,216},
 {219,223,221,217},
 {218,222,223,219},
 {201,19,28,203},
 {203,28,29,202},
 {202,29,20,200},
 {200,20,19,201},
 {225,224,229,230},
 {226,227,231,228},
 {229,228,232,233},
 {224,226,228,229},
 {227,225,230,231},
 {235,234,238,239},
 {228,231,235,232},
 {231,230,234,235},
 {230,229,233,234},
 {237,236,239,238},
 {233,232,236,237},
 {235,239,242,240},
 {234,233,237,238},
 {240,242,246,244},
 {239,236,243,242},
 {232,235,240,241},
 {236,232,241,243},
 {245,244,246,247},
 {241,240,244,245},
 {243,241,245,247},
 {242,243,247,246},
 {225,227,26,17},
 {226,224,16,25},
 {227,226,25,26},
 {224,225,17,16},
 {36,152,154,37},
 {37,154,153,38},
 {45,59,67,50},
 {50,67,60,51},
 {58,68,65},
 {67,59,74,75},
 {69,74,59},
 {60,67,75,68},
 {76,74,70},
 {77,85,70},
 {68,75,82,72},
 {72,83,73,65},
 {73,84,81,66},
 {75,74,76,82},
 {70,85,91,76},
 {82,89,83,72},
 {83,90,84,73},
 {76,91,89,82},
 {77,92,100,85},
 {84,97,95,81},
 {83,89,98,90},
 {90,99,97,84},
 {85,100,106,91},
 {89,91,106,98},
 {90,98,107,99},
 {92,101,114,100},
 {95,97,109,104},
 {99,111,109,97},
 {98,106,112,107},
 {99,107,113,111},
 {100,114,112,106},
 {114,101,108,115},
 {104,109,117,110},
 {107,112,118,113},
 {111,113,119,120},
 {114,115,118,112},
 {115,108,116,121},
 {116,103,102,105,110,117,120,119,122,121},
 {111,120,117,109},
 {113,118,122,119},
 {115,121,122,118},
 {134,132,137,139},
 {149,139,144,150},
 {132,131,136,137},
 {148,134,139,149},
 {130,133,138,135},
 {131,130,135,136},
 {135,138,143,140},
 {136,135,140,141},
 {139,137,142,144},
 {137,136,141,142},
 {144,142,145},
 {142,141,145},
 {143,150,144,145},
 {140,143,145},
 {141,140,145},
 {133,148,149,138},
 {138,149,150,143},
 {74,69,70},
 {65,73,66},
 {68,72,65},
 {60,68,58},
 {154,155,158,153},
 {152,157,155,154},
 {157,45,50,155},
 {155,50,51,158},
}

fox_cols = {}

for i = 1,#fox do
	if (i < 186) then
		add(fox_cols,{9,4})
	else
		add(fox_cols,{7,6})
	end
end

add(all_verts,fox_verts)
add(all_cols,fox_cols)
add(all_shapes,fox)