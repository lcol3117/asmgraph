import scala.util.chaining._
import scala.language.implicitConversions
import scala.annotation.tailrec
import scala.language.postfixOps

case class AsmLink(genOp: String, useOps: List[String])

class AsmGrapher(val asm: List[String]) {
  def graph(): List[List[Boolean]] = {
    this.easm()
        .pipe(this.reg_facts(_))
        .pipe(this.opdict(_))
        .pipe(this.graph_opdict(_))
  }
  
  def easm(): List[String] = {
    this.asm map { line =>
        line.pipe(raw"xor ([\_a-zA-Z0-9\[\]]+),\s*\1".r.replaceAllIn(_, "xorclear $1"))
            .pipe(raw"syscall".r.replaceAllIn(_, "int 0x80"))
            .pipe(raw"jne".r.replaceAllIn(_, "jnz"))
            .pipe(raw"ne".r.replaceAllIn(_, "nz"))
    }
  }
  
  def reg_facts(easm: List[String]): List[String] = {
    this.reg_facts_iter(easm, 0, List())
  }
  
  @tailrec
  def reg_facts_iter(rest: List[String], id: Int, resolved: List[String]): List[String] = {
    rest match {
      case head :: tail => {
        val extractedOp = raw"\S+\s+".r findFirstIn head
        val fixed = raw"\S+\s+".r.replaceFirstIn(head, "")
          .filterNot { _.isWhitespace }
          .split(",")
          .map { _ + "@@" + id.toString + ", " }
          .dropRight(2)
          .mkString
        this.reg_facts_iter(tail, id + 1, fixed :: resolved)
      }
      case Nil => resolved reverse
    }
  }
  
  def opdict(rf: List[String]): Map[AsmLink, Option[Int]] = {
    opdict_iter(rf, Map() withDefaultValue None)
  }
  
  @tailrec
  def opdict_iter(rf: List[String], resolved: Map[AsmLink, Option[Int]]): Map[AsmLink, Option[Int]] = {
    rf match {
      case head :: tail => {
        val List(genSegment, useOpsString) = raw",".r.replaceFirstIn(head, "@%")
          .split("@%")
          .toList
        val List(genOp, genFact) = (genSegment split " ") toList
        val useOps = useOpsString
          .filterNot { _.isWhitespace }
          .split(",")
          .toList
        val deferenceLevel = genOp.count(_ == "[")
        val undeferencedGenFact = genOp filterNot { "[]" contains _ }
        val typeId = this getTypeId genFact
        val genForm = genOpTypeId + (deferenceLevel * 5)
        this.opdict_iter(
          tail,
          new AsmLink(genOp, useOps) -> Some(genForm)
        )
      }
      case Nil => resolved
    }
  }
}
