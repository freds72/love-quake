import time 
import sys 
import array 

# LZS compression
# credits: https://www.excamera.com/sphinx/article-compression.html

def prefix(s1, s2): 
  """ Return the length of the common prefix of s1 and s2 """
  sz = len(s2)
  for i in range(sz): 
    if s1[i % len(s1)] != s2[i]: 
      return i 
  return sz 
  
class Bitstream(object): 
  def __init__(self): 
    self.b = []
  def append(self, sz, v): 
    assert 0 <= v 
    assert v < (1 << sz) 
    for i in range(sz): 
      self.b.append(1 & (v >> (sz - 1 - i)))
  def toarray(self): 
    bb = [0] * int((len(self.b) + 7) / 8) 
    for i,b in enumerate(self.b): 
      if b: 
        bb[int(i / 8)] |= (1 << (i & 7)); 
    return array.array('B', bb) 

class Codec(object): 
  def __init__(self, b_off, b_len):
    self.b_off = b_off
    self.b_len = b_len
    self.history = 2 ** b_off 
    refsize = (1 + self.b_off + self.b_len) 
    # bits needed for a backreference
    if refsize < 9: 
      self.M = 1 
    elif refsize < 18: 
      self.M = 2 
    else:
      self.M = 3 
    # print "M", self.M # e.g. M 2, b_len 4, so: 0->2, 15->17 
    self.maxlen = self.M + (2**self.b_len) - 1 
  
  def compress(self, blk): 
    lempel = {} 
    sched = []
    pos = 0 
    while pos < len(blk): 
      k = blk[pos:pos+self.M] 
      older = (pos - self.history - 1) 
      candidates = [p for p in lempel.get(k, []) if (older < p)] 
      (bestlen, bestpos) = max([(0, 0)] + [(prefix(blk[p:pos], blk[pos:]), p) for p in candidates]) 
      if k in lempel: 
        lempel[k].add(pos) 
      else: 
        lempel[k] = set([pos]) 
      bestlen = min(bestlen, self.maxlen) 
      if bestlen >= self.M:
        sched.append((bestpos - pos, bestlen)) 
        pos += bestlen
      else: 
        sched.append(blk[pos]) 
        pos += 1
    return sched
  def toarray(self, blk): 
    bs = Bitstream()
    bs.append(4, self.b_off) 
    bs.append(4, self.b_len) 
    bs.append(2, self.M)
    # total size: not needed for this project
    # bs.append(32, len(blk)) 
    sched = self.compress(blk) 
    for c in sched: 
      if type(c) is tuple: 
        (offset, l) = c 
        bs.append(1, 1) 
        bs.append(self.b_off, -offset - 1) 
        bs.append(self.b_len, l - self.M) 
      else: 
        bs.append(1, 0) 
        bs.append(8, c) 
    return bs.toarray()
  def to_cfile(self, hh, blk, name): 
    print("static PROGMEM prog_uchar %s[] = {" % name, file=hh)
    bb = self.toarray(blk) 
    for i in range(0, len(bb), 16): 
      if (i & 0xff) == 0: 
        print("",file=hh) 
      for c in bb[i:i+16]: 
        print("0x%02x, " % c, end='', file=hh)
    print("};",file=hh)
  def decompress(self, sched): 
    s = "" 
    for c in sched: 
      if len(c) == 1: 
        s += c 
      else: 
        (offset, l) = c 
        for i in range(l): 
          s += s[offset] 
    return s 

