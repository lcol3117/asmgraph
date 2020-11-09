defmodule AsmLine do
    def fromString(text) do
        [op | args] = String.split(text, " ")
        [gen | uses] = args
                        |> Enum.join("")
                        |> String.split(",")
        %{op: op, gen: gen, uses: [gen | uses]}
    end
end

defmodule AsmGraph do
    def graph(asm) do
        basic_repr = asm
        		|> String.replace("syscall", "int 0x80, eax, ebx, ecx, edx")
			|> String.replace("sysenter", "int 0x80, eax, ebx, ecx, edx")
        		|> String.replace(~r<;.*\n>, "\n")
        		|> String.split("\n")
        		|> Enum.filter(& &1 != "")
			|> Enum.map(&String.trim/1)
        		|> Enum.map(&AsmLine.fromString/1)
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
		|> IO.inspect
		|> Enum.flat_map(fn {source, targets, class} ->
		    Enum.map(targets, & {
			:binary.decode_unsigned(source),
			:binary.decode_unsigned(&1),
			class
		    })
		end)
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
	{base_num, spec1, spec2, spec3} = cond do
	    reg == "0x80"			-> {1, true, true, true}
	    reg == "eip"			-> {2, true, true, true}
	    Enum.member?(segm_regs, reg)	-> {3, false, true, true}
	    (reg == "ebp" or reg == "esp")	-> {4, false, true, true}
	    Enum.member?(instr_regs, reg) 	-> {5, false, false, true}
	    reg =~ ~r<^0x.*$> 			-> {6, false, false, false}
	    reg =~ ~r<^[[:digit:]]+>		-> {7, false, false, false}
	    true 				-> {8, false, false, false}
	end
	deref_count = reg
			|> String.graphemes
			|> Enum.count(& &1 == "[")
	repr_num = base_num + (deref_count * 9)
	{repr_num, spec1 &&1||0, spec2 &&1||0, spec3 &&1||0, deref_count, base_num}
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

IO.inspect(
    AsmGraph.graph """
    dec ecx ; this is a comment
    sub ebx, ecx
    xlatb eax
    mov edx, eax
    imul ecx, edx
    syscall
    """
)
