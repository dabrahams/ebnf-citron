import Foundation

if CommandLine.arguments.count != 2 {
  fatalError("usage: \(CommandLine.arguments[0]) <EBNF grammar file>")
}
let sourceFile = CommandLine.arguments[1]
let source: String
do {
  source = try String(contentsOfFile: sourceFile, encoding: .utf8)
}
catch {
  fatalError("file \(String(reflecting: sourceFile)) not found")
}

do {
  let tokens = lexer.tokens(
    in: source, fromFile: sourceFile, unrecognizedToken: .UNRECOGNIZED_CHARACTER)
  let parser = EBNFParser()
  parser.isTracingEnabled = true
  for t in tokens {
    // print(
    //   "\(tokenLocation): note: \(tokenID) \(String(reflecting: tokenText))")
    try parser.consume(token: (), code: t.0)
  }
  let r: EBNFParser.CitronResult = try parser.endParsing()
  print(r)
} catch let error {
  print("Error during parsing: \(error)")
}
