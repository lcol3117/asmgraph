function read_asm_line(text)
  op, args = text |> lowercase |> partial(split)(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> partial(split)(",") |> Iterators.peel
  uses = icat(gen, unmod)
  @MakeDict op gen uses
end

function graph_adj(asm, opcodes)
  asm |> graph_with(opcodes) |> map_with(x ->
    let (source => target) => class = x
      (length(opcodes) * source) + target => class
    end
  ) |> Dict
end

graph_with(opcodes) = x -> graph(x, opcodes)

function graph(asm, opcodes)
  asm |> (replace |> partial |> multiple)([
    "al" => "eax", "ah" => "eax", "ax" => "eax",
    "bl" => "ebx", "bh" => "ebx", "bx" => "ebx",
    "cl" => "ecx", "ch" => "ecx", "cx" => "ecx",
    "dl" => "edx", "dh" => "edx", "dx" => "edx",
    r";.*\n" => "\n", "sysenter" => "syscall",
    "syscall" => "int 0x80, eax, ebx, ecx, edx"
  ]) |> partial(split)("\n") |> filter_with(x -> x != "") |>
    map_with(read_asm_line) |> filter_with(x ->
      occursin("nop", x[:op])
    ) |> map_with(op_shift) |> enumerate |> 
end

multiple(f) = f -> m -> b -> foldl(|>, map(f, m), init=b)
partial(f) = a -> x -> f(x, a)

filter_with(f) = x -> filter(f, x)

Iterators.rest(itr::Iterators.Rest, state) = Iterators.Rest(itr.itr, state)

icat(args...) = Iterators.flatten(args)

function PairExpr(x)
  return quote
    $(Meta.quot(x)) => $x
  end
end

macro MakeDict(args...)
  dict_args = map(PairExpr, args) |> collect
  return quote
    Dict($(dict_args...))
  end
end

map_with(f) = x -> map(f, x)
