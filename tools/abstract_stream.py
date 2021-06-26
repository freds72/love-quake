from abc import ABC, abstractmethod
from contextlib import AbstractContextManager
from io import RawIOBase
from typing import List
# abstract class to work with resources (WAD or file based)
class Stream(AbstractContextManager):
  # read resource 'name'
  # returns a bytearray
  
  @abstractmethod
  def read(self, name) -> RawIOBase:
    pass

  # support with/as context
  def __enter__(self):
    return self
  def __exit__(self, type, value, traceback):
    pass  