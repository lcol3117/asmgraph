# asmgraph
Converts assembly to a graph of operations. Written in Elixir. **WILL MIGRATE TO JULIA SOON**

`AsmGraph.graph(asm_string, opcodes)` -> `[{link_from, link_to}, link_class_info}]`
or, more specifically,
`AsmGraph.graph(asm_string, opcodes)` -> `[{link_from, link_to}, {link_class_num, link_deref_count, link_sys_level}]`

`AsmGraph.graph_adj/2` represents a flattened sparse adjacency matrix as:
`AsmGraph.graph_adj(asm_string, opcodes)` -> `[{dimension, value}]`

Warning: The resulting data structure is sparse because it represents a **11,970,018-dimensional** vector. Please do not try to represent it densely. Your computer will thank you (by not catching fire). 

`opcodes` is a map from `String` (an opcode) to unsigned `Integer` (the number to associate with that opcode)

Note that all elements of the result are unsigned integers. 

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
