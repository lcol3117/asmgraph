function read_asm_line(text)
  op, args = text |> lowercase |> partial(split)(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> partial(split)(",") |> Iterators.peel
  uses = icat(gen, unmod)
  return @MakeDict op gen uses
end

function graph_adj(asm, opcodes)
  return asm |> graph_with(opcodes) |> map_with(x ->
    let (source => target) => class = x
      (length(opcodes) * source) + target => class
    end
  ) |> splat(Dict)
end

graph_with(opcodes) = x -> graph(x, opcodes)

function graph(asm, opcodes)
  basic_repr = asm |> (replace |> partial |> multiple)([
    "al" => "eax", "ah" => "eax", "ax" => "eax",
    "bl" => "ebx", "bh" => "ebx", "bx" => "ebx",
    "cl" => "ecx", "ch" => "ecx", "cx" => "ecx",
    "dl" => "edx", "dh" => "edx", "dx" => "edx",
    r";.*\n" => "\n", "sysenter" => "syscall",
    "syscall" => "int 0x80, eax, ebx, ecx, edx"
  ]) |> partial(split)("\n") |> filter_with(x -> x != "") |>
  map_with(read_asm_line) |> filter_with(x ->
    occursin("nop", x[:op])
  ) |> map_with(op_shift) |> enumerate |> map_with(x ->
    let index, line = x
      push!(line, :gen => (line[:gen], index))
    end
  ) |> foldl_with(factify_uses, init=([],Dict())) |>
  first |> collect |> reverse
  shifted_repr = basic_repr |> filter_with(x -> mov_like(x[:op])) |>
  map_with(x -> (x[:gen], Iterators.peel(x[:uses]))) |>
  foldl_with(mov_shifting, init=basic_repr) |>
  filter_with(x -> !mov_like(x[:op]))
  op_map = shifted_repr |> map_with(x -> x[:gen] => x[:op]) |> splat(Dict)
  return shifted_repr |> filter_with(x -> !mov_like(x[:op])) |>
  (line_paths |> partial |> map_with) |> filter_with(x ->
    let _, targets, _ = x
      targets |> collect |> isempty |> !
    end
  ) |> map_with(x -> let source, targets, (reg, _)
    (source, unique(targets), reg_class(reg))
  end
  ) |> unique |> map_with(x ->
    let source, targets, class = x
      map(s -> (opcode_index(source, opcodes), opcode_index(s, opcodes), class))
    end
  ) |> Iterators.flatten |> map_with(x -> let source, targets, class = x)
end

multiple(f) = f -> m -> b -> foldl(|>, map(f, m), init=b)
partial(f) = a -> x -> f(x, a)

splat(f) = x -> f(x...)

foldl_with(f; kw...) = x -> foldl(f, x; kw...)

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