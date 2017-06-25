import 'dart:io';

import 'package:dlox/src/ast_printer.dart';
import 'package:dlox/src/error_reporter.dart';
import 'package:dlox/src/parser.dart';
import 'package:dlox/src/scanner.dart';

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln('Usage: dlox [<path>]');
  } else if (args.length == 1) {
    _runFile(args[0]);
  } else {
    _runPrompt();
  }
}

void _runFile(String path) {
  try {
    exitCode = _run(new File(path).readAsStringSync());
  } on FileSystemException {
    stderr.writeln('Could not open file: $path');
  }
}

void _runPrompt() {
  for (;;) {
    stdout.write('dlox> ');
    _run(stdin.readLineSync());
  }
}

int _run(String source) {
  final errorReporter = new ErrorReporter();
  final tokens = new Scanner(source, errorReporter).scanTokens();
  final node = new Parser(tokens, errorReporter).parse();

  // temp
  if (!errorReporter.hadStaticError) print(new AstPrinter().print(node));

  final code = errorReporter.hadStaticError ? 65 : 0;
  return code;
}
