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
  fatalError("file \(sourceFile.debugDescription) not found")
}

do {
  let tokens = lexer.tokens(
    in: source, fromFile: sourceFile, unrecognizedToken: .UNRECOGNIZED_CHARACTER)
  let parser = EBNFParser()
  for (tokenID, tokenText, tokenLocation) in tokens {
    print(tokenLocation, tokenText, tokenID)
    print()
    try parser.consume(token: tokenText, code: tokenID)
  }
  let r: EBNFParser.CitronResult = try parser.endParsing()
  print(r)
} catch let error {
  print("Error during parsing: \(error)")
}
