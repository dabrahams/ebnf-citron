import CitronLexerModule

struct Token: AST {
  typealias ID = EBNFParser.CitronTokenCode

  init(_ id: ID, _ content: Substring, at position: SourceRegion) {
    self.id = id
    self.text = content
    self.position = position
  }

  let id: ID
  let text: Substring
  let position: SourceRegion

  var dump: String { String(text) }
}

extension Token: CustomStringConvertible {
  var description: String {
    "Token(.\(id), \(String(reflecting: text)), at: \(String(reflecting: position)))"
  }
}

