# asmgraph
Converts assembly to a graph of operations. Written in Elixir. 

`AsmGraph.graph(asm_string)` -> `[{link_from, link_to, link_class}]`

Steps:

 - [X] Use EAsm to make assembly easier to parse
 - [X] Operator shifting
 - [X] Parse Assembly as data
 - [X] Convert data to facts
 - [X] Link facts
 - [X] Handle Moves
 - [X] Get Class Information
 - [X] Graph
 - [X] Make Numeric

