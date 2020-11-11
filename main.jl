function read_asm_line(text)
  op, args = text |> lowercase |> split_with(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> split_with(",") |> Iterators.peel
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
  #?
end

split_with(delim) = x -> split(x, delim)

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
