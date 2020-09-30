import scala.language.postfixOps

type AsmOp = String
type AsmSym = String

case class AsmLine(op: AsmOp, gen: AsmSym, uses: List[AsmSym]) {
  def replaceOp(oldOp: AsmOp, newOp: AsmOp): AsmLine =
    if (op == oldOp) AsmLine(newOp, gen, uses) else this
  def replaceGen(oldGen: AsmSym, newGen: AsmSym): AsmLine =
    if (gen == oldGen) AsmLine(op, newGen, uses) else this
  def replaceUses(oldUses: List[AsmSym], newUses: List[AsmSym]) =
    if (uses == oldUses) AsmLine(op, gen, newUses) else this
}

object AsmLine {
  def fromString(str: String): Option[AsmLine] = {
    val symbols = str
      .trim()
      .replaceAll(raw";.*", "")
      .replaceAll(raw"\ *,\ *", " ")
      .split(raw"\ +") toList : List[AsmSym]
    symbols match {
      case op :: gen :: uses  => Some(AsmLine(op, gen, uses toList))
      case _                  => None
    }
  }
}

type Asm = List[AsmLine]

trait AsmReader { def read: Asm }

case class StdAsmReader(str: String) extends AsmReader {
  def read = {
    str
      .toLowerCase()
      .replaceAll("syscall", "int 0x80")
      .split("\n")
      .toList
      .flatMap(AsmLine fromString _)
  }
}

trait EAsm extends AsmReader {
  case class OpShift(bad: AsmSym, good: AsmSym)
  val shiftOps = List(
    OpShift("jz", "je"),
    OpShift("jnz", "jne"),
    OpShift("iretd", "iret"),
    OpShift("jnbe", "ja"),
    OpShift("jnb", "jae"),
    OpShift("jnae", "jb"),
    OpShift("jna", "jbe"),
    OpShift("jecxz", "jcxz"),
    OpShift("jnle", "jg"),
    OpShift("jnl", "jge"),
    OpShift("jnge", "jl"),
    OpShift("jng", "jle"),
    OpShift("jnp", "jpo"),
    OpShift("jp", "jpe"),
    OpShift("loopz", "loope"),
    OpShift("loopnz", "loopne"),
    OpShift("popad", "popa"),
    OpShift("popfd", "popf"),
    OpShift("pushad", "pusha"),
    OpShift("pushfd", "pushf"),
    OpShift("repz", "repe"),
    OpShift("repnz", "repne"),
    OpShift("retf", "ret"),
    OpShift("shl", "sal"),
    OpShift("setnb", "setae"),
    OpShift("setnae", "setb"),
    OpShift("setna", "setbe"),
    OpShift("setz", "sete"),
    OpShift("setnz", "setnz"),
    OpShift("setnge", "setl"),
    OpShift("setnl", "setge"),
    OpShift("setng", "setle"),
    OpShift("setnle", "setg"),
    OpShift("setp", "setpe"),
    OpShift("setnp", "setpo"),
    OpShift("shld", "shrd"),
    OpShift("fwait", "wait"),
    OpShift("xlatb", "xlat")
  )
  abstract override def read = {
    super.read
      .map(shiftOps.foldLeft(_) { (a, x) => a.replaceOp(x.bad, x.good) })
  }
}

val myReader = new StdAsmReader("xlatb eax, ebx\nsyscall") with EAsm

println(myReader.read)

