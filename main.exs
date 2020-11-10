defmodule AsmLine do
    def fromString(text) do
        [op | args] = text
			|> String.downcase
			|> String.split(" ")
        [gen | uses] = args
                        |> Enum.join("")
                        |> String.split(",")
        %{op: op, gen: gen, uses: [gen | uses]}
    end
end

defmodule AsmGraph do
    def graph_adj(asm, opcodes) do
    	num_opcodes = map_size opcodes
    	asm
	    |> graph(opcodes)
	    |> Enum.map(fn {{source, target}, class} ->
		{(num_opcodes * source) + target, class}
	    end)
	    |> Map.new
    end
    def graph(asm, opcodes) do
        basic_repr = asm
        		|> String.replace("syscall", "int 0x80, eax, ebx, ecx, edx")
			|> String.replace("sysenter", "int 0x80, eax, ebx, ecx, edx")
        		|> String.replace(~r<;.*\n>, "\n")
        		|> String.split("\n")
        		|> Enum.filter(& &1 != "")
			|> Enum.map(&String.trim/1)
        		|> Enum.map(&AsmLine.fromString/1)
			|> Enum.reject(fn %{op: op} ->
			    String.contains?(op, "nop")
			end)
        		|> Enum.map(&op_shift/1)
        		|> Enum.with_index(1)
        		|> Enum.map(fn {line, index} ->
        		    %{line | gen: {line[:gen], index}}
        		end)
        		|> Enum.reduce({[], %{}}, &factify_uses/2)
        		|> elem(0)
        		|> Enum.reverse
	shifted_repr = basic_repr
			|> Enum.filter(fn %{op: op} -> mov_like(op) end)
			|> Enum.map(fn %{gen: gen, uses: [_, use]} -> {gen, use} end)
			|> Enum.reduce(basic_repr, &mov_shifting/2)
			|> Enum.filter(fn %{op: op} -> not mov_like(op) end)
	op_map = shifted_repr
			    |> Enum.map(fn %{op: op, gen: gen} -> {gen, op} end)
			    |> Map.new
	shifted_repr
		|> Enum.filter(fn %{op: op} -> op != "mov" end)
		|> Enum.map(&line_paths(&1, op_map))
		|> Enum.filter(fn {_, targets, _} -> targets != [] end)
		|> Enum.map(fn {source, targets, {reg, _}} -> {
		    source,
		    Enum.uniq(targets),
		    reg_class(reg)
		} end)
		|> Enum.uniq
		|> Enum.flat_map(fn {source, targets, class} ->
		    Enum.map(targets, & {
			opcode_index(source, opcodes),
			opcode_index(&1, opcodes),
			class
		    })
		end)
		|> Enum.map(fn {source, target, class} ->
		    {{source, target}, class}
		end)
    end
    def opcode_index(opcode, opcodes) do
    	(opcodes[opcode] + 1) || 0
    end
    def reg_class(reg) do
	instr_regs = [
	    "eax", "ax", "al", "ah",
	    "ebx", "bx", "bl", "bh",
	    "ecx", "cx", "cl", "ch",
	    "edx", "dx", "dl", "dh"
	]
	segm_regs = [
	    "cs", "ds", "es",
	    "fs", "gs", "ss"
	]
	instr_ptr = [
	    "ip", "eip", "rip"
	]
	repr_num = cond do
	    reg == "0x80"			-> -2
	    Enum.member?(instr_ptr, reg)	-> -1
	    Enum.member?(segm_regs, reg)	-> 1
	    (reg == "ebp" or reg == "esp")	-> 2
	    Enum.member?(instr_regs, reg) 	-> 3
	    reg =~ ~r<^0x.*$> 			-> 4
	    reg =~ ~r<^[[:digit:]]+>		-> 5
	    true 				-> 6
	end
	deref_count = reg
			|> String.graphemes
			|> Enum.count(& &1 == "[")
	repr_num + (deref_count * 7)
    end
    def line_paths(%{op: op, gen: gen, uses: uses}, op_map) do
        targets = uses
		    |> Enum.map(&Map.get(op_map, &1))
		    |> Enum.filter(& &1 != nil)
	{op, targets, gen}
    end
    def mov_like(op) do
    	String.contains?(op, "mov") or (op == "lea")
    end
    def mov_shifting({from, to}, basic_repr) do
	Enum.map(basic_repr, & %{&1 | uses: Enum.map(&1[:uses], fn x ->
	    if x == from do
		to
	    else
		x
	    end
	end)})
    end
    def factify_uses(%{op: op, gen: {gen_v, gen_i}, uses: uses}, {acc, gen_map}) do
        new_uses = Enum.map(uses, & {&1, Map.get(gen_map, &1, 0)})
        new_line = %{op: op, gen: {gen_v, gen_i}, uses: new_uses}
        {[new_line | acc], Map.put(gen_map, gen_v, gen_i)}
    end
    def op_shift(line) do
        shifts = [
            {"jz", "je"},
            {"jnz", "jne"},
            {"iretd", "iret"},
            {"jnbe", "ja"},
            {"jnb", "jae"},
            {"jnae", "jb"},
            {"jna", "jbe"},
            {"jecxz", "jcxz"},
            {"jnle", "jg"},
            {"jnl", "jge"},
            {"jnge", "jl"},
            {"jng", "jle"},
            {"jp", "jpe"},
            {"jnp", "jpo"},
            {"loopz", "loope"},
            {"loopnz", "loopne"},
            {"popad", "popa"},
            {"popfd", "popf"},
            {"pushad", "pusha"},
            {"pushfd", "pushf"},
            {"repz", "repe"},
            {"repnz", "repne"},
            {"retf", "ret"},
            {"shl", "sal"},
            {"setnbe", "seta"},
            {"setnb", "setae"},
            {"setnae", "setb"},
            {"setna", "setbe"},
            {"setz", "sete"},
            {"setnz", "setne"},
            {"setnge", "setl"},
            {"setng", "setle"},
            {"setnle", "setg"},
            {"setnl", "setge"},
            {"setp", "setpe"},
            {"setnp", "setpo"},
            {"shld", "shrd"},
            {"fwait", "wait"},
            {"xlatb", "xlat"}
        ]
        Enum.reduce(shifts, line, fn {from, to}, line ->
            if line[:op] == from do
                %{line | op: to}
            else
                line
            end
        end)
    end
end

opcodes =
    with {:ok, opcodes_txt} <- File.read("opcodes.csv") do
	opcodes_txt
		|> String.split("\n")
		|> Enum.with_index
		|> Enum.map(fn {cs, index} ->
		    Enum.map(
		    	String.split(cs, ","),
			&{&1, index}
		    )
		end)
		|> Enum.flat_map(&Function.identity/1)
		|> Map.new
    else
    	{:error, :enoent} -> raise "Cannot find opcodes.csv (enoent)"
	{:error, reason} -> raise "Unable to read opcodes.csv because #{inspect reason}"
	other -> raise "Unable to read opcodes.csv, invalid return #{inspect other}"
    end

"""
dec ecx ; this is a comment
sub ebx, ecx
xlatb eax
movzx edx, eax
imul ecx, edx
hint_nop7
syscall
"""
|> AsmGraph.graph_adj(opcodes)
|> IO.inspect
