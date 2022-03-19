import CitronLexerModule

extension String {
  var isAllUpper: Bool {
    return allSatisfy { ("A"..."Z").contains($0) || $0 == "-" || $0 == "_" }
  }
}
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
    let r = upcased.isAllUpper ? upcased : "TOK\(literals.count)"
    literals[text] = r
    return r
  }
  
  mutating func newSymbol(_ root: String, ebnf: Substring = "") -> String {
    let normalizedRoot = (
      root.isAllUpper ? root : root.lowercased()
    ).replacingOccurrences(of: "-", with: "_")
    
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

    case .quantified(.symbol(let s), let q, _):
      return quantified(
        symbol(s), q, position: t.position, key: String(s.text + String(q)))
      
    case .quantified(.literal(let text, _), let q, _):
      return quantified(
        literalName(text), q, position: t.position, key: text + String(q))
      
    case .quantified(let u, let q, _):
      return quantified(term(u, citronLHS: citronLHS), q, position: t.position)
    }
  }

  mutating func quantified(
    _ u: String, _ q: Character, position: SourceRegion, key: String? = nil
  ) -> String {
    if let k = key, let r = quantifiedSymbols[k] { return r }
    let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
    let r = newSymbol(u + suffix)
    if let k = key { quantifiedSymbols[k] = r }
    citronRules.append((q == "+" ? [r, u] : [r], position))
    citronRules.append((q == "?" ? [r, u] : [r, r, u], position))
    return r
  }
  
  var description: String {
    citronRules.enumerated().lazy.map { i, r in
      let p = i == 0 ? ""
        : citronRules[i-1].0.first == r.0.first ? "\n" : "\n\n"
      return "\(p)\(r.0.first!) ::= \(r.0.dropFirst().joined(separator: " ")). {}"
    }.joined()
  }

  var debugDescription: String {
    citronRules.enumerated().lazy.map { i, r in
      let p = i == 0 ? ""
        : citronRules[i-1].0.first == r.0.first ? "\n" : "\n\n"
      return "\(p)\(r.1): note:\n" +
        "\(r.0.first!) ::= \(r.0.dropFirst().joined(separator: " ")). {}"
    }.joined()
  }
}
