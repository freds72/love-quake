local ffi=require 'ffi'
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
local band,bor,shl,bnot=bit.band,bit.bor,bit.lshift,bit.bnot

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

-- game globals
local plane_dot,plane_isfront,plane_get


function love.load(args)
    print("INFO - loading: "..args[1])
    love.filesystem.setIdentity("bsp")

    local f = love.filesystem.newFile(args[1]);
    f:open("r")
    -- dump to bytes
    local data = love.filesystem.newFileData(f)
    f:close()

    local mem = data:getFFIPointer()
    local header = ffi.cast('dheader_t*', mem)
    print("version:"..header.version)

    local src = ffi.cast("unsigned char*",mem)

    local bsp={
        models = read_all("dmodel_t", header.models, src),
        vertices = read_all("dvertex_t", header.vertices, src)[0],
        -- visdata = read_bytes(bsp_handle, header.visilist)
        -- lightmaps = read_bytes(bsp_handle, header.lightmaps)
        nodes = read_all("dnode_t", header.nodes, src),
        clipnodes = read_all("dclipnode_t", header.clipnodes, src),
        faces = read_all("dface_t", header.faces, src),
        -- textures = texinfo_t.read_all(bsp_handle, header.textures)
        -- miptex = read_miptex(bsp_handle, header.miptex)
        planes = read_all("dplane_t", header.planes, src),
        leaves = read_all("dleaf_t", header.leaves, src),
        edges = read_all("dedge_t", header.edges, src),
        marksurfaces = read_all("unsigned short", header.marksurfaces, src)[0],
        surfedges = read_all("int", header.surfedges, src)[0],
    }
    --[[
    for i=1,nmodels do
        local off = mem + lump.fileofs
        local model = ffi.cast(dmodel_t, off)
        print("origin: "..model.origin[0].."/"..model.origin[1].."/"..model.origin[2])
    end
    ]]
    unpack_array(function(face)
      print("faces: "..face.firstedge.." #faces: "..face.numedges)      
    end, bsp.faces)

    -- convert to flat array
    models,leaves=unpack_map(bsp)  
    models.data=data  
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
function love.wheelmoved(x, y)
  if y > 0 then
    zoom = zoom + 0.1
  elseif y < 0 then
    zoom = max(zoom - 0.1, 0.1)
  end
end

function love.update(dt)
  if love.mouse.isDown(1) then
      mx, my = love.mouse.getPosition()
      camx = mx - diffx
      camy = my - diffy
  end
end

function love.draw()
  love.graphics.clear()
  love.graphics.setLineWidth(2)  

  for i,model in ipairs(models) do
    love.graphics.setColor( 0.5, i/#models, 0, 1 )
    for i=model.leaf_start,model.leaf_end do   
      local leaf=leaves[i]
      for _,face in ipairs(leaf) do
        local poly={}
        for _,vi in ipairs(face.verts) do
          local v=models.verts[vi]
          add(poly,zoom * v[0]+camx)
          add(poly,zoom * v[1]+camy)
        end
        -- close poly
        add(poly,poly[1])
        add(poly,poly[2])
        love.graphics.line(poly)
      end
    end
  end
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

    local function get_leaf_faces(leaf)
      local res = {}
      for i=0,leaf.nummarksurfaces-1 do
        -- de-ref face
        add(res, faces[bsp.marksurfaces[leaf.firstmarksurface + i] + 1])
      end
      return res
    end    
  
    unpack_array(function(leaf)
      local l = get_leaf_faces(leaf)
      l.contents = leaf.contents
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
  
    return models,leaves
  end