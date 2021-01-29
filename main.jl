import MsgPack

partial(fq) = aq -> xq -> fq(xq, aq)
exval(xq) = xq != nothing
until_last(xq) = xq |> Iterators.reverse |> Iterators.peel |> Iterators.reverse
nget(xq, vq) = get(xq, vq, nothing)
nget(xq::Pair{Symbol,Any}, _vq::Symbol) = xq
splat(fq) = xq -> fq(xq...)
flatten_arrays(xq) = xq
flatten_arrays(xq::Array{Array{T,1},1}) where T = xq |> Iterators.flatten |> collect |> flatten_arrays
foldl_with(fq; kwq...) = xq -> foldl(fq, xq; kwq...)
filter_with(fq) = xq -> filter(fq, xq)
map_with(fq) = xq -> map(fq, xq)
split_with(delimq) = xq -> split(xq, delimq)
Iterators.rest(itrq::Iterators.Rest, stateq) = Iterators.Rest(itrq.itr, stateq)

function read_asm_line(text)
  op, args = text |> lowercase |> split_with(" ") |> Iterators.peel
  gen, unmod = args |> collect |> join |> split_with(",") |> Iterators.peel
  uses = [[gen] ; collect(unmod)]
  return Dict(:op => op, :gen => gen, :uses => uses)
end

function opcode_index(opcode, opcodes)
  get(opcodes, opcode, -1) + 1
end

function reg_class(reg)
  segm_regs = [
      "cs", "ds", "es",
      "fs", "gs", "ss"
  ]
  instr_regs = [
    "eax", "ebx",
    "ecx", "edx"
  ]
  repr_num =
    if reg == "0x80"
      -2
    elseif reg == "eip"
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
  dd_targets = nget(op_map, l[:uses])
  return (l[:op], exval(dd_targets) ? dd_targets : l[:uses], l[:gen])
end

function mov_like(op)
  occursin("mov", op) || (op == "lea")
end

function mov_shifting(basic_repr_raw, flow)
  basic_repr = flatten_arrays(basic_repr_raw)
  from, to = flow
  s_mod = s -> ((s == from) ? to : s)
  u_mod = x -> s -> union(x, Dict(:uses => s_mod(s))) |> splat(Dict)
  return map(x -> map(u_mod(x), x[:uses]), basic_repr)
end

function factify_uses(direct, line)
  acc, gen_map = direct
  gen = line[:gen]
  gen_v, gen_i = gen
  uses = map(x -> (x, get(gen_map, x, 0)), line[:uses])
  new_line = Dict(:op => line[:op], :gen => gen, :uses => uses)
  return ([[new_line] ; acc], union(gen_map, Dict(gen_v => gen_i)) |> splat(Dict))
end

const shifts = [
  ("jz", "je"), ("jnz", "jne"), ("iretd", "iret"), ("jnbe", "ja"), ("jnb", "jae"),
  ("jnae", "jb"), ("jna", "jbe"), ("jecxz", "jcxz"), ("jnle", "jg"), ("jnl", "jge"),
  ("jnge", "jl"), ("jng", "jle"), ("jp", "jpe"), ("jnp", "jpo"), ("loopz", "loope"),
  ("loopnz", "loopne"), ("popad", "popa"), ("popfd", "popf"), ("pushad", "pusha"), ("pushfd", "pushf"),
  ("repz", "repe"), ("repnz", "repne"), ("retf", "ret"),("shl", "sal"), ("setnbe", "seta"),
  ("setnb", "setae"), ("setnae", "setb"), ("setna", "setbe"), ("setz", "sete"), ("setnz", "setne"),
  ("setnge", "setl"), ("setng", "setle"), ("setnle", "setg"), ("setnl", "setge"), ("setp", "setpe"),
  ("setnp", "setpo"), ("shld", "shrd"), ("fwait", "wait"), ("xlatb", "xlat")
]

function op_shift(s_line)
  f_unit = (line, flow) ->
    let (from, to) = flow
      (line[:op] == from) ? union(line, Dict(:op => to)) |> splat(Dict) : line
    end
  return foldl(f_unit, shifts, init=s_line)
end

const r_mods = [
  r"\Wal" => "eax", r"\Wah" => "eax", r"\Wax" => "eax", r"\Wrax" => "eax",
  r"\Wbl" => "ebx", r"\Wbh" => "ebx", r"\Wbx" => "ebx", r"\Wrbx" => "ebx",
  r"\Wcl" => "ecx", r"\Wch" => "ecx", r"\Wcx" => "ecx", r"\Wrcx" => "ecx",
  r"\Wdl" => "edx", r"\Wdh" => "edx", r"\Wdx" => "edx", r"\Wrdx" => "edx",
  r";.*\n" => "\n", "sysenter" => "syscall", r"\Wrsp" => "esp", r"\Wrbp" => "ebp",
  r"\Wrip" => "eip", "syscall" => "int 0x80, eax, ebx, ecx, edx",
  r"xor\W+(?<a>\w+),\W+(?P=a)" => s"xorclear \g<a>",
  r"push\w? (?<a>.+?)\n" => s"movactpush esp, \g<a>, ebp\npush esp, \g<a>, ebp\n",
  r"pop\w? (?<a>.+?)\n" => s"movactpop \g<a>, esp, ebp\npop \g<a>, esp, ebp\n"
]

const dir_regexes = [
  r"\b(byte)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(sbyte)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(word)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(sword)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(dword)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(sdword)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(qword)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(tbyte)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(real4)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(real8)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(real10)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]"
]

function graph(asm, opcodes)
  start = foldl(replace,
    [map(partial(=>)(s" \g<a>"), dir_regexes) ; r_mods],
    init=asm
  )
  basic_repr = start |> split_with("\n") |> map_with(strip) |> filter_with(x -> x != "") |>
  partial(replace)(r"\ \ " => " ") |> map_with(read_asm_line) |> filter_with(x ->
    !occursin("nop", x[:op])
  ) |> map_with(op_shift) |> enumerate |> map_with(x ->
    let (index, line) = x
      union(line, Dict(:gen => (line[:gen], index))) |> splat(Dict)
    end
  ) |> foldl_with(factify_uses, init=([],Dict())) |> first |> collect
  shifted_repr = basic_repr |> filter_with(x -> mov_like(x[:op])) |>
  map_with(x -> (x[:gen], Iterators.peel(x[:uses]) |> collect)) |>
  foldl_with(mov_shifting, init=basic_repr) |> Iterators.flatten |> collect |>
  filter_with(x -> !mov_like(x[:op]))
  op_map = shifted_repr |> map_with(x -> (x[:gen] => x[:op])) |> splat(Dict)
  return shifted_repr |> filter_with(x -> !mov_like(x[:op])) |>
  map_with(x -> line_paths(x, op_map)) |> filter_with(x ->
    let (_, targets, _) = x
      targets |> collect |> isempty |> !
    end
  ) |> map_with(x -> let (source, targets, (reg, _)) = x
    (source, targets, reg_class(reg))
      end) |> filter_with(x -> isa(x[2], AbstractString)) |> unique |>
  map_with(x -> let (source, target, class) = x
      (opcode_index(source, opcodes), opcode_index(target, opcodes), class)
  end) |> collect
end

function graph_adj(asm, opcodes)
  return asm |> partial(graph)(opcodes) |> map_with(x ->
    let (source, target, class) = x
      ((length(opcodes) * source) + target) => class
    end
  ) |> splat(Dict)
end


io_opcodes_csv = open("opcodes.csv")
opcodes_csv = io_opcodes_csv |> read |> String
close(io_opcodes_csv)

opcodes = opcodes_csv |> split_with("\n") |> filter_with(x -> x != "") |>
enumerate |> collect |> map_with(x ->
  let (index, cs) = x
    split(string(cs), ",") |> map_with(s -> (s => index))
  end
) |> Iterators.flatten |> collect |> splat(Dict)

test_asm = """
dec ecx ; this is a comment
sub ebx, ecx
xlatb eax
movzx edx, eax
imul ecx, edx
hint_nop7
syscall
mov [esp+0], ebx
pop eax
syscall
"""
test_asm |> partial(graph_adj)(opcodes) |> println
test_asm |> partial(graph_adj)(opcodes) |> MsgPack.pack |> println
