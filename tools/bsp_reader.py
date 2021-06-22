import os
import re
import io
import math
import logging
from dotdict import dotdict
from ctypes import *
from collections import namedtuple
from collections import defaultdict
from python2pico import *
from entity_reader import ENTITYReader
from PIL import Image, ImageFilter, ImageDraw

# credits: https://gist.github.com/JonathonReinhart/b6f355f13021cd8ec5d0101e0e6675b2
class StructHelper(object):
  def __get_value_str(self, name, fmt='{}'):
      val = getattr(self, name)
      if isinstance(val, Array):
          val = list(val)
      return fmt.format(val)

  def __str__(self):
      result = '{}:\n'.format(self.__class__.__name__)
      maxname = max(len(name) for name, type_ in self._fields_)
      for name, type_ in self._fields_:
          value = getattr(self, name)
          result += ' {name:<{width}}: {value}\n'.format(
                  name = name,
                  width = maxname,
                  value = self.__get_value_str(name),
                  )
      return result

  def __repr__(self):
      return '{name}({fields})'.format(
              name = self.__class__.__name__,
              fields = ', '.join(
                  '{}={}'.format(name, self.__get_value_str(name, '{!r}')) for name, _ in self._fields_)
              )

  @classmethod
  def _typeof(cls, field):
      """Get the type of a field
      Example: A._typeof(A.fld)
      Inspired by stackoverflow.com/a/6061483
      """
      for name, type_ in cls._fields_:
          if getattr(cls, name) is field:
              return type_
      raise KeyError

  @classmethod
  def read_from(cls, f):
      result = cls()
      if f.readinto(result) != sizeof(cls):
          raise EOFError
      return result

  @classmethod
  def read_one(cls, f, entry):
    f.seek(entry.offset)
    return cls.read_from(f)

  @classmethod
  def read_all(cls, f, entry):
    f.seek(entry.offset)
    result = []
    n = int(entry.size/sizeof(cls))
    for i in range(n):
      result.append(cls.read_from(f))
    return result

  def get_bytes(self):
      """Get raw byte string of this structure
      ctypes.Structure implements the buffer interface, so it can be used
      directly anywhere the buffer interface is implemented.
      https://stackoverflow.com/q/1825715
      """

      # Works for either Python2 or Python3
      return bytearray(self)

      # Python 3 only! Don't try this in Python2, where bytes() == str()
      #return bytes(self)

# warning: outdated/wrong on some structures      
# http://www.gamers.org/dEngine/quake/spec/quake-spec34/qkspec_4.htm
# real sources
# https://github.com/id-Software/Quake/blob/master/QW/client/bspfile.h

class dentry_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("offset", c_long),
    ("size", c_long)
  ]

class dheader_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("version", c_int),
    ("entities",dentry_t), # List of Entities.
    ("planes",dentry_t), # Map Planes.
    ("miptex",dentry_t), # Wall Textures.
    ("vertices",dentry_t), # Map Vertices.
    ("visilist",dentry_t), # Leaves Visibility lists.
    ("nodes",dentry_t), # BSP Nodes.
    ("textures",dentry_t), # Texture Info for faces.
    ("faces",dentry_t), # Faces of each surface.
    ("lightmaps",dentry_t), # Wall Light Maps.
    ("clipnodes",dentry_t), # clip nodes, for Models.
    ("leaves",dentry_t), # BSP Leaves.
    ("marksurfaces",dentry_t), # List of Faces.
    ("edges",dentry_t), # Edges of faces.
    ("surfedges",dentry_t), # List of Edges.
    ("models",dentry_t) # List of Models.     
  ]

class vec3_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("x", c_float),
    ("z", c_float),
    ("y", c_float)
  ]

class vec3short_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("x", c_short),
    ("z", c_short),
    ("y", c_short)
  ]

class boundbox_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("min", vec3_t),
    ("max", vec3_t)
  ]

class bboxshort_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("min", vec3short_t),
    ("max", vec3short_t)
  ]

class dclipnode_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("plane_id", c_int),
    ("children", c_short*2)  # negative numbers are contents (eg leafs)
  ]

class dplane_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("normal", vec3_t), # Vector orthogonal to plane (Nx,Ny,Nz)
                        # with Nx2+Ny2+Nz2 = 1
    ("dist", c_float),  # Offset to plane, along the normal vector.
                        # Distance from (0,0,0) to the plane
    ("type", c_int)    # Type of plane, depending on normal vector.
  ]

class dedge_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("v", c_short * 2) # vertex numbers
  ]

class dmarksurface_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("face_id", c_ushort) # face id
  ]

class dsurfedge_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("edge_id", c_int) # edge id
  ]

MAX_MAP_HULLS = 4
class dmodel_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("bound",boundbox_t),          # The bounding box of the Model
    ("origin",vec3_t),             # origin of model, usually (0,0,0)
    ("headnode",c_int * MAX_MAP_HULLS),             # index of first BSP node
    ("numleafs",c_int),             # number of BSP leaves
    ("firstface", c_int),             # index of Faces
    ("numfaces", c_int)             # number of Faces
  ]

class edge_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("v", c_ushort * 2)  # index of the start+end vertex, must be in [0,numvertices[
  ]

class dnode_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("plane_id", c_int),    # The plane that splits the node
                            #           must be in [0,numplanes[
    ("children", c_short * 2),     # If bit15==0, index of Front child node
                            # If bit15==1, ~front = index of child leaf
                            # If bit15==0, id of Back child node
                            # If bit15==1, ~back =  id of child leaf
    ("bound", bboxshort_t),   # Bounding box of node and all childs
    ("face_id", c_ushort),  # Index of first Polygons in the node
    ("face_num", c_ushort)  # Number of faces in the node
  ]

CONTENTS_EMPTY  =	-1
CONTENTS_SOLID  =	-2
CONTENTS_WATER  =	-3
CONTENTS_SLIME  =	-4
CONTENTS_LAVA	  =	-5
CONTENTS_SKY	  =	-6

NUM_AMBIENTS = 4
class dleaf_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("contents",c_int),             # Special type of leaf
    ("visofs",c_int),          # Beginning of visibility lists
                                 #     must be -1 or in [0,numvislist[
    ("bound",bboxshort_t),       # Bounding box of the leaf
    ("face_id", c_ushort),      # First item of the list of faces
                                 #     must be in [0,numlfaces[
    ("face_num", c_ushort),     # Number of faces in the leaf  
    ("ambient_level", c_byte * NUM_AMBIENTS)       # level of the four ambient sounds: 0 no sound / 0xff max volume
  ]

MAXLIGHTMAPS = 4
class dface_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("plane_id", c_short),      # The plane in which the face lies
                                 #           must be in [0,numplanes[ 
    ("side", c_short),          # 0 if in front of the plane, 1 if behind the plane
    ("edge_id", c_int),        # first edge in the List of edges
                                 #           must be in [0,numledges[
    ("edge_num", c_short),     # number of edges in the List of edges
    ("tex_id", c_short),    # index of the Texture info the face is part of
                                 #           must be in [0,numtexinfos[ 
    ("styles", c_ubyte * MAXLIGHTMAPS),     # type of lighting, for the face
    ("lightofs", c_int)    # Pointer inside the general light map, or -1       
  ]                             

TEX_SPECIAL=1
class texinfo_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("u_axis",  vec3_t),
    ("u_offset", c_float),
    ("v_axis", vec3_t),
    ("v_offset", c_float),
    ("miptex", c_int),
    ("flags", c_int)
  ]

class dmiptexlump_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("nummiptex", c_int),
    ("dataofs", c_int * 4)
  ]

MIPLEVELS = 4
class miptex_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("name", c_char*16),
    ("width", c_uint),
    ("height", c_uint),
    ("offsets", c_uint * MIPLEVELS) # four mip maps stored
  ]

def pack_bbox(bbox):
  return pack_vec3(bbox.min) + pack_vec3(bbox.max)

def pack_texture(tex):
  s = ""
  s += pack_vec3(tex.u_axis)
  s += pack_fixed(tex.u_offset)
  s += pack_vec3(tex.v_axis)
  s += pack_fixed(tex.v_offset)
  return s

def pack_tline(texture):
  return "{:02x}{:02x}{:02x}{:02x}".format(texture.my,texture.mx,texture.height,texture.width)

def v_dot(a,b):
  return a.x*b.x+a.y*b.y+a.z*b.z

def pack_face(id, face, hard_edges):  
  s = ""
  # supporting plane index
  s += pack_variant(face.plane_id)
  # flags
  flags = 0
  if face.side:
    flags |=1

  # find texture
  texname = None
  if face.tex_id!=-1:
    tex = textures[face.tex_id]    
    if tex.miptex<len(miptex):
      mip = miptex[tex.miptex]
      texname = mip.name.decode("utf-8")
      if "sky" in texname:
        flags |= 2
    else:
      logging.warn("Invalid texture id: {}/{}".format(tex.miptex, len(miptex)))
  s += "{:02x}".format(flags)
    
  # base color/lightmap?
  color = 0
  # color = face.styles[0]
  # if color==0xff:
  #  color = face.styles[1]
  # elif color!=0:
  #   logging.warn("Light effect not supported: {}".format(color))
  if texname and "0x" in texname:    
    color = int(texname,16)
  s += "{:02x}".format(color)

  # hard edges
  edge_flags = 0

  # edge indirection
  # + skip last edge (duplicates start/end)
  face_verts = []
  if face.edge_num>32:
    raise Exception("Too many edges: {}/32".format(face.edge_num))
  for i in range(face.edge_num):
    edge_id = surfedges[face.edge_id + i].edge_id    
    if edge_id>=0:
      edge = edges[edge_id]
      face_verts.append(edge.v[0])      
    else:
      edge = edges[-edge_id]
      face_verts.append(edge.v[1])   
    if abs(edge_id) in hard_edges:
      edge_flags |= 1<<i

  s += pack_int32(edge_flags)

  # vertex indices
  s += pack_variant(len(face_verts))
  for vi in face_verts:
    s += pack_variant(vi)
    
  return s

def pack_leaf(id, leaf, vis):
  s = ""
  # type
  s += "{:02x}".format(128+leaf.contents)

  # visibility info
  s += pack_variant(len(vis))
  for k,v in vis.items():
    s += pack_variant(k)
    s += pack_int32(v)

  # faces?
  s += pack_variant(leaf.face_num)
  for i in range(leaf.face_num):
    face_id = marksurfaces[leaf.face_id + i].face_id
    s += pack_variant(face_id)
  return s

def pack_node(node):
  s = ""
  # supporting plane
  s += pack_variant(node.plane_id)

  flags = 0x0
  # todo: find out purpose of bsp node faces?
  # node_faces = []
  # for i in range(node.face_num):
  #   node_faces.append(faces[node.face_id + i])

  # references to nodes/leaves
  children = ""
  for i,child_id in enumerate(node.children):
    if child_id & 0x8000 != 0:
      child_id = ~child_id
      if child_id != 0:
        flags |= (i+1)
        # leaf
        children += pack_variant(child_id+1)
      else:
        # todo: optimize (flag?)
        children += pack_variant(0)
    else:
      # node
      if child_id==0:
        raise Exception("Child reference 0")
      children += pack_variant(child_id+1)

  s += "{:02x}{}".format(flags, children)
  return s

def pack_model(model):
  s = ""
  # reference to root node
  s += pack_variant(model.headnode[0]+1)
  
  # clip nodes
  s += pack_variant(len(clipnodes))
  for c in clipnodes:
    s += pack_variant(c.plane_id)
    flags = 0
    sc = ""
    for i in range(2):
      child = c.children[i]
      if child<0:
        flags |= (-child)<<(4*i)
      else:
        sc += pack_variant(child+1)
    s += "{:02x}".format(flags)
    s += sc
  return s

# https://mrelusive.com/publications/papers/Run-Length-Compression-of-Large-Sparse-Potential-Visible-Sets.pdf
def unpack_node_pvs(node, model, cache):
  for k,child_id in enumerate(node.children):
    if child_id & 0x8000 != 0:
      child_id = ~child_id
      if child_id != 0:
        leaf = leaves[child_id]
        if leaf.visofs!=-1 and child_id not in cache:
          numbytes = (model.numleafs+7)>>3
          # print("leafs: {} / bytes: {} / offset: {} / {}".format(model.numleafs, numbytes, leaf.visofs, len(visdata)))
          vis = {}
          i = 0
          c_out = 0          
          while c_out<numbytes:
            ii = visdata[leaf.visofs+i]
            if ii != 0:
              vis[c_out>>2] = vis.get(c_out>>2,0) | ii<<(8*(c_out%4))              
              i += 1
              c_out += 1
              continue
            # skip 0
            i += 1
            # number of bytes to skip
            c = visdata[leaf.visofs+i]
            # print("skipping: {}".format(c))
            i += 1
            c_out += c
          # print("{}:{}".format(child_id,{k:"{:02x}".format(v) for k,v in vis.items()}))
          # s = ""                  
          # for i in range(model.numleafs):
          #   if vis.get(i>>3,0)&(1<<(i&7)):
          #     s += "\t{}".format(i+1)
          #   else:
          #     s += "\t."
          # print("{}\t{}".format(child_id,s))
          cache[child_id] = vis
    else:
      unpack_node_pvs(nodes[child_id], model, cache)

def unpack_pvs(model, cache):
  for root_id in model.headnode:    
    if root_id<len(nodes): # ???      
      unpack_node_pvs(nodes[root_id], model, cache)

def pack_entities(entities):
  s = ""
  # player start?
  classnames=['info_player_start','info_player_deathmatch','testplayerstart']
  player_starts=[e for e in entities if "classname" in e and e.classname in classnames]
  if len(player_starts)==0:
    logging.warning("Missing info_player_start entity in: {}".format(entities))
    player_starts=[dotdict({
      'classname':'debug_player_start',
      'origin':dotdict({'x':0,'y':0,'z':0}),
      'angle':0
    })]
  player_start = player_starts[0]
  logging.info("Found player start: {} at: {}".format(player_start.classname, player_start.origin))
  s += pack_vec3(player_start.origin)
  s += pack_fixed("angle" in player_start and player_start.angle or 0)
    
  return s

def pack_vec3(v):
  return pack_fixed(v.x) + pack_fixed(v.y) + pack_fixed(v.z)

def read_bytes(f, entry):
    f.seek(entry.offset)
    return f.read(entry.size)

def read_miptex(f, entry):
  f.seek(entry.offset)
  nummiptex = c_int()
  f.readinto(nummiptex)
  mips = []
  for i in range(nummiptex.value):
    f.seek(entry.offset + 4 + 4*i)
    offset = c_int()
    f.readinto(offset) 
    offset = offset.value
    if offset==-1:
      continue
    f.seek(entry.offset + offset)
    mips.append(miptex_t.read_from(f))
  return mips

def get_face_texture(face):
  if face.tex_id!=-1:
    return textures[face.tex_id].miptex  
  return -1

def pack_bsp(filename):
  with open(filename,"rb") as bsp_handle:
    header = dheader_t.read_from(bsp_handle)

    # raw data
    global models
    global vertices
    global visdata
    global nodes
    global clipnodes
    global faces
    global textures 
    global miptex
    global planes
    global leaves
    global edges     
    global marksurfaces
    global surfedges
    global lightmaps
    models = dmodel_t.read_all(bsp_handle, header.models)
    vertices = vec3_t.read_all(bsp_handle, header.vertices)
    visdata = read_bytes(bsp_handle, header.visilist)
    lightmaps = read_bytes(bsp_handle, header.lightmaps)
    nodes = dnode_t.read_all(bsp_handle, header.nodes)
    clipnodes = dclipnode_t.read_all(bsp_handle, header.clipnodes)
    faces = dface_t.read_all(bsp_handle, header.faces)
    textures = texinfo_t.read_all(bsp_handle, header.textures)
    miptex = read_miptex(bsp_handle, header.miptex)
    planes = dplane_t.read_all(bsp_handle, header.planes)
    leaves = dleaf_t.read_all(bsp_handle, header.leaves)
    edges = dedge_t.read_all(bsp_handle, header.edges)
    marksurfaces = dmarksurface_t.read_all(bsp_handle, header.marksurfaces)
    surfedges = dsurfedge_t.read_all(bsp_handle, header.surfedges)

    s = ""

    # all vertices
    logging.info("Packing vertices: {}".format(len(vertices)))
    s += pack_variant(len(vertices))
    for v in vertices:
      s += pack_vec3(v)

    # all planes
    logging.info("Packing planes: {}".format(len(planes)))
    plane_types = [0,2,1,3,4,5]
    s += pack_variant(len(planes))
    for p in planes:
      s += "{:02x}".format(plane_types[p.type])
      s += pack_vec3(p.normal)
      s += pack_fixed(p.dist)

    # create edges to faces dictionary
    shared_edges = defaultdict(list)
    for i,face in enumerate(faces):
      for j in range(face.edge_num):
        id = abs(surfedges[face.edge_id + j].edge_id)
        if face not in shared_edges[id]:
          shared_edges[id].append(face)
    # find hard edges
    hard_edges = set()
    for id in shared_edges:
      shared_faces = shared_edges[id]
      if len(shared_faces)>0:
        f = shared_faces[0]
        n = planes[f.plane_id].normal
        for other_face in shared_faces:
          if f!=other_face:
            other_n = planes[other_face.plane_id].normal
            if abs(v_dot(n, other_n))<0.7:
              hard_edges.add(id)
              break

    # all faces
    logging.info("Packing faces: {}".format(len(faces)))
    s += pack_variant(len(faces))
    for i,face in enumerate(faces):
      s += pack_face(i, face, hard_edges)

    # visibility data
    logging.info("Packing visleafs: {}".format(len(visdata)))
    vis_cache = {}
    for model in models:
      unpack_pvs(model, vis_cache)

    # all leaves
    logging.info("Packing leaves: {}".format(len(leaves)))
    s += pack_variant(len(leaves))
    for i,l in enumerate(leaves):
      s += pack_leaf(i, l, vis_cache.get(i,{}))
        
    # all nodes
    logging.info("Packing nodes: {}".format(len(nodes)))
    s += pack_variant(len(nodes))
    for n in nodes:
      s += pack_node(n)
    
    # load models 
    models=[models[0]]
    s += pack_variant(len(models))
    for model in models:
      s += pack_model(model)
    
    # level gameplay
    entities = ENTITYReader(read_bytes(bsp_handle, header.entities).decode('iso-8859-1')).entities
    s += pack_entities(entities)

    return s
