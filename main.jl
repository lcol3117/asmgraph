using Distributed

using DataStructures
import MsgPack

partial(fq) = aq -> xq -> fq(xq, aq)
splat(fq) = xq -> fq(xq...)
filter_with(fq) = xq -> filter(fq, xq)
map_with(fq) = xq -> map(fq, xq)
split_with(delimq) = xq -> split(xq, delimq)
get_or_id(src, key) = haskey(src, key) ? src[key] : key
Iterators.rest(itrq::Iterators.Rest, stateq) = Iterators.Rest(itrq.itr, stateq)

function read_asm_line(text)
  segm_text, item_split, segm_component = try
    segm_text, item_split = text |> split_with(" ") |> filter_with(
      x -> x != ""
    ) |> Iterators.peel
    (
      segm_text,
      item_split,
      (
        parse(Int64, segm_text[1:4], base= 16)
      ) => (
        parse(Int64, segm_text[5:8], base= 16)
      )
    )
  catch _
    (nothing, nothing, -1 => -1)
  end
  __retn_target = try
    _, instr_split = Iterators.peel(item_split)
    op, args = Iterators.peel(instr_split)
    gen, unmod = args |> (
      "," |> split_with |> map_with
    ) |> Iterators.flatten |> Iterators.peel
    if length(ARGS) >= 2 && ARGS[2] == "debug"
      Dict(:op => op, :__args => args, :gen => gen, :__unmod => unmod) |> println
    end
    uses = [[gen] ; collect(unmod)]
    instr_component = Dict(:op => op, :gen => gen, :uses => uses)
    segm_component => instr_component
  catch _
    segm_component => Dict(:op => "nop", :gen => "@_NOP", :uses => ["@_NOP"])
  end
  if length(ARGS) >= 2 && ARGS[2] == "debug"
    println("$segm_component -> $item_split -> $(__retn_target.second)")
  end
  return __retn_target
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
  r"xor\W+(?<a>\w+)\W*,\W*(?P=a)" => s"xorclear \g<a>",
  r"\Wal" => " eax", r"\Wah" => " eax", r"\Wax" => " eax", r"\Wrax" => " eax",
  r"\Wbl" => " ebx", r"\Wbh" => " ebx", r"\Wbx" => " ebx", r"\Wrbx" => " ebx",
  r"\Wcl" => " ecx", r"\Wch" => " ecx", r"\Wcx" => " ecx", r"\Wrcx" => " ecx",
  r"\Wdl" => " edx", r"\Wdh" => " edx", r"\Wdx" => " edx", r"\Wrdx" => " edx",
  r"\Wsp" => " esp", r"\Wbp" => " ebp",
  r";.*\n" => "\n", "sysenter" => "syscall", r"\Wrsp" => " esp", r"\Wrbp" => " ebp",
  r"\Wrip" => " eip", "syscall" => "int 0x80, eax, ebx, ecx, edx", "mov eip," => "jmp",
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
  r"\b(real10)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]",
  r"\b(near)?[^\w\n]*(\w+)?[^\w\n]?\[(?<a>\w+).*\]"
]

function instr_reg(reg)
  return reg in [
    "eax", "ebx",
    "ecx", "edx"
  ]
end

function reg_class(reg)
  segm_regs = [
      "cs", "ds", "es",
      "fs", "gs", "ss"
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
    elseif instr_reg(reg)
      3
    elseif startswith(reg, "0x")
      4
    elseif occursin(r"^\d+", reg)
      5
    else
      6
    end
  deref_count = count(partial(==)("["), reg)
  return repr_num + (min(deref_count, 3) * 7)
end

function mov_like(op)
  return occursin("mov", op) || (op == "lea")
end

function number_op_pair(x)
  if x == ("mov" => nothing)
    25256
  elseif x == ("push" => nothing)
    25257
  elseif x == ("pop" => nothing)
    25258
  else
    (28 * opcode_index(x.first, opcodes)) + reg_class(x.second)
  end
end

function graph(asm, opcodes)
  start = foldl(replace,
    [map(partial(=>)(s" \g<a> "), dir_regexes) ; r_mods],
    init= asm
  )
  bw_repr = start |> split_with("\n") |> map_with(strip) |> filter_with(x -> x != "") |>
  partial(replace)(r"\ \ " => " ") |>
  partial(replace)(r"\," => ", ") |>
  map_with(read_asm_line) |> filter_with(x ->
    !occursin("nop", x.second[:op])
  ) |> map_with(line ->
    line.first => op_shift(line.second)
  ) |> map_with(line ->
    line.first => union(line.second, Dict(:op =>
      if mov_like(line.second[:op])
        "mov" => nothing
      elseif line.second[:op] == "push"
        "push" => nothing
      elseif line.second[:op] == "pop"
        "pop" => nothing
      else
        line.second[:op] => line.second[:gen]
      end
    )) |> splat(Dict)
  )
  links = Set{Pair{Pair{AbstractString,Union{AbstractString,Nothing}},Pair{AbstractString,Union{AbstractString,Nothing}}}}()
  op_sources = Dict{AbstractString,Pair{AbstractString,Union{AbstractString,Nothing}}}()
  mov_shifting = Dict{AbstractString,AbstractString}()
  stack_refs = Stack{AbstractString}()
  from_stack = Set{AbstractString}()
  call_stack = Stack{Int64}()
  h = Set{Int64}()
  jump_derive_eax = false
  jump_source = nothing
  jump_depth = 0
  start_segm = nothing
  links_retn = run_graphing(
    bw_repr, links, op_sources, mov_shifting, stack_refs, from_stack,
    h, jump_derive_eax, jump_source, jump_depth, start_segm, call_stack
  )
  return filter(x -> (x.second != nothing) && (x.first != nothing), map(
    x -> Pair(map(
      x -> x.second == "" ? nothing : number_op_pair(x),
      x
    )...),
    collect(links_retn)
  ))
end

@everywhere function run_graphing(
  bw_repr, links, op_sources, mov_shifting, stack_refs, from_stack,
  h, jump_derive_eax, jump_source, jump_depth, start_segm, call_stack
)
  fork_local = Set{Future}()
  basic_repr = begin
    if start_segm == nothing
      bw_repr
    elseif !any(x -> x.first == start_segm, bw_repr)
      nothing
    else
      Iterators.dropwhile(
        x -> x.first != start_segm,
        bw_repr
      )
    end
  end
  if bw_repr != nothing
    for full in basic_repr
      try
        i = full.second
        if instr_reg(i[:op].first) || instr_reg(i[:op].second)
          continue
        end
      	if jump_depth >= parse(Int64, ARGS[1])
      	  if length(ARGS) >= 2 && ARGS[2] == "debug"
      	    println("Stopping recursive fork, jump depth reached $jump_depth")
      	  end
      	  continue
      	end
        if i[:op].first[1] == 'j'
          new_start_segm = full.first.first => begin
            if startswith(i[:gen], "0x")
              parse(Int64, i[:gen])
            else
              parse(Int64, i[:gen], base= 16)
            end
          end
      	  is_c = i[:op].second != "jmp"
      	  if new_start_segm in h
      	    continue
      	  end
      	  push!(h, new_start_segm)
          union!(
            fork_local,
            @spawnat :any run_graphing(
              bw_repr, links, op_sources, mov_shifting, stack_refs, from_stack,
              h, is_c, i[:op], jump_depth + 1, new_start_segm, call_stack
            )
          )
          if is_c && haskey(op_sources, "eax")
            push!(links, op_sources["eax"]=> i[:op])
          end
        end
        if occursin("call", i[:op].first)
          new_start_segm = full.first.first => begin
            if startswith(i[:gen], "0x")
              parse(Int64, i[:gen])
            else
              parse(Int64, i[:gen], base= 16)
            end
          end
      	  is_c = i[:op].second != "call"
      	  if new_start_segm in h
      	    continue
      	  end
      	  push!(h, new_start_segm)
          push!(call_stack, new_start_segm)
          union!(
            fork_local,
            @spawnat :any run_graphing(
              bw_repr, links, op_sources, mov_shifting, stack_refs, from_stack,
              h, is_c, i[:op], jump_depth + 1, new_start_segm, call_stack
            )
          )
          if is_c && haskey(op_sources, "eax")
            push!(links, op_sources["eax"] => i[:op])
          end
        end
        if occursin("ret", i[:op].first * i[:op].second)
          retn_addr = pop!(call_stack)
          union!(
            fork_local,
            run_graphing(
              bw_repr, links, op_sources, mov_shifting, stack_refs, from_stack,
              h, is_c, i[:op], jump_depth + 1, new_start_segm, call_stack
            )
          )
        end
        if i[:op] == ("mov" => nothing)
          push!(mov_shifting, i[:gen] => get_or_id(mov_shifting, i[:uses][1]))
        elseif i[:op] == ("push" => nothing)
          push!(stack_refs, i[:gen])
          if haskey(op_sources, get_or_id(mov_shifting, i[:gen]))
            push!(op_sources,
              "esp" => op_sources[get_or_id(mov_shifting, i[:gen])]
            )
            push!(op_sources,
              "ebp" => op_sources[get_or_id(mov_shifting, i[:gen])]
            )
          end
        elseif i[:op] == ("pop" => nothing)
          try
            push!(mov_shifting, i[:gen] => pop!(stack_refs))
          catch _ end
        else
      	  if length(ARGS) >= 2 && ARGS[2] == "debug"
      	    println("Opcode $(i[:op]) entered...")
      	  end
          if i[:gen] in from_stack
            delete!(from_stack, i[:gen])
          end
          if i[:gen] == "eax"
            jump_derive_eax = false
          end
          if jump_derive_eax
            push!(links, get_or_id(op_sources, "eax") => i[:op])
          end
          if jump_source != nothing
            push!(links, jump_source => i[:op])
          end
          for j in i[:uses]
            exists = haskey(op_sources, get_or_id(mov_shifting, j))
            if exists && op_sources[get_or_id(mov_shifting, j)] != i[:op]
              if get_or_id(mov_shifting, j) in from_stack
                if haskey(op_sources, "esp")
                  push!(links, op_sources["esp"] => i[:op])
                end
                if haskey(op_sources, "ebp")
                  push!(links, op_sources["ebp"] => i[:op])
                end
              end
              push!(links, op_sources[get_or_id(mov_shifting, j)] => i[:op])
            end
          end
          push!(op_sources, i[:gen] => i[:op])
        end
        catch _ end
    end
  end
  return union(
    links,
    ( fetch(i) for i in fork_local )
  )
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
    map(
      sub -> [sub.first, sub.second],
      x
    ) |> Iterators.flatten |> collect |> MsgPack.pack,
    UInt8(0x0A) => UInt8(0xC0),
    UInt8(0x00) => UInt8(0xC1)
  )
end

function graph_modified_msgpack(asm, opcodes)
  return graph(asm, opcodes) |> modified_msgpack_pack
end

io_asm = open("source.asm")
asm = io_asm |> read |> String
close(io_asm)

open("target.mmp", "a") do f
  write(f, graph_modified_msgpack(asm, opcodes))
  write(f, "\n")
end

if length(ARGS) >= 2 && ARGS[2] == "debug"
  open("target.mmp") do f
    f |> read |> String |> println
  end
end
