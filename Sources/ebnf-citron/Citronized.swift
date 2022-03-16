import Foundation

struct Citronized: CustomStringConvertible {
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
    "<": "LT",
    ">": "GT",
    "->": "ARROW",
    "_": "UNDERSCORE",
    ".": "DOT",
    ",": "COMMA",
    "::": "COLON_COLON",
    "?": "QUESTION"
  ]
  var citronRules: [[String]] = []
  var quantifiedSymbols: [String: String] = [:]
  
  init(_ input: EBNF.RuleList) {
    for compoundRule in input {
      for rhs in compoundRule.rhs {
        citronRules.append(citronRule(compoundRule.lhs, rhs))
      }
    }
    citronRules.sort { $0.lexicographicallyPrecedes($1) }
  }

  mutating func literalName(_ text: String) -> String {
    if let r = literals[text] { return r }
    let upcased = text.uppercased()
    let validRange = upcased.rangeOfCharacter(from: .uppercaseLetters)
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
  
  mutating func citronRule(_ lhs: Token, _ rhs: EBNF.Alt) -> [String] {
    let l = symbol(lhs)
    return [l] + rhs.map { term($0, citronLHS: l) }
  }

  mutating func term(_ t: EBNF.Term, citronLHS: String) -> String {
    switch t {
    case .group(let alternatives):
      let group_lhs = newSymbol(citronLHS)
      for rhs in alternatives {
        citronRules.append([group_lhs] + rhs.map { term($0, citronLHS: group_lhs) })
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
      citronRules.append(q == "+" ? [r, unquantified] : [r])
      citronRules.append(q == "?" ? [r, unquantified] : [r, r, unquantified])
      return r
      
    case .quantified(.literal(let text, _), let q, _):
      let sq = text + String(q)
      let unquantified = literalName(text)
      if let r = quantifiedSymbols[sq] { return r }
      let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
      let r = newSymbol(unquantified + suffix)
      quantifiedSymbols[sq] = r
      citronRules.append(q == "+" ? [r, unquantified] : [r])
      citronRules.append(q == "?" ? [r, unquantified] : [r, r, unquantified])
      return r
      
    case .quantified(let t, let q, _):
      let unquantified = term(t, citronLHS: citronLHS)
      let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
      let r = newSymbol(unquantified + suffix)
      citronRules.append(q == "+" ? [r, unquantified] : [r])
      citronRules.append(q == "?" ? [r, unquantified] : [r, r, unquantified])
      return r
    }
  }

  var description: String {
    citronRules.lazy.map {
      "\($0.first!) ::= \($0.dropFirst().joined(separator: " "))\n. {}"
    }.joined(separator: "\n\n")
  }
}
