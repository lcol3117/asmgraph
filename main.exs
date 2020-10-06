defmodule AsmLine do
    def fromString(text) do
        [op | args] = String.split(text, " ")
        [gen | uses] = args
                        |> Enum.join("")
                        |> String.split(",")
        %{op: op, gen: gen, uses: uses}
    end
end

defmodule AsmGraph do
    def graph(asm) do
        basic_repr = asm
        		|> String.replace("syscall", "int 0x80, eax, ebx, ecx, edx")
        		|> String.replace(~r/;.*\n/, "\n")
        		|> String.split("\n")
        		|> Enum.filter(&(&1 != ""))
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
        op_map = basic_repr
			|> Enum.map(fn %{op: op, gen: gen} -> {gen, op} end)
			|> Map.new
	basic_repr
        	|> Enum.map(&line_paths(&1, op_map))
		|> Enum.filter(fn {_, targets} -> targets != [] end)
    end
    def line_paths(%{op: op, uses: uses}, op_map) do
        targets = uses
		    |> Enum.map(&(Map.get(op_map, &1)))
		    |> Enum.filter(&(&1 != nil))
	{op, targets}
    end
    def factify_uses(%{op: op, gen: {gen_v, gen_i}, uses: uses}, {acc, gen_map}) do
        new_uses = Enum.map(uses, &({&1, Map.get(gen_map, &1, 0)}))
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
    imul ecx, eax
    syscall
    """
)
