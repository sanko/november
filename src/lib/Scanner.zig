const std = @import("std");
const debug = std.debug;
const testing = std.testing;

const handy = @import("handy.zig");
const is_alpha = handy.is_alpha;
const is_digit = handy.is_digit;

const token_ = @import("Token.zig");
const Token = token_.Token;
const TokenType = token_.TokenType;

const Scanner = @This();

end: [*]const u8,
start: [*]const u8,
current: [*]const u8,
line: usize,
column: usize,

pub fn init(source: []const u8) Scanner {
    const start: [*]const u8 = @ptrCast(source);
    return Scanner{
        .end = @ptrCast(if (source.len == 0) &start[0] else &source[source.len - 1]),
        .start = start,
        .current = @ptrCast(source),
        .line = 1,
        .column = 0,
    };
}

pub fn scan(self: *Scanner) void {
    var line: usize = 0;

    while (true) {
        const token = self.scan_token();
        if (token.line != line) {
            line = token.line;
            debug.print("line {}: ", .{line});
        }

        token.debug(debug);
        debug.print("\n", .{});

        if (token.type == .Eof) break;
    }
}

test "basic scanner init" {
    var scanner = init("&{}{}{}{}warn;'quoted text';m/match/;\nmy $file = '你好.txt'; -M $file;");
    try testing.expect(scanner.line == 1);
    scanner.scan();
    try testing.expect(scanner.line == 2);
}

pub fn scan_token(self: *Scanner) Token {
    self.skip_whitespace();
    self.start = self.current;
    if (self.is_at_end()) return self.make_token(TokenType.Eof);

    const c = self.advance();

    if (is_digit(c)) return self.number();
    if (is_alpha(c)) return self.identifier();

    switch (c) {
        '&' => return if (self.match('&')) self.make_token(TokenType.AmpersandAmpersand) else self.make_token(TokenType.Ampersand),
        '(' => return self.make_token(TokenType.OpenParen),
        ')' => return self.make_token(TokenType.CloseParen),
        '{' => return self.make_token(TokenType.OpenBrace),
        '}' => return self.make_token(TokenType.CloseBrace),
        ';' => return self.make_token(TokenType.Semicolon),
        ',' => return self.make_token(TokenType.Comma),
        '.' => return self.make_token(TokenType.Dot),
        '-' => {
            if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                switch (self.start[1]) {
                    'a' => return self.make_token(TokenType.FT_A),
                    'C' => return self.make_token(TokenType.FT_C),
                    'c' => return self.make_token(TokenType.FT_c),
                    'd' => return self.make_token(TokenType.FT_d),
                    'e' => return self.make_token(TokenType.FT_e),
                    'f' => return self.make_token(TokenType.FT_f),
                    'g' => return self.make_token(TokenType.FT_g),
                    'k' => return self.make_token(TokenType.FT_k),
                    'l' => return self.make_token(TokenType.FT_l),
                    'M' => return self.make_token(TokenType.FT_M),
                    'O' => return self.make_token(TokenType.FT_O),
                    'o' => return self.make_token(TokenType.FT_o),
                    'p' => return self.make_token(TokenType.FT_p),
                    'r' => return self.make_token(TokenType.FT_r),
                    'R' => return self.make_token(TokenType.FT_R),
                    'S' => return self.make_token(TokenType.FT_S),
                    's' => return self.make_token(TokenType.FT_s),
                    'T' => return self.make_token(TokenType.FT_T),
                    't' => return self.make_token(TokenType.FT_t),
                    'u' => return self.make_token(TokenType.FT_u),
                    'w' => return self.make_token(TokenType.FT_w),
                    'W' => return self.make_token(TokenType.FT_W),
                    'X' => return self.make_token(TokenType.FT_X),
                    'x' => return self.make_token(TokenType.FT_x),
                    'z' => return self.make_token(TokenType.FT_z),
                    else => return self.make_token(TokenType.Identifier),
                }
            } else {
                return self.make_token(TokenType.Minus);
            }
        },
        '+' => return self.make_token(TokenType.Plus),
        '/' => return self.make_token(TokenType.Slash),
        '*' => return self.make_token(TokenType.Star),
        '`' => return self.make_token(TokenType.Backtick),
        '!' => return if (self.match('=')) self.make_token(TokenType.BangEqual) else self.make_token(TokenType.Bang),
        '=' => return if (self.match('=')) self.make_token(TokenType.EqualEqual) else if (self.match('>')) self.make_token(TokenType.EqualEqual) else self.make_token(TokenType.Equal),
        '<' => return if (self.match('=')) self.make_token(TokenType.LessEqual) else self.make_token(TokenType.Less),
        '>' => return if (self.match('=')) self.make_token(TokenType.FatComma) else self.make_token(TokenType.Greater),
        '"' => return self.double_string(),
        '\'' => return self.single_string(),
        else => {},
    }

    debug.print("unknown character: {c}\n", .{c});
    return self.error_token("Unexpected character.");
}

pub fn double_string(self: *Scanner) Token {
    while (self.peek() != '"' and !self.is_at_end()) {
        if (self.peek() == '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.is_at_end()) return self.error_token("Unterminated string.");
    _ = self.advance();
    return self.make_token(TokenType.DString);
}

pub fn single_string(self: *Scanner) Token {
    while (self.peek() != '\'' and !self.is_at_end()) {
        if (self.peek() == '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.is_at_end()) return self.error_token("Unterminated string.");
    _ = self.advance();
    return self.make_token(TokenType.SString);
}

pub fn number(self: *Scanner) Token {
    while (is_digit(self.peek())) {
        _ = self.advance();
    }

    if (self.peek() == '.' and is_digit(self.peek_next())) {
        _ = self.advance();
        while (is_digit(self.peek())) {
            _ = self.advance();
        }
    }

    return self.make_token(TokenType.Number);
}

pub fn identifier(self: *Scanner) Token {
    while (is_alpha(self.peek()) or is_digit(self.peek())) {
        _ = self.advance();
    }

    return self.make_token(self.identifier_type());
}

pub fn match(self: *Scanner, comptime expected: u8) bool {
    if (self.is_at_end()) return false;
    if (self.peek() != expected) return false;

    self.current += 1;
    return true;
}

pub fn make_token(self: *Scanner, token_type: TokenType) Token {
    if (token_type != TokenType.Eof) {
        return Token{
            .type = token_type,
            .content = self.start,
            .len = (@intFromPtr(self.current) - @intFromPtr(self.start)),
            .line = self.line,
        };
    } else {
        return Token{
            .type = token_type,
            .content = "",
            .len = 0,
            .line = self.line,
        };
    }
}

pub fn error_token(self: *Scanner, message: []const u8) Token {
    return Token{
        .type = TokenType.Error,
        .content = @ptrCast(message),
        .len = @intCast(message.len),
        .line = self.line,
    };
}

pub fn is_at_end(self: *Scanner) bool {
    return @intFromPtr(self.current) > @intFromPtr(self.end);
}

pub fn advance(self: *Scanner) u8 {
    const ret = self.current[0];
    self.current += 1;
    return ret;
}

pub fn peek(self: *Scanner) u8 {
    return self.current[0];
}

pub fn peek_next(self: *Scanner) u8 {
    if (self.is_at_end()) return 0;
    return self.current[1];
}

pub fn skip_whitespace(self: *Scanner) void {
    while (true) {
        const c = self.peek();
        switch (c) {
            ' ', '\r', '\t' => {
                _ = self.advance();
            },
            '\n' => {
                self.line += 1;
                _ = self.advance();
            },
            '/' => {
                if (self.peek_next() == '/') {
                    // A comment goes until the end of the line.
                    while (self.peek() != '\n' and !self.is_at_end()) {
                        _ = self.advance();
                    }
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

pub fn identifier_type(self: *Scanner) TokenType {
    switch (self.start[0]) {
        'a' => return self.check_keyword(1, "nd", TokenType.And),
        'c' => return self.check_keyword(1, "lass", TokenType.Class),
        'e' => return self.check_keyword(1, "lse", TokenType.Else),
        'f' => {
            if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                switch (self.start[1]) {
                    'a' => return self.check_keyword(2, "lse", TokenType.False),
                    'i' => return self.check_keyword(2, "eld", TokenType.Field),
                    'o' => return self.check_keyword(2, "r", TokenType.For),
                    'u' => return self.check_keyword(2, "n", TokenType.Fun),
                    else => return TokenType.Identifier,
                }
            } else {
                return TokenType.Identifier;
            }
        },
        'i' => return self.check_keyword(1, "f", TokenType.If),
        'm' => return self.check_keyword(1, "ethod", TokenType.Method),
        'o' => return self.check_keyword(1, "r", TokenType.Or),
        'p' => return self.check_keyword(1, "rint", TokenType.Print),
        'r' => return self.check_keyword(1, "eturn", TokenType.Return),
        's' => return self.check_keyword(1, "uper", TokenType.Super),
        't' => {
            if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                switch (self.start[1]) {
                    'h' => return self.check_keyword(2, "is", TokenType.This),
                    'r' => return self.check_keyword(2, "ue", TokenType.True),
                    else => return TokenType.Identifier,
                }
            } else {
                return TokenType.Identifier;
            }
        },
        'u' => return self.check_keyword(1, "ndef", TokenType.Undef),
        'v' => return self.check_keyword(1, "ar", TokenType.Var),
        'w' => return self.check_keyword(1, "hile", TokenType.While),
        else => return TokenType.Identifier,
    }
}

pub fn check_keyword(self: *Scanner, start: usize, rest: []const u8, token_type: TokenType) TokenType {
    const len = rest.len;
    const tgt = self.start[start .. start + len];
    const lhs = @intFromPtr(self.current) - @intFromPtr(self.start);
    const rhs = start + len;
    _ = lhs;
    _ = rhs;
    if (@intFromPtr(self.current) - @intFromPtr(self.start) == start + len and std.mem.eql(u8, tgt, rest)) {
        return token_type;
    }

    return TokenType.Identifier;
}
