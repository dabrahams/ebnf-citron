import Foundation

if CommandLine.arguments.count != 2 {
  fatalError("usage: \(CommandLine.arguments[0]) <EBNF grammar file>")
}

let content: String
do {
  content = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
}
catch {
  fatalError("file not found?")
}
print(content)
