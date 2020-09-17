import scala.util.chaining._
import scala.language.implicitConversions
import scala.annotation.tailrec
import scala.language.postfixOps

class AsmGrapher(val asm: List[String]) {
  def graph(): List[List[Boolean]] = {
    this.easm()
        .pipe(this.reg_facts(_))
        .pipe(this.opdict(_))
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
  
}
