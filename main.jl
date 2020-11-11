function read_asm_line(text)
  op, args = text |> lowercase |> split_on(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> split_on(",") |> Iterators.peel
  uses = icat(gen, unmod)
  @MakeDict op gen uses
end

split_on(delim) = x -> split(x, delim)

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

