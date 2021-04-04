import random
from PIL import Image, ImageFilter, ImageDraw, ImageFont

# https://blackpawn.com/texts/lightmaps/default.html
class Rect:
  def __init__(self, left=0, top=0, right=127, bottom=127):
    self.top = top
    self.left = left
    self.bottom = bottom
    self.right = right
    self.size = (self.right-self.left+1, self.bottom-self.top+1)
  
  def compare(self,width,height):
    w,h = self.size
    if w==width and h==height: return 0
    if w>=width and h>=height: return 1
    return -1

  def __str__(self):
    return "{}/{} - {}/{}".format(self.left,self.top,self.right,self.bottom)

class ImageAtlas():
  def __init__(self, width=128, height=128, rc=None):
    self.child=[]
    self.rc = rc or Rect(left=0,top=0,right=width-1,bottom=height-1)
    self.img = None
  
  def _reserve(self, img, tabs=""):
    if len(self.child)>0:
      for child in self.child:
        newnode = child._reserve(img, tabs + "\t")
        if newnode: return newnode
      return
      # raise Exception("No room left for: {}".format(img.size))
  
    # print(tabs, self)
    # if there's already a lightmap here, return no room left
    if self.img: return None

    width, height = img.size
    # if we're too small, return
    fit = self.rc.compare(width, height)
    
    if fit<0: 
      return None
    if fit==0: 
      self.img = img
      return self

    # otherwise, gotta split this node and create some kids
    # decide which way to split)
    rw, rh = self.rc.size   
    dw = rw - width
    dh = rh - height

    # insert into first child we created
    if dw > dh: 
      self.child=[     
        ImageAtlas(rc=Rect(self.rc.left,      self.rc.top, self.rc.left+width-1, self.rc.bottom)),
        ImageAtlas(rc=Rect(self.rc.left + width, self.rc.top, self.rc.right,     self.rc.bottom))
      ]
    else:
      self.child=[
        ImageAtlas(rc=Rect(self.rc.left, self.rc.top,   self.rc.right, self.rc.top+height-1)),
        ImageAtlas(rc=Rect(self.rc.left, self.rc.top+height,self.rc.right, self.rc.bottom))
      ]
    
    return self.child[0]._reserve(img)

  def add(self, img):
    node = self._reserve(img)
    if not node:
      raise Exception("No room left for: {}".format(img.size))
    # return lightmap coordinates
    return (node.rc.left, node.rc.top)

  def __str__(self):
    return "{} img: {}".format(self.rc,self.img)

class MockImage():
  def __init__(self,width,height,msg=None):
    self.size = (width, height)
    self.msg = msg
  
def visit_atlas(node,tabs=""):
  print(tabs,node)
  for child in node.child:
    visit_atlas(child, tabs=tabs+"\t")  

# get a font
fnt = ImageFont.truetype("arial",6)

def draw_atlas(node,d):
  global fnt
  rc = node.rc
  if node.img:
    c = random.randrange(256)
    d.rectangle((rc.left,rc.top,rc.right,rc.bottom),fill=(c,c,c,255))        
    # d.text(((rc.left+rc.right)/2,(rc.top+rc.bottom)/2), node.img.msg, font=fnt, fill=(0,0,0,255))
  else:
    d.rectangle((rc.left,rc.top,rc.right,rc.bottom),outline=(255,0,0,255))
  for child in node.child:
    draw_atlas(child,d)  

def test():  
  atlas = ImageAtlas()
  imgs = []
  for i in range(24):
    imgs.append(MockImage(random.randrange(8,32),random.randrange(8,32), msg=str(i)))

  # sort
  sorted(imgs, key=lambda img: img.size)
  for i in imgs:
    atlas.add(i)  

  img = Image.new('RGBA', (128,128), (0,0,0,0))
  draw = ImageDraw.Draw(img)
  draw_atlas(atlas, draw)
  img.save("atlas.png")
  
  visit_atlas(atlas)
  
if __name__ == '__main__':
    test()
