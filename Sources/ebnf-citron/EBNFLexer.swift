import CitronLexerModule

let lexer = Scanner<EBNFParser.CitronTokenCode>(
  literalStrings: [
    "|": .OR,
    "*": .STAR,
    "+": .PLUS,
    "?": .QUESTION,
    "::=": .IS_DEFINED_AS,
    "(": .LPAREN,
    ")": .RPAREN
  ],
  patterns: [
    /// A mapping from regular expression pattern to either a coresponding token ID,
    /// or `nil` if the pattern is to be discarded (e.g. for whitespace).
    #"[-A-Za-z0-9]+"#: .SYMBOL,
    #"'([^\\']|\\.)*'"#: .LITERAL,

    // "//" followed by any number of non-newlines (See
    // https://unicode-org.github.io/icu/userguide/strings/regexp.html
    //   #regular-expression-metacharacters
    // and https://www.unicode.org/reports/tr44/#BC_Values_Table).
    #"//\P{Bidi_Class=B}*"#: nil, // 1-line comment

    #"\s+"#: nil // whitespace
  ]
)
