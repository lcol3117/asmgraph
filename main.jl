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
  return get(opcodes, opcode, -1) + 1
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
  @show start
  basic_repr = start |> split_with("\n") |> map_with(strip) |> filter_with(x -> x != "") |>
  partial(replace)(r"\ \ " => " ") |> map_with(read_asm_line) |> filter_with(x ->
    !occursin("nop", x[:op])
  ) |> map_with(op_shift) |> enumerate |> map_with(x ->
    let (index, line) = x
      union(line, Dict(:gen => (line[:gen], index))) |> splat(Dict)
    end
  ) |> enumerate |> map_with(x ->
    let (index, line) = x
      Dict(
        :op   => opcode_index(line[:op]),
        :gen  => (line[:gen], index),
        :uses => map(sub -> (sub, index), line[:uses])
      )
    end
  ) |>  collect
  return basic_repr
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

function modified_msgpack_pack(x)
  return replace(
    x |> MsgPack.pack,
    UInt8(0x0A) => UInt8(0xC1)
  )
end

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
test_asm |> partial(graph)(opcodes) |> println
test_asm |> partial(graph)(opcodes) |> modified_msgpack_pack |> println
