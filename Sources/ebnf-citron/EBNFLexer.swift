import CitronLexerModule

let lexer = Scanner<EBNFParser.CitronTokenCode>(
  literalStrings: [
    "::=": .IS_DEFINED_AS
  ],
  patterns: [
    /// A mapping from regular expression pattern to either a coresponding token ID,
    /// or `nil` if the pattern is to be discarded (e.g. for whitespace).
    #"[-_A-Za-z0-9]+(?=\s*::=)"#: .LHS,
    #"[-_A-Za-z0-9]+"#: .SYMBOL,

    #"\s+"#: nil // whitespace
  ]
)
