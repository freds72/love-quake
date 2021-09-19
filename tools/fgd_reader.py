import sys
import copy
from antlr4 import *
from FGDLexer import FGDLexer
from FGDParser import FGDParser
from FGDVisitor import FGDVisitor
from FGDListener import FGDListener
from collections import namedtuple
from dotdict import dotdict
from enum import IntFlag

class FGDWalker(FGDListener):     
    def __init__(self):
      self.result = []

    def exitClassdef(self, ctx):

      print("type: {} class:{}".format(ctx.classtype().getText(), ctx.classname().getText()))
      if ctx.classattribute():
        for attr in ctx.classattribute():
          s = "\t@{}".format(attr.KEYWORD().getText())
          if attr.attributeproperty():
            s += "("
            s += ",".join([prop.getText() for prop in attr.attributeproperty()])
            s += ")"
          if attr.untypedproperty():
            s += "{"
            s += ",".join(["{}={}".format(prop.QUOTED_STRING().getText(),prop.value().getText()) for prop in attr.untypedproperty()])
            s += "}"
          print(s)
          
      if ctx.tooltip():
        print("\thelp: {}".format(ctx.tooltip().getText()))
    
      for prop in ctx.classprops().typedproperty():
        pair = prop.propertyname().getText()
        if prop.valuetype():
          pair += " ({}) ".format(prop.valuetype().getText())
        if prop.value():
          pair += " = {}".format(prop.value().getText())
        print(pair)
        if prop.tooltip():
          print("\thelp: {}".format(prop.tooltip().getText()))
        if prop.option():
          for option in prop.option():
            s = "\t> {}".format(option.optionkey().getText())
            if option.tooltip():
              s += " => {}".format(option.tooltip().getText())
            print(s)

class FGDReader():
  def __init__(self, data):    
    lexer = FGDLexer(InputStream(data))
    stream = CommonTokenStream(lexer)
    parser = FGDParser(stream)
    tree = parser.blocks()
    walker = ParseTreeWalker()

    FGD_walker = FGDWalker()
    walker.walk(FGD_walker, tree)    

# if __name__ == '__main__':
#   with open("C:\\Users\\Frederic\\AppData\\Roaming\\TrenchBroom\\games\\q8k\\test.fgd",'r') as f:
#     FGDReader(f.read())

class MyErrorListener(FGDListener):
    def __init__(self, input):
        self.input = input
    def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
        print("FAILED: %s" % self.input)
        print("%d:%d %s" % (line, column, msg))
    def reportAmbiguity(self, recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs):
        print(str(startIndex) + " to " + str(stopIndex))
if __name__ == '__main__':
  filename = "C:\\Users\\Frederic\\AppData\\Roaming\\TrenchBroom\\games\\q8k\\test.fgd"
#  with open(filename, 'r') as f:
#    for l in f:
#      l = l.rstrip()
#      if len(l) < 2:
#          continue
#      istream = InputStream(l)
#      lexer = FGDLexer(istream)
#      stream = CommonTokenStream(lexer)
#      
#      # print out the token parsing
#      stream.fill()
#      print('INPUT: ' + l)
#
#      for token in stream.tokens:
#          if token.text != '<EOF>':
#            print("%s: %s" % (token.text, lexer.ruleNames[token.type]))
#
#      parser = FGDParser(stream)
#
#      parser.removeErrorListeners()

  print("--- full parsing ----")
  with open(filename,'r') as f:
    FGDReader(f.read())
