// set CLASSPATH=antlr-4.9-complete.jar
// java org.antlr.v4.Tool -Dlanguage=Python3 -visitor -listener FGD.g4

// $env:Path += ";D:\Java\jdk-15.0.1\bin"
// $env:CLASSPATH="antlr-4.9.2-complete.jar"

// help: https://developer.valvesoftware.com/wiki/FGD

grammar FGD;

// parser
blocks:
  classdef* EOF
  ;

classdef:
  '@' classtype classattribute* '=' classname (':' tooltip)? classprops
  ;

classtype:
  KEYWORD
  ;

classattribute:
  KEYWORD '(' (
    (vectorproperty (',' vectorproperty)*) |
    (attributeproperty (',' attributeproperty)*) |
    ('{' untypedproperty* '}'))
  ')'
  ;

attributeproperty:
  KEYWORD |
  NUMBER |
  QUOTED_STRING
  ;

vectorproperty:
  NUMBER NUMBER NUMBER
  ;

classname:
  KEYWORD
  ;

tooltip:
  QUOTED_STRING ('+' QUOTED_STRING)*
  ;

classprops:
  '[' typedproperty* ']'
  ;

untypedproperty:
  QUOTED_STRING ':' value
  ;

typedproperty:
  propertyname '(' valuetype ')' (
    (':' ':' value) |
    (':' tooltip ':' value) |
    (':' tooltip ))? 
  ('=' '[' option* ']')?
  ;
  
option:
  optionkey (
    (':' ':' value) | 
    (':' tooltip ':' value) | 
    (':' tooltip))
  ;

valuetype:
  KEYWORD
  ;

propertyname:  
  KEYWORD
  ;

value:  
  NUMBER |
  QUOTED_STRING
  ;

optionkey:  
  NUMBER |
  QUOTED_STRING
  ;

// lexer
NUMBER
  : '-'? DIGIT+ ('.' DIGIT+)?
  ;

QUOTED_STRING:
  '"' (~('"' | '\\' | '\r' | '\n') )+ '"'
  ;

KEYWORD:
  CHAR (CHAR|DIGIT)*
  ;

fragment CHAR:
  ('a'..'z'|'A'..'Z'|'_')
  ;

fragment DIGIT
  : ('0'..'9')
  ;

fragment BOOLEAN
  : ('true' | 'false')
  ;

BLOCKCOMMENT
   : '/*' .*? '*/' -> skip
   ;

LINECOMMENT
   : '//' ~ [\r\n]* -> skip
   ;

WS
   : [ \t\n\r] + -> skip
   ;