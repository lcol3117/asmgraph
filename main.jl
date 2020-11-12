multiple(f) = f -> m -> b -> foldl(|>, map(f, m), init=b)
partial(f) = a -> x -> f(x, a)
exval(x) = x != nothing
until_last(x) = x |> Iterators.reverse |> Iterators.peel |> Iterators.reverse
nget(x, v) = get(x, v, nothing)
splat(f) = x -> f(x...)
foldl_with(f; kw...) = x -> foldl(f, x; kw...)
filter_with(f) = x -> filter(f, x)
map_with(f) = x -> map(f, x)
split_with(delim) = x -> split(x, delim)
Iterators.rest(itr::Iterators.Rest, state) = Iterators.Rest(itr.itr, state)

function PairExpr(x)
  return quote
    $(Meta.quot(x)) => $x
  end
end

macro MakeDict(args...)
  dict_args = args |> map_with(PairExpr) |> collect
  return quote
    Dict($(dict_args...))
  end
end

function read_asm_line(text)
  op, args = text |> lowercase |> split_with(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> split_with(",") |> Iterators.peel
  uses = [[gen] ; unmod]
  return @MakeDict op gen uses
end

function opcode_index(opcode, opcodes)
  get(opcodes, opcode, -1) + 1
end

function reg_class(reg)
  segm_regs = [
	    "cs", "ds", "es",
	    "fs", "gs", "ss"
	]
	instr_ptr = [
	    "ip", "eip", "rip"
	]
	repr_num =
  if reg == "0x80"
    -2
  elseif reg in instr_ptr
    -1
  elseif reg in segm_regs
    1
  elseif (reg == "ebp" || reg == "esp")
    2
  elseif reg in instr_regs
    3
  elseif match(r"^0x.*$", reg)
    4
  elseif match(r"^\d+", reg)
    5
  else
    6
  end
  deref_count = count(partial(==)("["), reg)
  return repr_num + (deref_count * 7)
end

function line_paths(l, op_map)
  targets = l[:uses] |> map_with(x -> nget(op_map, x)) |> filter_with(exval)
  return (op, targets, gen)
end

function mov_like(op)
  occursin("mov", op) || (op == "lea")
end

function mov_shifting(flow, basic_repr)
  from, to = flow
  map(x -> push(x, :uses => map(s -> (s == from) ? to : s, x[:uses])), basic_repr)
end

function factify_uses(line, direct)
  acc, gen_map = direct
  gen = line[:gen]
  gen_v, gen_i = gen
  uses = map(x -> (x, get(gen_map, x, 0)), line[:uses])
  new_line = @MakeDict op gen uses
  return ([[new_line] ; acc], push(gen_map, gen_v, gen_i))
end

const shifts = [
  ("jz", "je"),
  ("jnz", "jne"),
  ("iretd", "iret"),
  ("jnbe", "ja"),
  ("jnb", "jae"),
  ("jnae", "jb"),
  ("jna", "jbe"),
  ("jecxz", "jcxz"),
  ("jnle", "jg"),
  ("jnl", "jge"),
  ("jnge", "jl"),
  ("jng", "jle"),
  ("jp", "jpe"),
  ("jnp", "jpo"),
  ("loopz", "loope"),
  ("loopnz", "loopne"),
  ("popad", "popa"),
  ("popfd", "popf"),
  ("pushad", "pusha"),
  ("pushfd", "pushf"),
  ("repz", "repe"),
  ("repnz", "repne"),
  ("retf", "ret"),
  ("shl", "sal"),
  ("setnbe", "seta"),
  ("setnb", "setae"),
  ("setnae", "setb"),
  ("setna", "setbe"),
  ("setz", "sete"),
  ("setnz", "setne"),
  ("setnge", "setl"),
  ("setng", "setle"),
  ("setnle", "setg"),
  ("setnl", "setge"),
  ("setp", "setpe"),
  ("setnp", "setpo"),
  ("shld", "shrd"),
  ("fwait", "wait"),
  ("xlatb", "xlat")
]

function op_shift(line)
  foldl(shifts, (flow, line) -> let (from, to) = flow
    (line[:op] == from) ? push(line, :op => to) : line
  end, init=line)
end

function graph(asm, opcodes)
  basic_repr = asm |> (replace |> partial |> multiple)([
    "al" => "eax", "ah" => "eax", "ax" => "eax",
    "bl" => "ebx", "bh" => "ebx", "bx" => "ebx",
    "cl" => "ecx", "ch" => "ecx", "cx" => "ecx",
    "dl" => "edx", "dh" => "edx", "dx" => "edx",
    r";.*\n" => "\n", "sysenter" => "syscall",
    "syscall" => "int 0x80, eax, ebx, ecx, edx"
  ]) |> split_with("\n") |> map_with(strip) |> filter_with(x -> x != "") |>
  map_with(read_asm_line) |> filter_with(x ->
    occursin("nop", x[:op])
  ) |> map_with(op_shift) |> enumerate |> map_with(x ->
    let (index, line) = x
      push(line, :gen => (line[:gen], index))
    end
  ) |> foldl_with(factify_uses, init=([],Dict())) |>
  first |> collect |> reverse
  shifted_repr = basic_repr |> filter_with(x -> mov_like(x[:op])) |>
  map_with(x -> (x[:gen], Iterators.peel(x[:uses]))) |>
  foldl_with(mov_shifting, init=basic_repr) |> filter_with(x -> !mov_like(x[:op]))
  op_map = shifted_repr |> map_with(x -> (x[:gen], x[:op])) |> splat(Dict)
  return shifted_repr |> filter_with(x -> !mov_like(x[:op])) |>
  (line_paths |> partial |> map_with) |> filter_with(x ->
    let (_, targets, _) = x
      targets |> collect |> isempty |> !
    end
  ) |> map_with(x -> let (source, targets, (reg, _)) = x
    (source, unique(targets), reg_class(reg))
  end) |> unique |> map_with(x -> let (source, targets, class) = x
      map(s -> (opcode_index(source, opcodes), opcode_index(s, opcodes), class))
	end) |> Iterators.flatten |> map_with(x -> let (source, targets, class) = x
    (source, targets, class)
  end)
end

function graph_adj(asm, opcodes)
  return asm |> partial(graph)(opcodes) |> map_with(x ->
    let (source, target, class) = x
      ((length(opcodes) * source) + target) => class
    end
  ) |> splat(Dict)
end


io_opcodes_csv = open("opcodes.csv", "r")
opcodes_csv = read(io_opcodes_csv, String)
close(io_opcodes_csv)

sp(x) = let
	println(x)
	x
end

opcodes = opcodes_csv |> split_with("\n") |> filter_with(x -> x != "") |>
enumerate |> collect |> map_with(x ->
  let (index, cs) = x
    if isa(cs, String)
      cs |> typeof |> println
      cs |> split_with(",") |> map_with(s -> (s => index))
    else
      []
    end
  end
) |> Iterators.flatten |> splat(Dict)

"""
dec ecx ; this is a comment
sub ebx, ecx
xlatb eax
movzx edx, eax
imul ecx, edx
hint_nop7
syscall
""" |> partial(graph_adj)(opcodes) |> println
