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
  asm |> partial(replace)() \
  |> partial(replace)("sysenter" => "syscall") |> partial(replace)(
    "syscall" => "int 0x80, eax, ebx, edx, ecx"
  )
end

multiple(f) = x -> map(f, x) |> foldl(|>)
partial(f) = a -> x -> f(x, a)

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
