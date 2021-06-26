# Generated from ENTITY.g4 by ANTLR 4.9.2
from antlr4 import *
from io import StringIO
import sys
if sys.version_info[1] > 5:
    from typing import TextIO
else:
    from typing.io import TextIO



def serializedATN():
    with StringIO() as buf:
        buf.write("\3\u608b\ua72a\u8133\ub9ed\u417c\u3be7\u7786\u5964\2\b")
        buf.write("T\b\1\4\2\t\2\4\3\t\3\4\4\t\4\4\5\t\5\4\6\t\6\4\7\t\7")
        buf.write("\4\b\t\b\4\t\t\t\4\n\t\n\4\13\t\13\3\2\3\2\3\3\3\3\3\4")
        buf.write("\3\4\6\4\36\n\4\r\4\16\4\37\3\4\3\4\3\5\3\5\3\6\3\6\3")
        buf.write("\7\3\7\3\b\3\b\3\b\3\b\3\b\3\b\3\b\3\b\3\b\5\b\63\n\b")
        buf.write("\3\t\3\t\3\t\3\t\7\t9\n\t\f\t\16\t<\13\t\3\t\3\t\3\t\3")
        buf.write("\t\3\t\3\n\3\n\3\n\3\n\7\nG\n\n\f\n\16\nJ\13\n\3\n\3\n")
        buf.write("\3\13\6\13O\n\13\r\13\16\13P\3\13\3\13\3:\2\f\3\3\5\4")
        buf.write("\7\5\t\2\13\2\r\2\17\2\21\6\23\7\25\b\3\2\6\6\2\f\f\17")
        buf.write("\17$$^^\5\2C\\aac|\4\2\f\f\17\17\5\2\13\f\17\17\"\"\2")
        buf.write("T\2\3\3\2\2\2\2\5\3\2\2\2\2\7\3\2\2\2\2\21\3\2\2\2\2\23")
        buf.write("\3\2\2\2\2\25\3\2\2\2\3\27\3\2\2\2\5\31\3\2\2\2\7\33\3")
        buf.write("\2\2\2\t#\3\2\2\2\13%\3\2\2\2\r\'\3\2\2\2\17\62\3\2\2")
        buf.write("\2\21\64\3\2\2\2\23B\3\2\2\2\25N\3\2\2\2\27\30\7}\2\2")
        buf.write("\30\4\3\2\2\2\31\32\7\177\2\2\32\6\3\2\2\2\33\35\7$\2")
        buf.write("\2\34\36\n\2\2\2\35\34\3\2\2\2\36\37\3\2\2\2\37\35\3\2")
        buf.write("\2\2\37 \3\2\2\2 !\3\2\2\2!\"\7$\2\2\"\b\3\2\2\2#$\4C")
        buf.write("\\\2$\n\3\2\2\2%&\t\3\2\2&\f\3\2\2\2\'(\4\62;\2(\16\3")
        buf.write("\2\2\2)*\7v\2\2*+\7t\2\2+,\7w\2\2,\63\7g\2\2-.\7h\2\2")
        buf.write("./\7c\2\2/\60\7n\2\2\60\61\7u\2\2\61\63\7g\2\2\62)\3\2")
        buf.write("\2\2\62-\3\2\2\2\63\20\3\2\2\2\64\65\7\61\2\2\65\66\7")
        buf.write(",\2\2\66:\3\2\2\2\679\13\2\2\28\67\3\2\2\29<\3\2\2\2:")
        buf.write(";\3\2\2\2:8\3\2\2\2;=\3\2\2\2<:\3\2\2\2=>\7,\2\2>?\7\61")
        buf.write("\2\2?@\3\2\2\2@A\b\t\2\2A\22\3\2\2\2BC\7\61\2\2CD\7\61")
        buf.write("\2\2DH\3\2\2\2EG\n\4\2\2FE\3\2\2\2GJ\3\2\2\2HF\3\2\2\2")
        buf.write("HI\3\2\2\2IK\3\2\2\2JH\3\2\2\2KL\b\n\2\2L\24\3\2\2\2M")
        buf.write("O\t\5\2\2NM\3\2\2\2OP\3\2\2\2PN\3\2\2\2PQ\3\2\2\2QR\3")
        buf.write("\2\2\2RS\b\13\2\2S\26\3\2\2\2\b\2\37\62:HP\3\b\2\2")
        return buf.getvalue()


class ENTITYLexer(Lexer):

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    T__0 = 1
    T__1 = 2
    QUOTED_STRING = 3
    BLOCKCOMMENT = 4
    LINECOMMENT = 5
    WS = 6

    channelNames = [ u"DEFAULT_TOKEN_CHANNEL", u"HIDDEN" ]

    modeNames = [ "DEFAULT_MODE" ]

    literalNames = [ "<INVALID>",
            "'{'", "'}'" ]

    symbolicNames = [ "<INVALID>",
            "QUOTED_STRING", "BLOCKCOMMENT", "LINECOMMENT", "WS" ]

    ruleNames = [ "T__0", "T__1", "QUOTED_STRING", "AZ", "CHAR", "DIGIT", 
                  "BOOLEAN", "BLOCKCOMMENT", "LINECOMMENT", "WS" ]

    grammarFileName = "ENTITY.g4"

    def __init__(self, input=None, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.9.2")
        self._interp = LexerATNSimulator(self, self.atn, self.decisionsToDFA, PredictionContextCache())
        self._actions = None
        self._predicates = None


