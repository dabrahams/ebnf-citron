import CitronLexerModule

struct Citronized: CustomStringConvertible, CustomDebugStringConvertible {
  var ebnfToCitron: [Substring: String] = [:]
  var nonTerminals: [String: Substring] = [:]
  var literals: [String: String] = [
    "*": "STAR",
    "+": "PLUS",
    "[": "LBRACKET",
    "]": "RBRACKET",
    "(": "LPAREN",
    ")": "RPAREN",
    "{": "LBRACE",
    "}": "RBRACE",
    ":": "COLON",
    "&": "AMPER",
    "|": "VBAR",
    "=": "EQUAL",
    "==": "EQUAL_EQUAL",
    "<": "LANGLE",
    ">": "RANGLE",
    "->": "ARROW",
    "_": "UNDERSCORE",
    ".": "DOT",
    ",": "COMMA",
    "::": "COLON_COLON",
    "?": "QUESTION"
  ]
  typealias CitronRule = [String]
  var citronRules: [(CitronRule, SourceRegion)] = []
  var quantifiedSymbols: [String: String] = [:]
  
  init(_ input: EBNF.RuleList) {
    for compoundRule in input {
      for rhs in compoundRule.rhs {
        addCitronRule {
          (
            $0.citronRule($0.symbol(compoundRule.lhs), rhs),
            rhs.position
          )
        }
      }
    }
  }

  mutating func literalName(_ text: String) -> String {
    if let r = literals[text] { return r }
    let upcased = text.uppercased()
    let r = upcased.allSatisfy { ("A"..."Z").contains($0) }
      ? upcased : "TOK\(literals.count)"
    literals[text] = r
    return r
  }
  
  mutating func newSymbol(_ root: String, ebnf: Substring = "") -> String {
    let normalizedRoot = root.replacingOccurrences(of: "-", with: "_")
    for suffix in 0...20 {
      let r = suffix == 0 ? normalizedRoot : "\(normalizedRoot)_\(suffix)"
      if nonTerminals[r] == nil {
        if !ebnf.isEmpty { ebnfToCitron[ebnf] = r }
        nonTerminals[r] = ebnf
        return r
      }
    }
    fatalError("More than 20?!")
  }
  
  mutating func symbol(_ ebnfSymbol: Token) -> String {
    let t = ebnfSymbol.text
    if let r = ebnfToCitron[t] { return r }
    return newSymbol(String(t), ebnf: t)
  }

  mutating func addCitronRule(
    _ makeRule: (inout Self)->(CitronRule, SourceRegion))
  {
    let marker = citronRules.count
    citronRules.append(([], .empty))
    citronRules[marker] = makeRule(&self)
  }
  
  mutating func citronRule(_ citronLHS: String, _ rhs: EBNF.Alt) -> CitronRule {
    return [citronLHS] + rhs.map { term($0, citronLHS: citronLHS) }
  }

  mutating func term(_ t: EBNF.Term, citronLHS: String) -> String {
    switch t {
    case .group(let alternatives):
      let group_lhs = newSymbol(citronLHS)
      for rhs in alternatives {
        addCitronRule { me in
          (
            [group_lhs] + rhs.map { me.term($0, citronLHS: group_lhs) },
            rhs.position
          )
        }
      }
      return group_lhs
    case .symbol(let s):
      return symbol(s)
      
    case .literal(let l, _):
      return literalName(l)

    // FIXME: Nix the horrible code duplication in quantifier handling.
    case .quantified(.symbol(let s), let q, _):
      let sq = String(s.text + String(q))
      let unquantified = symbol(s)
      if let r = quantifiedSymbols[sq] { return r }
      let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
      let r = newSymbol(s.text + suffix)
      quantifiedSymbols[sq] = r
      citronRules.append((q == "+" ? [r, unquantified] : [r], s.position))
      citronRules.append((q == "?" ? [r, unquantified] : [r, r, unquantified], t.position))
      return r
      
    case .quantified(.literal(let text, let p), let q, _):
      let sq = text + String(q)
      let unquantified = literalName(text)
      if let r = quantifiedSymbols[sq] { return r }
      let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
      let r = newSymbol(unquantified + suffix)
      quantifiedSymbols[sq] = r
      citronRules.append((q == "+" ? [r, unquantified] : [r], p))
      citronRules.append((q == "?" ? [r, unquantified] : [r, r, unquantified], t.position))
      
      return r
      
    case .quantified(let t1, let q, _):
      let unquantified = term(t1, citronLHS: citronLHS)
      let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
      let r = newSymbol(unquantified + suffix)
      citronRules.append((q == "+" ? [r, unquantified] : [r], t1.position))
      citronRules.append((q == "?" ? [r, unquantified] : [r, r, unquantified], t.position))
      return r
    }
  }

  var description: String {
    citronRules.lazy.map {
      "\($0.0.first!) ::= \($0.0.dropFirst().joined(separator: " ")). {}"
    }.joined(separator: "\n\n")
  }

  var debugDescription: String {
    citronRules.lazy.map {
      "\($0.1): note:\n" +
      "\($0.0.first!) ::= \($0.0.dropFirst().joined(separator: " ")). {}"
    }.joined(separator: "\n\n")
  }
}
