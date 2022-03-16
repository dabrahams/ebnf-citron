import Foundation

if CommandLine.arguments.count != 2 {
  fatalError("usage: \(CommandLine.arguments[0]) <EBNF grammar file>", file: #filePath)
}
let sourceFile = CommandLine.arguments[1]
let source: String
do {
  source = try String(contentsOfFile: sourceFile, encoding: .utf8)
}
catch {
  fatalError("file \(String(reflecting: sourceFile)) not found", file: #filePath)
}

do {
  let tokens = lexer.tokens(
    in: source, fromFile: sourceFile, unrecognizedToken: .UNRECOGNIZED_CHARACTER)
  let parser = EBNFParser()
  for (id, text, position) in tokens {
    // print(
    //   "\(tokenLocation): note: \(tokenID) \(String(reflecting: tokenText))")
    try parser.consume(token: Token(id, text, at: position), code: id)
  }
  print(Citronized(try parser.endParsing()))

  
} catch let e as EBNFParser.UnexpectedTokenError {
  print("\(e.token.position): error: Unexpected token \(e.tokenCode)")
  fatalError(file: #filePath)
} catch let error {
  fatalError("Error during parsing: \(error)", file: #filePath)
}
