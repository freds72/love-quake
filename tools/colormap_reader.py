import struct
import os
import re
import io
import math
from collections import namedtuple
from dotdict import dotdict
from PIL import Image, ImageFilter
from abstract_stream import Stream

# RGB to pico8 color index
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

# map rgb colors to label fake hexa codes
rgb_to_label={
  "0x000000":'0',
  "0x1d2b53":'1',
  "0x7e2553":'2',
  "0x008751":'3',
  "0xab5236":'4',
  "0x5f574f":'5',
  "0xc2c3c7":'6',
  "0xfff1e8":'7',
  "0xff004d":'8',
  "0xffa300":'9',
  "0xffec27":'a',
  "0x00e436":'b',
  "0x29adff":'c',
  "0x83769c":'d',
  "0xff77a8":'e',
  "0xffccaa":'f',
  "0x291814":'g',
  "0x111d35":'h',
  "0x422136":'i',
  "0x125359":'j',
  "0x742f29":'k',
  "0x49333b":'l',
  "0xa28879":'m',
  "0xf3ef7d":'n',
  "0xbe1250":'o',
  "0xff6c24":'p',
  "0xa8e72e":'q',
  "0x00b543":'r',
  "0x065ab5":'s',
  "0x754665":'t',
  "0xff6e59":'u',
  "0xff9d81":'v'}

# returns pico8 standard palette
def std_palette():
  return {rgb:p8 for rgb,p8 in rgb_to_pico8.items() if p8<16}

def std_rgba_palette():
  return {(int(rgb[2:4],16),int(rgb[4:6],16),int(rgb[6:8],16),255):p8 for rgb,p8 in rgb_to_pico8.items() if p8<16}

# helper methods for gradient/colormap manipulation
class ColormapReader():
  def __init__(self, stream):
    palette_data = stream.read("PLAYPAL")
    if len(palette_data)!=16*16*3:
      raise Exception("Invalid 'PLAYPAL' palette size: {} - must be 16*16*3".format(len(palette_data)))
    palette = []
    for i in range(0,16*16*3,3*16):
      i += 3*8
      r,g,b = palette_data[i],palette_data[i+1],palette_data[i+2]
      palette.append((r,g,b,255))
    self.palette = palette
    self.stream = stream
  
  # returns a pico8 compatible array of gradients
  # use_palette : indicates if color should be checked against the class palette
  def read(self, name, use_palette = False):
    palette = None
    if use_palette:
      palette = self.palette

    palette_data = self.stream.read(name)

    # align color formats
    if palette is not None:
      palette = ["0x{:02x}{:02x}{:02x}".format(pal[0],pal[1],pal[2]) for pal in palette]

    # transpose
    columns = [[] for i in range(16)]
    for i,rgb in enumerate(["0x{:02x}{:02x}{:02x}".format(palette_data[i],palette_data[i+1],palette_data[i+2]) for i in range(0,3*16*16,3)]):
      if palette is None:
        # get hardware color (inc. extended color ids)
        p8 = rgb_to_pico8.get(rgb, None)
        if p8 is None:
          raise Exception("Unknown PICO8 color: {} in palette: {}".format(rgb, name))
      else:
        # remap hardware color identifiers (0-15/129-145) to palette index (0-15) (for shading gradients)
        if rgb not in palette:
          raise Exception("Unable to reference: {}  in remap palette: {}".format(rgb,palette))
        p8 = palette.index(rgb)
      c = i%16
      columns[c].append(p8)
    # flatten list
    return [item for sublist in columns for item in sublist]

# helper class to check or build a new palette
class AutoPalette:  
  # palette: an array of (r,g,b,a) tuples
  def __init__(self, palette=None):
    self.auto = palette is None
    self.palette = palette or []

  def register(self, rgba):
    # invalid color (drop alpha)?
    if "0x{0[0]:02x}{0[1]:02x}{0[2]:02x}".format(rgba) not in rgb_to_pico8:
      raise Exception("Invalid color: {} in image".format(rgba))
    # returns a 0-15 value for image encoding
    if rgba in self.palette: return self.palette.index(rgba)
    # not found and auto-palette
    if self.auto:
      # already full?
      count = len(self.palette)
      if count==16:
        raise Exception("Image uses too many colors (16+). New color: {} not allowed".format(rgba))
      self.palette.append(rgba)
      return count
    raise Exception("Color: {} not in palette".format(rgba))

  # returns a list of hardware colors matching the palette
  # label indicates if color coding should be using 'fake' hexa or standard
  def pal(self, label=False):
    encoding = rgb_to_pico8
    if label:
      encoding = rgb_to_label
    return list(map(encoding.get,map("0x{0[0]:02x}{0[1]:02x}{0[2]:02x}".format,self.palette)))
