import MsgPack

using DataStructures

partial(fq) = aq -> xq -> fq(xq, aq)
splat(fq) = xq -> fq(xq...)
filter_with(fq) = xq -> filter(fq, xq)
map_with(fq) = xq -> map(fq, xq)
split_with(delimq) = xq -> split(xq, delimq)
get_or_id(src, key) = haskey(src, key) ? src[key] : key
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
  r"xor\W+(?<a>\w+),\W+(?P=a)" => s"xorclear \g<a>"
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
  return repr_num + (min(deref_count, 3) * 7)
end

function mov_like(op)
  return contains(op, "mov") || (op == "lea")
end

function graph(asm, opcodes)
  start = foldl(replace,
    [map(partial(=>)(s" \g<a>"), dir_regexes) ; r_mods],
    init=asm
  )
  @show start
  basic_repr = start |> split_with("\n") |> map_with(strip) |> filter_with(x -> x != "") |>
  partial(replace)(r"\ \ " => " ") |> map_with(read_asm_line) |> filter_with(x ->
    !occursin("nop", x[:op])
  ) |> map_with(op_shift) |> map_with(line ->
    union(line, Dict(:op =>
      if mov_like(line[:op])
        "-1"
      elseif line[:op] == "push"
        "-2"
      elseif line[:op] == "pop"
        "-3"
      else
        # (28 * opcode_index(line[:op], opcodes)) + reg_class(line[:gen])
        "[| $(line[:op]) via $(line[:gen]) |]"
      end
    )) |> splat(Dict)
  )
  @show basic_repr
  links = Dict{AbstractString,AbstractString}()
  op_sources = Dict{AbstractString,AbstractString}()
  mov_shifting = Dict{AbstractString,AbstractString}()
  stack_refs = Stack{AbstractString}()
  for i in basic_repr
    if i[:op] == "-1"
      push!(mov_shifting, i[:gen] => get_or_id(mov_shifting, i[:uses][1]))
      println("<<MOV>>")
    elseif i[:op] == "-2"
      push!(stack_refs, i[:gen])
      println("<<PUSH>>")
    elseif i[:op] == "-3"
      push!(mov_shifting, i[:gen] => pop!(stack_refs))
      println("<<POP>>")
    else
      println("<<>>")
      for j in i[:uses]
        if haskey(op_sources, get_or_id(mov_shifting, j))
          push!(links, op_sources[get_or_id(mov_shifting, j)] => i[:op])
          println(op_sources[get_or_id(mov_shifting, j)] => i[:op])
        end
      end
      push!(op_sources, i[:gen] => i[:op])
    end
  end
  return links
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

println("[[TEST]]")

io_test_asm = open("test.asm")
test_asm = io_test_asm |> read |> String
close(io_test_asm)

test_asm |> partial(graph)(opcodes) |> println
test_asm |> partial(graph)(opcodes) |> modified_msgpack_pack |> println
