# asmgraph
Converts assembly to a graph of operations. Written in Elixir. **WILL MIGRATE TO JULIA SOON**

`AsmGraph.graph(asm_string, opcodes)` -> `[{link_from, link_to}, link_class}]`

`AsmGraph.graph_adj/2` represents a flattened sparse adjacency matrix as:
`AsmGraph.graph_adj(asm_string, opcodes)` -> `[{dimension, value}]`

`opcodes` is a map from `String` (an opcode) to unsigned `Integer` (the number to associate with that opcode)

Note that all elements of the result are unsigned integers except for `link_class`, which is signed. 

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
 - [X] Convert to Sparse Adjacency Representation
