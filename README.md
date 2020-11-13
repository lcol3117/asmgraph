# asmgraph
Converts assembly to a graph of operations. Written in Julia. 

`graph_adj(asm_string, opcodes_index_dict)` -> `Dict(dimension => value)`

`String, Dict{String,Number}` -> `Dict{Number,Number}`
