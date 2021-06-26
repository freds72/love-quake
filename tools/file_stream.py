import os
import io
from contextlib import contextmanager
from typing import List
from abstract_stream import Stream
from pathlib import Path

# filebased resource stream
class FileStream(Stream):
  def __init__(self, basepath):
    self.root = basepath

  # read a file from root directory  
  @contextmanager
  def read(self, name) -> io.RawIOBase:    
    filename = os.path.join(self.root, name)
    with open(filename, 'rb') as file:
      yield file   