import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

bool _hasTypeIn(Token token, List<TokenType> types) => types.contains(token.type);

class Parser {
  final List<Token> _tokens;
  final ErrorReporter _errorReporter;
  final List<Statement> _statements = [];
  int _index = 0;

  Parser(this._tokens, this._errorReporter);

  List<Statement> parse() {
    while (!_isAtEnd()) {
      try {
        _statements.add(_parseStatement());
      } on LoxError catch (error) {
        _errorReporter.report(error, isDynamic: false);
        _synchronize();
      }
    }

    return _statements;
  }

  Statement _parseStatement() {
    if (_advanceIf(TokenType.$var)) return _parseVar();

    if (_advanceIf(TokenType.$print)) return _parsePrint();

    final expression = _parseExpression();
    _expect(TokenType.semicolon, 'Expected semicolon.');
    return new ExpressionStatement(expression);
  }

  Statement _parseVar() {
    final identifier = _peek();
    _expect(TokenType.identifier, 'Expected identifier after \'var\'.');
    final initializer = _advanceIf(TokenType.equal) ? _parseExpression() : null;
    _expect(TokenType.semicolon, 'Expected semicolon.');
    return new VarStatement(identifier, initializer);
  }

  Statement _parsePrint() {
    final expression = _parseExpression();
    _expect(TokenType.semicolon, 'Expected semicolon.');
    return new PrintStatement(expression);
  }

  Expression _parseExpression() => _parseAssignment();

  Expression _parseAssignment() {
    final expression = _parseTernary();
    if (_peek().type != TokenType.equal) return expression;

    final operator = _advance();
    final rhs = _parseAssignment();
    if (expression is IdentifierExpression) return new AssignmentExpression(expression.identifier, rhs);

    throw new LoxError(operator, 'Invalid left-hand side of assignment.');
  }

  Expression _parseTernary() {
    final expression = _parseEquality();
    if (!_advanceIf(TokenType.question)) return expression;

    final consequent = _parseAssignment();
    _expect(TokenType.colon, 'Expected colon for ternary operator.');
    final alternative = _parseAssignment();
    return new TernaryExpression(expression, consequent, alternative);
  }

  Expression _parseEquality() =>
    _parseBinary(_parseComparison, [TokenType.equalEqual, TokenType.bangEqual]);

  Expression _parseComparison() =>
    _parseBinary(_parseAdditive, [TokenType.greater, TokenType.greaterEqual, TokenType.less, TokenType.lessEqual]);

  Expression _parseAdditive() =>
    _parseBinary(_parseMultiplicative, [TokenType.minus, TokenType.plus]);

  Expression _parseMultiplicative() =>
    _parseBinary(_parseUnary, [TokenType.star, TokenType.slash]);

  Expression _parseBinary(Expression parseOperand(), List<TokenType> operators) {
    var expression = parseOperand();

    while (_hasTypeIn(_peek(), operators)) {
      final operator = _advance();
      final rightOperand = parseOperand();
      expression = new BinaryExpression(expression, operator, rightOperand);
    }

    return expression;
  }

  Expression _parseUnary() {
    if (!_hasTypeIn(_peek(), [TokenType.bang, TokenType.minus])) return _parsePrimary();

    final operator = _advance();
    final operand = _parseUnary();
    return new UnaryExpression(operator, operand);
  }

  Expression _parsePrimary() {
    final next = _advance();
    switch (next.type) {
      case TokenType.leftParen:
        final expression = _parseExpression();
        _expect(TokenType.rightParen, 'Expected closing parenthesis.');
        return new ParenthesizedExpression(expression);
      case TokenType.identifier:
        return new IdentifierExpression(next);
      case TokenType.$nil:
        return new LiteralExpression(null);
      case TokenType.$true:
        return new LiteralExpression(true);
      case TokenType.$false:
        return new LiteralExpression(false);
      case TokenType.string:
        return new LiteralExpression(next.lexeme.substring(1, next.lexeme.length - 1));
      case TokenType.number:
        return new LiteralExpression(double.parse(next.lexeme));
      case TokenType.eof:
        throw new LoxError(next, 'Unexpected end of input.');
      default:
        throw new LoxError(next, 'Unexpected token \'${next.lexeme}\'.');
    }
  }

  bool _isAtEnd() => _tokens[_index].type == TokenType.eof;

  Token _peek() => _tokens[_index];

  Token _advance() => _isAtEnd() ? _tokens[_index] : _tokens[_index++];

  bool _advanceIf(TokenType type) {
    final isMatch = _peek().type == type;
    if (isMatch) _advance();

    return isMatch;
  }

  void _expect(TokenType type, String errorMessage) {
    final token = _advance();
    if (token.type != type) throw new LoxError(token, errorMessage);
  }

  void _synchronize() {
    while (!_isAtEnd()) {
      switch (_peek().type) {
        case TokenType.semicolon:
          _advance();
          return;
        case TokenType.$class:
        case TokenType.$fun:
        case TokenType.$for:
        case TokenType.$if:
        case TokenType.$print:
        case TokenType.$return:
        case TokenType.$var:
        case TokenType.$while:
          return;
        default:
          _advance();
          break;
      }
    }
  }
}
