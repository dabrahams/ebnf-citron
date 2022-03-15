PARSING = Sources/ebnf-citron
GRAMMAR = ${PARSING}/EBNFGrammar.citron
CITRON_PARSER = ${PARSING}/EBNFParser.swift
SWIFTC = swiftc
SWIFT_FLAGS =
LCOV_FILE = ./.build/coverage.lcov
SHELL=/bin/bash
EBNF=/Users/dave/src/val/Docs/Grammar.ebnf

ifeq ($(OS),Windows_NT)
    PARSER_OPTS =  -Xlinker swiftCore.lib
else
    PARSER_OPTS =
endif

run: ${CITRON_PARSER}
	swift run ebnf-citron ${EBNF}

build: ${CITRON_PARSER}
	swift build --enable-test-discovery ${SWIFT_FLAGS}

test: ${CITRON_PARSER}
	swift test --enable-test-discovery ${SWIFT_FLAGS}

test-lcov: ${CITRON_PARSER}
	swift build --build-tests --enable-code-coverage
	$$(swift test --enable-test-discovery --enable-code-coverage --verbose \
	   ${SWIFT_FLAGS} 2>&1 \
	   | tee /dev/tty | grep 'llvm-cov export' \
	   | sed -e 's/ export / export -format=lcov /') > "${LCOV_FILE}"

test-jcov: ${CITRON_PARSER}
	swift test --enable-test-discovery --enable-code-coverage ${SWIFT_FLAGS}

clean:
	rm -rf ${CITRON_PARSER} ./.build


${CITRON_PARSER}: ${GRAMMAR}
	rm -f $@
	swift build --target citron # Build citron executable
	swift run citron ${GRAMMAR_OPTS} ${GRAMMAR} -o $@
	chmod -w $@                              # prevent unintended edits
