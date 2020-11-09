# asmgraph
Converts assembly to a graph of operations. Written in Elixir. 

`AsmGraph.graph(asm_string, opcodes)` -> `[{link_from, link_to}, link_class_info}]`
or, more specifically,
`AsmGraph.graph(asm_string, opcodes)` -> `[{link_from, link_to}, {link_class_num, link_deref_count, link_sys_level}]`

`AsmGraph.graph_sparse_adj/2` represents a flattened sparse adjacency matrix as:
`AsmGraph.graph_sparse_adj(asm_string, opcodes)` -> `[{dimension, value}]`

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
 - [ ] Convert to Sparse Adjacency Representation
