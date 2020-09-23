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
    Some(AsmLine("test", "just", List("a", "demo")))
  }
}

type Asm = List[AsmLine]

trait AsmReader { def read: Asm }

case class StdAsmReader(str: String) extends AsmReader {
  def read = {
    str
      .replaceAll("syscall", "int 0x80")
      .split("\n")
      .toList
      .flatMap(AsmLine fromString _)
  }
}

trait EAsm extends AsmReader {
  abstract override def read = {
    super.read
      .map(_.replaceOp("test", "easmtest"))
  }
}

val myReader = new StdAsmReader("mov eax, ebx\nsyscall") with EAsm

println(myReader.read)

