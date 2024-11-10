pub const TokenLen = u47;
pub const Token = struct {
    type: TokenType,
    line: usize,
    len: usize,
    content: [*]const u8,

    pub fn debug(self: Token, writer: anytype) void {
        writer.print("Token{{type: {s}, content: \"{s}\"}}", .{ @tagName(self.type), self.content[0..self.len] });
    }

    pub fn synthetic(text: []const u8) Token {
        var token: Token = undefined;
        token.content = text.ptr;
        token.len = @intCast(text.len);
        return token;
    }
};

pub const TokenType = enum {
    // File tests -X
    FT_A,
    FT_B,
    FT_b,
    FT_C,
    FT_c,
    FT_d,
    FT_e,
    FT_f,
    FT_g,
    FT_k,
    FT_l,
    FT_M,
    FT_O,
    FT_o,
    FT_p,
    FT_r,
    FT_R,
    FT_S,
    FT_s,
    FT_T,
    FT_t,
    FT_u,
    FT_w,
    FT_W,
    FT_X,
    FT_x,
    FT_z,
    //
    Ampersand,
    AmpersandAmpersand,
    OpenParen,
    CloseParen,
    OpenBrace,
    CloseBrace,
    Comma,
    FatComma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,
    Backtick,

    // One or two character tokens.
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,

    // Literals.
    Identifier,
    DString,
    SString,
    Number,

    // Keywords.
    And,
    Class,
    Field,
    Method,
    Else,
    False,
    For,
    Fun,
    If,
    Undef,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Error,
    Eof,

    /// From: https://zig.news/rbino/using-comptime-to-invert-bijective-functions-on-enums-3pmk
    /// explanation in the comments
    pub fn name(self: TokenType) []const u8 {
        // This won't work for some reason says `idx` is not comptime known
        // const str = comptime blk: {
        //     const idx = @intFromEnum(self);
        //     const str = @typeInfo(TokenType).Enum.fields[idx].name;
        //     break :blk str;
        // };
        // return str;

        switch (self) {
            inline else => |shape| {
                const str = comptime blk: {
                    const idx = @intFromEnum(shape);
                    const str = @typeInfo(TokenType).Enum.fields[idx].name;
                    break :blk str;
                };
                return str;
            },
        }
    }
};
