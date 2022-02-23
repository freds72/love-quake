local ffi=require 'ffi'
local nfs = require( "nativefs" )
local entities = require( "entities" )

local model = {}
-- module globals
plane_dot,plane_dot1,plane_isfront,plane_get=nil,nil,nil,nil

-- pico8 compat helpers
local add=table.insert
local flr,ceil=math.floor,math.ceil
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local sin,cos=math.sin,math.cos

ffi.cdef[[
    #pragma pack(1)
    
    typedef float dvertex_t[3];
    typedef struct { unsigned char r,g,b; } color_t;
    
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
        // [s/t][xyz offset]
        dvertex_t   s;
        float       s_offset;
        dvertex_t   t;
        float       t_offset;
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

-- reads the given struct name from the byte array
local function read_all(cname, lump, mem)
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

local function unpack_array(fn,array)
    for i=0,#array do
        fn(array[i],i)
    end
end
local function unpack_vert(v,dst)
    dst = dst or {}
    add(dst, v.x)
    add(dst, v.y)
    add(dst, v.z)
    return dst
end

local function unpack_map(bsp)
    local verts,planes,faces,leaves,nodes,models,uvs,clipnodes={},bsp.planes,{},{},{},{},{},{}
    
    -- planes
    plane_get=function(pi)
        local n=planes[pi].normal
        return n[0],n[1],n[2]
    end
    plane_dot=function(pi,v)
        local plane=planes[pi]
        local t,n=plane.type,plane.normal
        if t<3 then                 
        return n[t]*v[t],plane.dist
        end
        return n[0]*v[0]+n[1]*v[1]+n[2]*v[2],plane.dist
    end
    plane_dot1=function(pi,v)
        local plane=planes[pi]
        local t,n=plane.type,plane.normal
        if t<3 then                 
        return n[t]*v[t+1],plane.dist
        end
        return n[0]*v[1]+n[1]*v[2]+n[2]*v[3],plane.dist
    end
    plane_isfront=function(pi,v)
        local plane=planes[pi]
        local t,n=plane.type,plane.normal
        if t<3 then    
        return n[t]*v[t]>plane.dist
        end
        return n[0]*v[0]+n[1]*v[1]+n[2]*v[2]>plane.dist
    end
    
    local function v_dot(a,b)
        return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
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
        -- texture?
        if f.texinfo~=-1 then
            local tex = bsp.texinfo[f.texinfo]
            face.texinfo = tex

            face.baselight = f.styles[1]

            -- light info?
            if f.lightofs~=-1 then
                local lightmap_scale = 16
                local u_min=32000
                local u_max=-32000
                local v_min=32000
                local v_max=-32000
                for _,vi in pairs(face_verts) do
                    local v=bsp.vertices[vi]
                    local u=v_dot(v,tex.s) + tex.s_offset
                    local v=v_dot(v,tex.t) + tex.t_offset
                    u_min=min(u_min,u)
                    v_min=min(v_min,v)
                    u_max=max(u_max,u)
                    v_max=max(v_max,v)
                end
                face.umin = u_min
                face.vmin = v_min
                u_min=flr(u_min / lightmap_scale)
                v_min=flr(v_min / lightmap_scale)
                u_max=ceil(u_max / lightmap_scale)
                v_max=ceil(v_max / lightmap_scale)
                
                -- lightmap size
                face.width = u_max-u_min+1
                face.height = v_max-v_min+1 
                face.lightofs = bsp.lightmaps[f.lightofs]
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
    models.textures=bsp.textures
    unpack_array(function(model)  
        add(models,{
        origin={0,0,0},
        m={
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            0,0,0,1
        },
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

local function unpack_textures(lump, mem)
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
        -- store pointers to image data (e.g. color indices)
        local imgs={}
        for j=0,3 do
            add(imgs,ffi.cast("unsigned char*", mem + ofs + mt.offsets[j]))
            --[[
            local scale=shl(1,j)
            local w,h=flr(mt.width/scale), flr(mt.height/scale)
            local imagedata = love.image.newImageData(w,h)
            local image     = love.graphics.newImage(imagedata,{linear=true, mipmaps=false})
            image:setFilter('nearest','nearest')        
            local ptr = ffi.cast('uint32_t*', imagedata:getFFIPointer()) 
            for k=0,w*h-1 do
                local rgb=palette[data[k] ]
                ptr[k]=0xff000000+shl(rgb.b,16)+shl(rgb.g,8)+rgb.r
            end
            image:replacePixels(imagedata)
            add(imgs, image)
            ]]
        end
        textures[i] = {
            width = mt.width,
            height = mt.height,
            mips = imgs
        }
        end
    end
    return textures
end

-- handle to bsp raw memory
local _data
function load_bsp(root_path, name)
    _data = nfs.newFileData(root_path.."/maps/"..name)

    local mem = _data:getFFIPointer()

    local header = ffi.cast('dheader_t*', mem)
    print("version:"..header.version)

    local ptr = ffi.cast("unsigned char*",mem)

    
    local entities_lump = header.entities
    local entities = ffi.string(ptr + entities_lump.fileofs, entities_lump.filelen)

    local bsp={
        models = read_all("dmodel_t", header.models, ptr),
        vertices = read_all("dvertex_t", header.vertices, ptr)[0],
        visdata = read_all("unsigned char", header.visibility, ptr)[0],
        lightmaps = read_all("unsigned char", header.lighting, ptr),
        nodes = read_all("dnode_t", header.nodes, ptr),
        clipnodes = read_all("dclipnode_t", header.clipnodes, ptr),
        faces = read_all("dface_t", header.faces, ptr),
        texinfo = read_all("texinfo_t", header.texinfo, ptr),
        textures = unpack_textures(header.textures, ptr),
        planes = read_all("dplane_t", header.planes, ptr),
        leaves = read_all("dleaf_t", header.leaves, ptr),
        edges = read_all("dedge_t", header.edges, ptr),
        marksurfaces = read_all("unsigned short", header.marksurfaces, ptr)[0],
        surfedges = read_all("int", header.surfedges, ptr)[0],
    }

    return unpack_map(bsp),unpack_entities(entities)
end

return model