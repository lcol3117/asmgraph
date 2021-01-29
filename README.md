# asmgraph
Converts assembly to a graph of operations. Written in Julia. 

`graph_link(asm_string, opcodes_index_dict)` -> `Dict(src => target)`

`String, Dict{String,Number}` -> `Dict{Number,Number}`
