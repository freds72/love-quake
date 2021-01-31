# Generated from ENTITY.g4 by ANTLR 4.8
# encoding: utf-8
from antlr4 import *
from io import StringIO
import sys
if sys.version_info[1] > 5:
	from typing import TextIO
else:
	from typing.io import TextIO


def serializedATN():
    with StringIO() as buf:
        buf.write("\3\u608b\ua72a\u8133\ub9ed\u417c\u3be7\u7786\u5964\3\b")
        buf.write("%\4\2\t\2\4\3\t\3\4\4\t\4\4\5\t\5\4\6\t\6\3\2\7\2\16\n")
        buf.write("\2\f\2\16\2\21\13\2\3\2\3\2\3\3\3\3\7\3\27\n\3\f\3\16")
        buf.write("\3\32\13\3\3\3\3\3\3\4\3\4\3\4\3\5\3\5\3\6\3\6\3\6\2\2")
        buf.write("\7\2\4\6\b\n\2\2\2!\2\17\3\2\2\2\4\24\3\2\2\2\6\35\3\2")
        buf.write("\2\2\b \3\2\2\2\n\"\3\2\2\2\f\16\5\4\3\2\r\f\3\2\2\2\16")
        buf.write("\21\3\2\2\2\17\r\3\2\2\2\17\20\3\2\2\2\20\22\3\2\2\2\21")
        buf.write("\17\3\2\2\2\22\23\7\2\2\3\23\3\3\2\2\2\24\30\7\3\2\2\25")
        buf.write("\27\5\6\4\2\26\25\3\2\2\2\27\32\3\2\2\2\30\26\3\2\2\2")
        buf.write("\30\31\3\2\2\2\31\33\3\2\2\2\32\30\3\2\2\2\33\34\7\4\2")
        buf.write("\2\34\5\3\2\2\2\35\36\5\b\5\2\36\37\5\n\6\2\37\7\3\2\2")
        buf.write("\2 !\7\5\2\2!\t\3\2\2\2\"#\7\5\2\2#\13\3\2\2\2\4\17\30")
        return buf.getvalue()


class ENTITYParser ( Parser ):

    grammarFileName = "ENTITY.g4"

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    sharedContextCache = PredictionContextCache()

    literalNames = [ "<INVALID>", "'{'", "'}'" ]

    symbolicNames = [ "<INVALID>", "<INVALID>", "<INVALID>", "QUOTED_STRING", 
                      "BLOCKCOMMENT", "LINECOMMENT", "WS" ]

    RULE_actors = 0
    RULE_block = 1
    RULE_pair = 2
    RULE_keyword = 3
    RULE_args = 4

    ruleNames =  [ "actors", "block", "pair", "keyword", "args" ]

    EOF = Token.EOF
    T__0=1
    T__1=2
    QUOTED_STRING=3
    BLOCKCOMMENT=4
    LINECOMMENT=5
    WS=6

    def __init__(self, input:TokenStream, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.8")
        self._interp = ParserATNSimulator(self, self.atn, self.decisionsToDFA, self.sharedContextCache)
        self._predicates = None




    class ActorsContext(ParserRuleContext):

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def EOF(self):
            return self.getToken(ENTITYParser.EOF, 0)

        def block(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(ENTITYParser.BlockContext)
            else:
                return self.getTypedRuleContext(ENTITYParser.BlockContext,i)


        def getRuleIndex(self):
            return ENTITYParser.RULE_actors

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterActors" ):
                listener.enterActors(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitActors" ):
                listener.exitActors(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitActors" ):
                return visitor.visitActors(self)
            else:
                return visitor.visitChildren(self)




    def actors(self):

        localctx = ENTITYParser.ActorsContext(self, self._ctx, self.state)
        self.enterRule(localctx, 0, self.RULE_actors)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 13
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while _la==ENTITYParser.T__0:
                self.state = 10
                self.block()
                self.state = 15
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 16
            self.match(ENTITYParser.EOF)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class BlockContext(ParserRuleContext):

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def pair(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(ENTITYParser.PairContext)
            else:
                return self.getTypedRuleContext(ENTITYParser.PairContext,i)


        def getRuleIndex(self):
            return ENTITYParser.RULE_block

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBlock" ):
                listener.enterBlock(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBlock" ):
                listener.exitBlock(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBlock" ):
                return visitor.visitBlock(self)
            else:
                return visitor.visitChildren(self)




    def block(self):

        localctx = ENTITYParser.BlockContext(self, self._ctx, self.state)
        self.enterRule(localctx, 2, self.RULE_block)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 18
            self.match(ENTITYParser.T__0)
            self.state = 22
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while _la==ENTITYParser.QUOTED_STRING:
                self.state = 19
                self.pair()
                self.state = 24
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 25
            self.match(ENTITYParser.T__1)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class PairContext(ParserRuleContext):

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def keyword(self):
            return self.getTypedRuleContext(ENTITYParser.KeywordContext,0)


        def args(self):
            return self.getTypedRuleContext(ENTITYParser.ArgsContext,0)


        def getRuleIndex(self):
            return ENTITYParser.RULE_pair

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterPair" ):
                listener.enterPair(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitPair" ):
                listener.exitPair(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitPair" ):
                return visitor.visitPair(self)
            else:
                return visitor.visitChildren(self)




    def pair(self):

        localctx = ENTITYParser.PairContext(self, self._ctx, self.state)
        self.enterRule(localctx, 4, self.RULE_pair)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 27
            self.keyword()
            self.state = 28
            self.args()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class KeywordContext(ParserRuleContext):

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def QUOTED_STRING(self):
            return self.getToken(ENTITYParser.QUOTED_STRING, 0)

        def getRuleIndex(self):
            return ENTITYParser.RULE_keyword

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterKeyword" ):
                listener.enterKeyword(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitKeyword" ):
                listener.exitKeyword(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitKeyword" ):
                return visitor.visitKeyword(self)
            else:
                return visitor.visitChildren(self)




    def keyword(self):

        localctx = ENTITYParser.KeywordContext(self, self._ctx, self.state)
        self.enterRule(localctx, 6, self.RULE_keyword)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 30
            self.match(ENTITYParser.QUOTED_STRING)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArgsContext(ParserRuleContext):

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def QUOTED_STRING(self):
            return self.getToken(ENTITYParser.QUOTED_STRING, 0)

        def getRuleIndex(self):
            return ENTITYParser.RULE_args

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArgs" ):
                listener.enterArgs(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArgs" ):
                listener.exitArgs(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArgs" ):
                return visitor.visitArgs(self)
            else:
                return visitor.visitChildren(self)




    def args(self):

        localctx = ENTITYParser.ArgsContext(self, self._ctx, self.state)
        self.enterRule(localctx, 8, self.RULE_args)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 32
            self.match(ENTITYParser.QUOTED_STRING)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx





