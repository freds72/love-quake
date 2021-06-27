import os
import re
import io
import math
import logging
import argparse
from PIL import Image, ImageFilter

# reference: https://quakewiki.org/wiki/Quake_palette#palette.lmp
# sample a 24-bit RGB value to one of the colours on the existing 8-bit palette 
def convert_24_to_8(palette, rgb):
 best_index = -1
 best_dist = 0

 for i in range(256):
   dist = 0
   for j in range(3):
     # note that we could use RGB luminosity bias for greater accuracy, but quake's colormap apparently didn't do this
     d = abs(rgb[j] - palette[i*3+j])
     dist += d * d

   if best_index == -1 or dist < best_dist:
     best_index = i
     best_dist = dist

 return best_index

def generate_colormap(palette, num_fullbrights):
 out_colormap = bytes([])

 for x in range(256):
  for y in range(64):
   # default: this colour is a fullbright, just keep the original colour
   col = x
   if x < 256 - num_fullbrights:
    rgb = []
    for i in range(3):
      # divide by 32, rounding to nearest integer
      c = min((palette[x*3+i] * (63 - y) + 16) >> 5, 255)
      rgb.append(c) 
    col = convert_24_to_8(palette, rgb)
   out_colormap += bytes([col])
 return out_colormap

def make_pal2(srcpath, num_fullbrights, outpath):
 src = Image.open(srcpath)
 width, height = src.size
 if width>16 or height>16:
   raise Exception("Palette image: {} invalid size: {}x{} - Palette size must be less than 16x16px".format(srcpath,width,height))
 # convert to array of rgb integers
 palette = []
 for x in range(width):
  for y in range(height):
   rgb = src.getpixel((x,y))   
   for i in range(3):
    palette.append(rgb[i])
 
 colormap = generate_colormap(palette, num_fullbrights)
 with open(outpath, "wb") as f:
  f.write(colormap)

def make_pal(srcpath, num_fullbrights, outpath):
 src = Image.open(srcpath)
 width, height = src.size
 if width>16 or height>16:
   raise Exception("Palette image: {} invalid size: {}x{} - Palette size must be less than 16x16px".format(srcpath,width,height))
 # convert to array of rgb integers
 palette = bytearray([])
 for y in range(height):
  for x in range(width):
   rgb = src.getpixel((x,y))   
   palette += bytes(rgb[:3])
 with open(outpath, "wb") as f:
  f.write(palette)

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--palette", required=True, type=str, help="Palette image")
  parser.add_argument("--brights", required=False, type=int, default=32, help="Number of bright colors (default: 32). Use 0 to disable")
  parser.add_argument("--out", required=True, type=str, help="Output lmp file")

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)
  make_pal(args.palette, args.brights, args.out)  
    
if __name__ == '__main__':
 main()


