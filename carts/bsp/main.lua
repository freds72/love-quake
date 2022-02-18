local ffi=require 'ffi'
local nfs = require( "nativefs" )

ffi.cdef[[
#pragma pack(1)

typedef float dvertex_t[3];

typedef short dvertexshort_t[3];

typedef struct
{
	int		fileofs, filelen;
} lump_t;

typedef struct
{
  int	   version;	
  lump_t entities;
  lump_t planes;
  lump_t textures;
  lump_t vertices;
  lump_t visibility;
  lump_t nodes;
  lump_t texinfo;
  lump_t faces;
  lump_t lighting;
  lump_t clipnodes;
  lump_t leaves;
  lump_t marksurfaces;
  lump_t edges;
  lump_t surfedges;
  lump_t models;
} dheader_t;

typedef struct
{
	dvertex_t	mins, maxs;
	float		origin[3];
	int			headnode[4];
	int			visleafs;		// not including the solid leaf 0
	int			firstface, numfaces;
} dmodel_t;

typedef struct
{
	int			nummiptex;
	int			dataofs[4];		// [nummiptex]
} dmiptexlump_t;

static const int MIPLEVELS	= 4;
typedef struct miptex_s
{
	char		name[16];
	unsigned	width, height;
	unsigned	offsets[MIPLEVELS];		// four mip maps stored
} miptex_t;

typedef struct
{
	dvertex_t	normal;
	float	dist;
	int		type;		// PLANE_X - PLANE_ANYZ ?remove? trivial to regenerate
} dplane_t;

typedef struct
{
	int			planenum;
	short		children[2];	// negative numbers are -(leafs+1), not nodes
	dvertexshort_t		mins;		// for sphere culling
	dvertexshort_t		maxs;
	unsigned short	firstface;
	unsigned short	numfaces;	// counting both sides
} dnode_t;

typedef struct
{
	int			planenum;
	short		children[2];	// negative numbers are contents
} dclipnode_t;

typedef struct texinfo_s
{
	float		vecs[2][4];		// [s/t][xyz offset]
	int			miptex;
	int			flags;
} texinfo_t;

typedef struct
{
	unsigned short	v[2];		// vertex numbers
} dedge_t;

static const int	MAXLIGHTMAPS = 4;
typedef struct
{
	short		planenum;
	short		side;

	int			firstedge;		// we must support > 64k edges
	short		numedges;	
	short		texinfo;

	unsigned char		styles[MAXLIGHTMAPS];  // lighting info
	int			          lightofs;		// start of [numstyles*surfsize] samples
} dface_t;

// #define	AMBIENT_WATER	0
// #define	AMBIENT_SKY		1
// #define	AMBIENT_SLIME	2
// #define	AMBIENT_LAVA	3

static const int NUM_AMBIENTS = 4;

// leaf 0 is the generic CONTENTS_SOLID leaf, used for all solid areas
// all other leafs need visibility info
typedef struct
{
	int			contents;
	int			visofs;				// -1 = no visibility info

	dvertexshort_t		mins;			// for frustum culling
	dvertexshort_t		maxs;

	unsigned short		firstmarksurface;
	unsigned short		nummarksurfaces;

	unsigned char		  ambient_level[NUM_AMBIENTS];
} dleaf_t;
]]

-- pico8 compat helpers
local add=table.insert
local flr=math.floor
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local sin,cos=math.sin,math.cos

function printh(...)
    print(...)
end

function print_vector(v)
  printh(v[0].." "..v[1].." "..v[2])
end

-- reads the given struct name from the byte array
function read_all(cname, lump, mem)
    local res = {}
    local sz,ct = ffi.sizeof(cname), ffi.typeof(cname.."*")
    local n = lump.filelen / sz
    mem = mem + lump.fileofs
    for i=0,n-1 do
        res[i] = ffi.cast(ct, mem)
        mem = mem + sz
    end
    --return ffi.cast(cname.."["..n.."]", mem)
    return res
end

function read_textures(lump, mem)
  mem = mem + lump.fileofs
  local textures = {}
  local m = ffi.cast("dmiptexlump_t*", mem)
  local n = m.nummiptex
  print("reading #textures: "..n)
  for i=0,n-1 do
    local ofs = m.dataofs[i]
    if ofs~=-1 then
      local mt = ffi.cast("miptex_t*", mem + ofs)
      print("texture: "..ffi.string(mt.name).." size: "..mt.width.."x"..mt.height)
      local offsets={}
      -- test(?)
      local imgs={}
      for j=0,3 do
        offsets[j] = mem + ofs + mt.offsets[j]
        print("offset: "..mt.offsets[j])

        local data = ffi.cast("unsigned char*", offsets[j])
      
        local scale=shl(1,j)
        local w,h=flr(mt.width/scale), flr(mt.height/scale)
        local imagedata = love.image.newImageData(w,h)
        local image     = love.graphics.newImage(imagedata,{linear=true, mipmaps=false})
        image:setFilter('nearest','nearest')        
        imagedata:mapPixel(
          function(x, y, r, g, b, a)                   
            local idx = data[x + y*w]/255
            return idx,idx,idx,1 
        end)
        image:replacePixels(imagedata)
        add(imgs, image)
      end
      add(textures, {
        width = mt.width,
        height = mt.height,
        offsets = offsets,
        imgs = imgs
      })
    end
  end
  return textures
end

-- game globals
local plane_dot,plane_isfront,plane_get


function love.load(args)

    hw = love.graphics.getWidth( )/2
    hh = love.graphics.getWidth( )/2

    print("INFO - game root: "..args[1])
    -- dump to bytes
    local data = nfs.newFileData(args[1].."/maps/"..args[2])

    local mem = data:getFFIPointer()
    local header = ffi.cast('dheader_t*', mem)
    print("version:"..header.version)

    local src = ffi.cast("unsigned char*",mem)

    local bsp={
        models = read_all("dmodel_t", header.models, src),
        vertices = read_all("dvertex_t", header.vertices, src)[0],
        visdata = read_all("unsigned char", header.visibility, src)[0],
        -- lightmaps = read_bytes(bsp_handle, header.lightmaps)
        nodes = read_all("dnode_t", header.nodes, src),
        clipnodes = read_all("dclipnode_t", header.clipnodes, src),
        faces = read_all("dface_t", header.faces, src),
        texinfo = read_all("texinfo_t", header.texinfo, src),
        textures = read_textures(header.textures, src),
        planes = read_all("dplane_t", header.planes, src),
        leaves = read_all("dleaf_t", header.leaves, src),
        edges = read_all("dedge_t", header.edges, src),
        marksurfaces = read_all("unsigned short", header.marksurfaces, src)[0],
        surfedges = read_all("int", header.surfedges, src)[0],
    }

    -- convert to flat array
    models=unpack_map(bsp)  
    models.data = data  
    models.raw = bsp
    models.src = src
end

function find_sub_sector(node,pos)
  while node do
    node=node[plane_isfront(node.plane,pos)]
    if node and node.contents then
      -- leaf?
      return node
    end
  end
end

function v_lerp(a,b,t,uv)
  local ax,ay,az,u,v=a[1],a[2],a[3],a.u,a.v
	return {
    ax+(b[1]-ax)*t,
    ay+(b[2]-ay)*t,
    az+(b[3]-az)*t,
    u=uv and u+(b.u-u)*t,
    v=uv and v+(b.v-v)*t
  }
end

function z_poly_clip(v,nv,uvs)
	local res,v0={},v[nv]
	local d0=v0[3]-8
	for i=1,nv do
    local side=d0>0
    if side then
      res[#res+1]=v0
    end
		local v1=v[i]
		local d1=v1[3]-8
    -- not same sign?
		if (d1>0)~=side then
      local nv=v_lerp(v0,v1,d0/(d0-d1),uvs)
      -- project against near plane
      nv.x=hw+(nv[1]*16)
      nv.y=hh-(nv[2]*16)
      nv.w=16
      res[#res+1]=nv
    end
    v0=v1
		d0=d1
	end
	return res,#res
end

mx,my=0,0
diffx,diffy=0,0
camx,camy=0,0
function love.mousepressed(mx, my, b)
  if b == 1 then
      diffx = mx - camx
      diffy = my - camy
  end
end

zoom=1
angle=0
texture=1
function love.wheelmoved(x, y)
  if love.mouse.isDown(1) then
    if y > 0 then
      angle = angle + 0.1
    elseif y < 0 then
      angle = angle - 0.1
    end
  else
    if y>0 then
      texture = min(texture + 1, #models.raw.textures)
    else
      texture = max(texture -1, 1)
    end
    -- if y > 0 then
    --   zoom = zoom + 5
    -- elseif y < 0 then
    --   zoom = zoom - 5
    -- end
  end
end

function love.update(dt)
  if love.mouse.isDown(1) then
      mx, my = love.mouse.getPosition()
      camx = mx - diffx
      camy = my - diffy
  end
  
end

local visframe,prev_leaf=0
function love.draw()
  love.graphics.clear()
  love.graphics.setLineJoin("none") 
  --love.graphics.setLineWidth(2)  

  local pos={[0]=camx,camy,zoom}
  local current_leaf = find_sub_sector(models[1].bsp,pos)

  local collect_leaves=function(leaves)
    -- changed sector?
    if current_leaf and current_leaf~=prev_leaf then
      prev_leaf = current_leaf
      visframe = visframe + 1
      -- find all (potentially) visible leaves
      for i,bits in pairs(current_leaf.pvs) do
        i=shl(i,5)
        for j=0,31 do
          -- visible?
          if band(bits,shl(0x1,j))~=0 then
            local leaf=leaves[bor(i,j)+2]
            -- tag visible parents (if not already tagged)
            while leaf and leaf.visframe~=visframe do
              leaf.visframe=visframe
              leaf=leaf.parent
            end
          end
        end
      end    
    end
  end

  -- refresh visible set
  collect_leaves(models.leaves)

  local visleaves={}
  if current_leaf then
    function collect_bsp(node,pos)
      local function collect_leaf(side)
        local child=node[side]
        if child and child.visframe==visframe then
          if child.contents then          
            visleaves[#visleaves+1]=child
          else
            collect_bsp(child,pos)
          end
        end
      end  
      local side=plane_isfront(node.plane,pos)
      collect_leaf(side)
      collect_leaf(not side)
    end   
    collect_bsp(models[1].bsp,pos)
  else
    visleaves=models.leaves
  end

  local f_cache={}
  local cc,ss=cos(angle),sin(angle)
  for i=#visleaves,1,-1 do
    local leaf=visleaves[i]
  --for i,leaf in ipairs(visleaves) do
    for j,face in ipairs(leaf) do
      if not f_cache[face] and plane_dot(face.plane,pos)>face.cp~=face.side then
        f_cache[face]=true
        love.graphics.setColor( 0, i/#visleaves, j/#leaf)
        local poly={}
        local vis=true
        for _,vi in ipairs(face.verts) do
          local v=models.verts[vi]
          local x,y,z=v[0]-camx,v[2]-zoom,v[1]-camy
          -- rotation
          x,z=cc*x-ss*z,ss*x+cc*z
          local w=128/z          
          add(poly,{x,y,z,x=hw+x*w,y=hh-y*w,w=w})        
        end
        poly = z_poly_clip(poly,#poly)
        if #poly>2 then
          local ngon={}
          for i=1,#poly do            
            add(ngon,poly[i].x)
            add(ngon,poly[i].y)
          end
          -- close poly
          add(ngon,ngon[1])
          add(ngon,ngon[2])
          love.graphics.polygon("fill", ngon)
        end
      end
    end
  end


  love.graphics.draw(models.raw.textures[texture].imgs[1], 0 ,0,0,4,4)


end


function unpack_array(fn,array)
    for i=0,#array do
        fn(array[i],i)
    end
end
function unpack_vert(v,dst)
    dst = dst or {}
    add(dst, v.x)
    add(dst, v.y)
    add(dst, v.z)
    return dst
end

function unpack_map(bsp)
    local verts,planes,faces,leaves,nodes,models,uvs,clipnodes={},bsp.planes,{},{},{},{},{},{}
    
    printh("------------------------")
  
    -- planes
    plane_get=function(pi)
      return planes[pi]
    end
    plane_dot=function(pi,v)
      local plane=planes[pi]
      local t,n=plane.type,plane.normal
      if t<3 then                 
        return n[t]*v[t],plane.dist
      end
      return n[0]*v[0]+n[1]*v[1]+n[2]*v[2],plane.dist
    end
    plane_isfront=function(pi,v)
      local plane=planes[pi]
      local t,n=plane.type,plane.normal
      if t<3 then    
        return n[t]*v[t]>plane.dist
      end
      return n[0]*v[0]+n[1]*v[1]+n[2]*v[2]>plane.dist
    end
  
    unpack_array(function(f,i)      
      -- side flag
      local face={
        side=(f.side~=0),
        plane=f.planenum
      }

      local face_verts = {}
      for i=0,f.numedges-1 do
        local edge_id = bsp.surfedges[f.firstedge + i]
        if edge_id>=0 then
          local edge = bsp.edges[edge_id]
          add(face_verts, edge.v[0])
        else
          local edge = bsp.edges[-edge_id]
          add(face_verts, edge.v[1])
        end
      end
      -- !! 1-based array
      face.verts = face_verts
      face.cp=plane_dot(f.planenum, bsp.vertices[face_verts[1]])
      add(faces, face)
    end, bsp.faces)
  
    local unpack_node_pvs
    unpack_node_pvs=function(node, model, cache)
      for i=0,1 do
        local child_id = node.children[i]
        if band(child_id,0x8000) ~= 0 then
          child_id = bnot(child_id)
          if child_id ~= 0 then
            local leaf = bsp.leaves[child_id]
            if leaf.visofs~=-1 and not cache[child_id] then
              local numbytes = shr(model.visleafs+7,3)
              -- print("leafs: {} / bytes: {} / offset: {} / {}".format(model.numleafs, numbytes, leaf.visofs, len(visdata)))
              local vis = {}
              local i = 0
              local c_out = 0          
              while c_out<numbytes do
                local ii = bsp.visdata[leaf.visofs+i]
                if ii ~= 0 then
                  vis[shr(c_out,2)] = bor(vis[shr(c_out,2)] or 0, shl(ii, 8*(c_out%4)))              
                  i = i + 1
                  c_out = c_out + 1
                  goto skip
                end
                -- skip 0
                i = i + 1
                -- number of bytes to skip
                c = bsp.visdata[leaf.visofs+i]
                i = i + 1
                c_out = c_out + c
  ::skip::
              end
              cache[child_id] = vis
            end
          end
        else
          unpack_node_pvs(bsp.nodes[child_id], model, cache)
        end
      end
    end

    -- attach vis data to 1st model
    local main_model,vis_cache=bsp.models[0],{}    
    unpack_node_pvs(bsp.nodes[main_model.headnode[0]], main_model, vis_cache)

    unpack_array(function(leaf, i)
      local l={
        contents = leaf.contents,
        pvs = vis_cache[i]
      }
      for i=0,leaf.nummarksurfaces-1 do
        -- de-ref face
        add(l, faces[bsp.marksurfaces[leaf.firstmarksurface + i] + 1])
      end
      add(leaves,l)
    end, bsp.leaves)

    unpack_array(function(node)
      local n={
        plane=node.planenum
      }
      local flags = 0
      for i=0,1 do
        local child_id = node.children[i]
        if band(child_id,0x8000) ~= 0 then
          child_id = bnot(child_id)
          if child_id ~= 0 then
            flags = bor(flags, i+1)
            child_id = child_id + 1
          else
            child_id = 0
          end
        else
          -- node
          if child_id==0 then
            assert("invalid child reference: 0")
          end
          child_id = child_id + 1
        end
        n[i==0] = child_id
      end
      n.flags=flags
      add(nodes, n)
    end, bsp.nodes)

    -- attach nodes/leaves
    for _,node in pairs(nodes) do
      local function attach_node(side,leaf)
        local refs=leaf and leaves or nodes
        local child=refs[node[side]]
        node[side]=child
        -- used to optimize bsp traversal for rendering
        if child then
          child.parent=node
        end
      end
      attach_node(true,band(node.flags,0x1)~=0)
      attach_node(false,band(node.flags,0x2)~=0)
    end
    
    -- shared content leaves
    local content_types={}
    for i=1,6 do
      -- -1: ordinary leaf
      -- -2: the leaf is entirely inside a solid (nothing is displayed).
      -- -3: Water, the vision is troubled.
      -- -4: Slime, green acid that hurts the player.
      -- -5: Lava, vision turns red and the player is badly hurt.   
      -- -6: sky 
      add(content_types,{contents=-i})
    end  
    -- unpack "clipnodes" (collision hulls)
    unpack_array(function(node)
      local clipnode={
        plane=node.planenum
      }
      local flags = 0
      for i=0,1 do
        clipnode[i==0]=node.children[i]
      end
      add(clipnodes, clipnode)
    end, bsp.clipnodes)
    -- attach references
    for _,node in pairs(clipnodes) do
      local function attach_node(side)
        local id=node[side]
        node[side]=id<0 and content_types[-id] or clipnodes[id+1]
      end
      attach_node(true)
      attach_node(false)
    end
  
    -- unpack "models"  
    local leaf_base=0
    models.verts=bsp.vertices
    models.planes=bsp.planes
    models.leaves=leaves
    unpack_array(function(model)  
      add(models,{
        origin={0,0,0},
        solid=true,
        faces=faces,
        -- root node (for display)
        bsp=nodes[model.headnode[0]+1],
        -- 32 unit clip nodes
        clipnodes=clipnodes[model.headnode[1]+1],
        leaf_start=leaf_base + 2,
        leaf_end=leaf_base + model.visleafs + 1})
      leaf_base = leaf_base + model.visleafs
    end, bsp.models)

    return models
  end