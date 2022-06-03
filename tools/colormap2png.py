import os
import re
import io
import math
import logging
import argparse
from ctypes import *
from PIL import Image, ImageFilter
from c_tools import StructHelper

class color_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("r", c_ubyte),
    ("g", c_ubyte),
    ("b", c_ubyte)
  ]

class palette_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("idx", c_uint8)
  ]

def read_palette(input, width):
  return color_t.read_n(input, width)

def colormap2png(input, palette, outfile):
  width = len(palette)
  colormap = [palette[c.idx] for c in palette_t.read_n(input, width * 64)]
  
  # convert to array of rgb integers
  img = Image.new('RGB', (width, 64), (0,0,0))
  for i,c in enumerate(colormap):
    img.putpixel((i%width,i//width),(c.r,c.g,c.b))
  img.save(outfile,"png")

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--palette", required=True, type=str, help="Palette lump")
  parser.add_argument("--colormap", required=True, type=str, help="Colormap lump")
  parser.add_argument("--out", required=True, type=str, help="Output PNG filename")

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)

  width = os.path.getsize(args.palette)//sizeof(color_t)
  with open(args.palette,"rb") as pf: 
    palette = read_palette(pf, width)
    with open(args.colormap, "rb") as cf:
      colormap2png(cf, palette, args.out)
    
if __name__ == '__main__':
  main()


