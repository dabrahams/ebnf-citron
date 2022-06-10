import CitronLexerModule

extension String {
  var isAllUpper: Bool {
    return allSatisfy { ("A"..."Z").contains($0) || $0 == "-" || $0 == "_" }
  }
}
struct Citronized: CustomStringConvertible, CustomDebugStringConvertible {
  /// A mapping from EBNF symbol name to the name used in the generated citron
  /// grammar.
  var ebnfToCitron: [Substring: String] = [:]

  /// A mapping from citron symbol name to EBNF symbol name, or to a placeholder
  /// string if the citron symbol was synthesized (e.g. "foo_opt" from foo?).
  var nonTerminals: [String: Substring] = [:]

  /// A mapping from literal strings in the EBNF sourcde to corresponding citron
  /// symbol names.
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

  /// A BNF grammar rule, with the LHS stored in the first position and the RHS in the remainder.
  typealias CitronRule = [String]

  /// The BNF grammar rules, paired with a region of source that describes their
  /// RHS.
  var citronRules: [(CitronRule, SourceRegion)] = []

  /// A mapping from a string representation of a quantified EBNF symbol,
  /// e.g. "foo?", to a corresponding synthesized BNF symbol, e.g. "foo-opt".
  var quantifiedSymbols: [String: String] = [:]

  /// Creates a BNF representation of `input` suitable for use as a Citron
  /// grammar.
  init(_ input: EBNF.RuleList) {
    for compoundRule in input {
      for rhs in compoundRule.rhs {
        let bnfLHS = bnfSymbol(compoundRule.lhs)
        citronRules.append(
          (
            [bnfLHS] + rhs.map { term($0, citronLHS: bnfLHS) },
            rhs.position
          )
        )
      }
    }
  }

  /// Returns a valid citron token name corresponding to the given text,
  /// generating one if necessary.
  mutating func literalName(_ text: String) -> String {
    if let r = literals[text] { return r }
    let upcased = text.uppercased()
    let r = upcased.isAllUpper ? upcased : "TOK\(literals.count)"
    literals[text] = r
    return r
  }

  /// Returns a new BNF nonterminal symbol name based on the given `root` name,
  /// memoizing the mapping if `rootIsEBNF` is true.
  mutating func newSymbol(
    root: String, rootIsEBNF: Bool = false
  ) -> String {
    let normalizedRoot = (
      root.isAllUpper ? root : root.lowercased()
    ).replacingOccurrences(of: "-", with: "_")

    // Try up to 20 numerical suffixes if the normalizedRoot is already taken.
    for suffix in 0...20 {
      let r = suffix == 0 ? normalizedRoot : "\(normalizedRoot)_\(suffix)"
      if nonTerminals[r] == nil {
        if rootIsEBNF { ebnfToCitron[root[...]] = r }
        nonTerminals[r] = rootIsEBNF ? root[...] : "<synthesized>"
        return r
      }
    }
    fatalError("More than 20?!")
  }

  /// Returns the BNF nonterminal symbol name corresponding to the given ebnf
  /// symbol, generating a new name and memoizing the correspondence if
  /// necessary.
  mutating func bnfSymbol(_ ebnfSymbol: Token) -> String {
    let ebnfName = ebnfSymbol.text
    if let r = ebnfToCitron[ebnfName] { return r }
    let r = newSymbol(root: String(ebnfName), rootIsEBNF: true)
    ebnfToCitron[ebnfName] = r
    return r
  }

  /// Returns the BNF symbol name corresponding to `t` as should appear in the
  /// context of a BNF rule defining `citronLHS`.
  mutating func term(_ t: EBNF.Term, citronLHS: String) -> String {
    switch t {
    case .group(let alternatives):

      // Synthesize a symbol for the group.
      let group_lhs = newSymbol(root: citronLHS)
      for rhs in alternatives {
        citronRules.append(
          (
            [group_lhs] + rhs.map { term($0, citronLHS: group_lhs) },
            rhs.position
          ))
      }
      return group_lhs

    case .symbol(let s):
      return bnfSymbol(s)
      
    case .literal(let l, _):
      return literalName(l)

    // quantified symbols and literals get a symbol name based on the underlying
    // thing.
    case .quantified(.symbol(let s), let q, _):
      return quantified(
        bnfSymbol(s), q, position: t.position, key: String(s.text + String(q)))
      
    case .quantified(.literal(let text, _), let q, _):
      return quantified(
        literalName(text), q, position: t.position, key: text + String(q))
      
    case .quantified(let u, let q, _):
      return quantified(term(u, citronLHS: citronLHS), q, position: t.position)
    }
  }

  /// Returns the BNF symbol corresponding to quantifying the BNF symbol `u`
  /// with `q`, with the EBNF source appearing at `position`.
  mutating func quantified(
    _ u: String, _ q: Character, position: SourceRegion, key: String? = nil
  ) -> String {
    if let k = key, let r = quantifiedSymbols[k] { return r }
    let suffix = ["?": "-opt", "*": "-list", "+": "-list1"][q]!
    let r = newSymbol(root: u + suffix)
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
