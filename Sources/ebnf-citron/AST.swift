import CitronLexerModule

protocol AST {
  var position: SourceRegion { get }
  var dump: String { get }
}


extension Array: AST where Element: AST {
  var position: SourceRegion {
    first != nil ? first!.position...last!.position : .empty
  }
  var dump: String {
    self.lazy.map { $0.dump }.joined(separator: Self.dumpSeparator)
  }
  static var dumpSeparator: String {
    return Element.self == EBNF.Rule.self ? "\n\n"
      : Element.self == EBNF.Alt.self ? "\n  | "
      : " "
  }
}

extension Optional: AST where Wrapped: AST {
  var position: SourceRegion {
    self?.position ?? .empty
  }
  var dump: String { self?.dump ?? "" }
}


enum EBNF {
  typealias RuleList = [Rule]
  struct Rule: AST {
    let lhs: Symbol
    let rhs: AltList
    var position: SourceRegion { lhs.position...rhs.position }
    var dump: String {
      """
      \(position): note: rule
      \(lhs.dump) ::=
        \(rhs.dump)
      """
    }
  }
  typealias AltList = [Alt]
  typealias Alt = TermList?
  typealias TermList = [Term]
  typealias Symbol = Token
  
  enum Term: AST {
    case group(AltList)
    case symbol(Symbol)
    case literal(String, position: SourceRegion)
    indirect case quantified(Term, Character, position: SourceRegion)
    
    var position: SourceRegion {
      switch self {
      case .group(let g): return g.position
      case .symbol(let s): return s.position
      case .literal(_, let p): return p
      case .quantified(_, _, let p): return p
      }
    }
    var dump: String {
      switch self {
      case .group(let g): return "( \(g.dump) )"
      case .symbol(let s): return s.dump
      case .literal(let s, _):
        return "'\(s.replacingOccurrences(of: "'", with: "\\'"))'"
      case .quantified(let t, let q, _): return t.dump + String(q)
      }
    }
  }
}

