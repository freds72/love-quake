import bpy
import bmesh
import argparse
import sys
import os
import re
from mathutils import Vector, Matrix
from collections import defaultdict

# pack helpers (cannot be shared - Python file reference sheningans...)
def tohex(val, nbits):
    return (hex((int(round(val,0)) + (1<<nbits)) % (1<<nbits))[2:]).zfill(nbits>>2)

# variable length packing (1 or 2 bytes)
def pack_variant(x):
    x=int(x)
    if x>0x7fff:
      raise Exception('Unable to convert: {} into a 1 or 2 bytes'.format(x))
    # 2 bytes
    if x>127:
        h = "{:04x}".format(x + 0x8000)
        if len(h)!=4:
            raise Exception('Unable to convert: {} into a word: {}'.format(x,h))
        return h
    # 1 byte
    h = pack_byte(x)
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h

# single byte (unsigned short)
def pack_byte(x):
    h = tohex(x,8)
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h
    
# short must be between -32000/32000
def pack_int(x):
    h = tohex(x,16)
    if len(h)!=4:
        raise Exception('Unable to convert: {} into a word: {}'.format(x,h))
    return h

def pack_int32(x):
    h = tohex(x,32)
    if len(h)!=8:
        raise Exception('Unable to convert: {} into a dword: {}'.format(x,h))
    return h

# 16:16 fixed point value
# 4 bytes
def pack_fixed(x):
    h = tohex(int(x*(1<<16)),32)
    if len(h)!=8:
        raise Exception('Unable to convert: {} into a dword: {}'.format(x,h))
    return h

# short must be between -127/127
def pack_short(x):
    h = pack_byte(int(round(x+128,0)))
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h

# float must be between -4/+3.968 resolution: 0.03125
# 1 byte
def pack_float(x):
    h = pack_byte(int(round(32*x+128,0)))
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h
# double must be between -128/+127 resolution: 0.0078
# 2 bytes
def pack_double(x):
    h = "{}".format(tohex(128*x+16384,16))
    if len(h)!=4:
        raise Exception('Unable to convert: {} into a word: {}'.format(x,h))
    return h

# https://blender.stackexchange.com/questions/153048/blender-2-8-python-input-rgb-doesnt-match-hex-color-nor-actual-color
# seriously???
# import matplotlib.colors
# matplotlib.colors.to_rgb('#B4FBB8')
# 0 : (0.0, 0.0, 0.0)
# 1 : (0.11372549019607843, 0.16862745098039217, 0.3254901960784314)
# 2 : (0.49411764705882355, 0.1450980392156863, 0.3254901960784314)
# 3 : (0.0, 0.5294117647058824, 0.3176470588235294)
# 4 : (0.6705882352941176, 0.3215686274509804, 0.21176470588235294)
# 5 : (0.37254901960784315, 0.3411764705882353, 0.30980392156862746)
# 6 : (0.7607843137254902, 0.7647058823529411, 0.7803921568627451)
# 7 : (1.0, 0.9450980392156862, 0.9098039215686274)
# 8 : (1.0, 0.0, 0.30196078431372547)
# 9 : (1.0, 0.6392156862745098, 0.0)
# 10 : (1.0, 0.9254901960784314, 0.15294117647058825)
# 11 : (0.0, 0.8941176470588236, 0.21176470588235294)
# 12 : (0.1607843137254902, 0.6784313725490196, 1.0)
# 13 : (0.5137254901960784, 0.4627450980392157, 0.611764705882353)
# 14 : (1.0, 0.4666666666666667, 0.6588235294117647)
# 15 : (1.0, 0.8, 0.6666666666666666)
# 128 : (0.1607843137254902, 0.09411764705882353, 0.0784313725490196)
# 129 : (0.06666666666666667, 0.11372549019607843, 0.20784313725490197)
# 130 : (0.25882352941176473, 0.12941176470588237, 0.21176470588235294)
# 131 : (0.07058823529411765, 0.3254901960784314, 0.34901960784313724)
# 132 : (0.4549019607843137, 0.1843137254901961, 0.1607843137254902)
# 133 : (0.28627450980392155, 0.2, 0.23137254901960785)
# 134 : (0.6352941176470588, 0.5333333333333333, 0.4745098039215686)
# 135 : (0.9529411764705882, 0.9372549019607843, 0.49019607843137253)
# 136 : (0.7450980392156863, 0.07058823529411765, 0.3137254901960784)
# 137 : (1.0, 0.4235294117647059, 0.1411764705882353)
# 138 : (0.6588235294117647, 0.9058823529411765, 0.1803921568627451)
# 139 : (0.0, 0.7098039215686275, 0.2627450980392157)
# 140 : (0.023529411764705882, 0.35294117647058826, 0.7098039215686275)
# 141 : (0.4588235294117647, 0.27450980392156865, 0.396078431372549)
# 142 : (1.0, 0.43137254901960786, 0.34901960784313724)
# 143 : (1.0, 0.615686274509804, 0.5058823529411764)
rgb_to_pico8={
  "0x000000":0,
  "0x1d2b53":1,
  "0x7e2553":2,
  "0x008751":3,
  "0xab5236":4,
  "0x5f574f":5,
  "0xc2c3c7":6,
  "0xfff1e8":7,
  "0xff004d":8,
  "0xffa300":9,
  "0xffec27":10,
  "0x00e436":11,
  "0x29adff":12,
  "0x83769c":13,
  "0xff77a8":14,
  "0xffccaa":15,
  "0x291814":128,
  "0x111d35":129,
  "0x422136":130,
  "0x125359":131,
  "0x742f29":132,
  "0x49333b":133,
  "0xa28879":134,
  "0xf3ef7d":135,
  "0xbe1250":136,
  "0xff6c24":137,
  "0xa8e72e":138,
  "0x00b543":139,
  "0x065ab5":140,
  "0x754665":141,
  "0xff6e59":142,
  "0xff9d81":143}

def diffuse_to_p8color(rgb):
    h = "0x{:02x}{:02x}{:02x}".format(int(round(255*rgb[0])),int(round(255*rgb[1])),int(round(255*rgb[2])))
    try:
        #print("diffuse:{} -> {}\n".format(rgb,p8_colors.index(h)))
        return rgb_to_pico8[h]
    except Exception as e:
        # unknown color
        raise Exception('Unknown color: 0x{} ({})'.format(h, rgb))

# Convert from Blender format to y-up format
def pack_vector(co):
    return "{}{}{}".format(pack_fixed(co.x), pack_fixed(co.z), pack_fixed(co.y))

# face flags bit layout:
FACE_FLAG_DUALSIDED=0x1
FACE_FLAG_UVMAP=0x2

def pack_face(bm, f, obcontext, palette):
    s = ""

    color = 0
    # face flags
    flags = 0

    vlen = len(f.loops)
    if vlen<3 or vlen>256:
        raise Exception("Only valid polygons supported (#verts: {}/256)".format(vlen))

    if len(obcontext.material_slots)>0:
        slot = obcontext.material_slots[f.material_index]
        mat = slot.material
        flags |= mat.use_backface_culling==False and FACE_FLAG_DUALSIDED or 0
        # if material use nodes, assumes "textured"
        if mat.use_nodes:
            flags |= FACE_FLAG_UVMAP
        else:
            # convert "hardware color" into palette index
            color = diffuse_to_p8color(mat.diffuse_color)
            if color not in palette:
                raise Exception("HW color not found in palette: {} (palette: {})".format(color, palette))
    
            color = palette.index(color)
    
    # flags
    s += pack_byte(flags)

    # + vertex ids (= edge loop)
    s += pack_byte(vlen)    
    for loop in f.loops:
        s += pack_variant(loop.vert.index) 

    if flags & FACE_FLAG_UVMAP:
        # + uv's
        uv_layer = bm.loops.layers.uv["UVMap"]
        # + vertex ids (= edge loop)
        for loop in f.loops:
            uv = loop[uv_layer].uv
            # align to pico8 tile boundaries
            # uv map must be 256x256
            s += pack_byte(int(round(256*uv[0])))
            # reverse image y
            s += pack_byte(int(round(256*(1-uv[1]))))
    else:
        # color
        s += pack_byte(color)

    return s  

def pack_layer(layer, palette):
    # data
    s = ""
    
    # pick object named "model"
    obcontext = [o for o in layer.objects if o.name == 'model'][0]
    obdata = obcontext.data
    bm = bmesh.new()
    bm.from_mesh(obdata)

    # all vertices
    s += pack_variant(len(bm.verts))
    for v in bm.verts:
        s += pack_vector(v.co)

    # faces 
    s += pack_variant(len(bm.faces))
    for f in bm.faces:
        s += pack_face(bm, f, obcontext, palette)      

        # normal
        s += pack_vector(f.normal)    

    return s

def write_model(path, colors):
    scene = bpy.context.scene

    # model data
    blob = pack_layer(scene.collection.children["export"], list(bytearray.fromhex(colors)))

    #
    with open(path, 'w') as f:
        f.write(blob)

def main():
    argv = sys.argv
    if "--" not in argv:
        argv = []
    else:
        argv = argv[argv.index("--") + 1:]

    try:
        parser = argparse.ArgumentParser(description='Exports Blender model as a byte array',prog = "blender -b -P "+__file__+" --")
        parser.add_argument('-o','--out', help='Output file', required=True, dest='out')
        parser.add_argument('-c','--colors', help='Pico8 hardware colors (hex packed)', required=True, dest='colors')
        args = parser.parse_args(argv)
    except Exception as e:
        sys.exit(repr(e))
    
    write_model(args.out, args.colors)

if __name__ == '__main__':
    main()