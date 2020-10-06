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
        asm
        |> String.replace("syscall", "int 0x80")
        |> String.replace(~r/;.*\n/, "\n")
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(&AsmLine.fromString/1)
        |> Enum.with_index(1)
        |> Enum.map(fn {line, index} ->
            %{line | gen: {line[:gen], index}}
        end)
        |> Enum.reduce({[], %{}}, &factify_uses/2)
        |> elem(0)
        |> Enum.reverse
    end
    def factify_uses(%{op: op, gen: {gen_v, gen_i}, uses: uses}, {acc, gen_map}) do
        new_uses = Enum.map(uses, &({&1, gen_map[&1] <~ 0}))
        new_line = %{op: op, gen: {gen_v, gen_i}, uses: new_uses}
        {[new_line | acc], Map.put(gen_map, gen_v, gen_i)}
    end
    def nilable <~ alt do
        if nilable == nil do
            alt
        else
            nilable
        end
    end
end

IO.inspect(
    AsmGraph.graph """
    mov eax, ebx; this is a comment
    mov ebx, ecx
    inc eax
    sub ecx, eax
    syscall
    """
)
