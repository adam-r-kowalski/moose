const std = @import("std");
const atom = @import("atom");

test "tokenize add then multiply" {
    const allocator = std.testing.allocator;
    const source = "x + y * z";
    const actual = try atom.testing.tokenize(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\symbol x
        \\plus
        \\symbol y
        \\times
        \\symbol z
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse add" {
    const allocator = std.testing.allocator;
    const source = "x + y";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(+ x y)";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse add then multiply" {
    const allocator = std.testing.allocator;
    const source = "x + y * z";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(+ x (* y z))";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse multiply then add" {
    const allocator = std.testing.allocator;
    const source = "x * y + z";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(+ (* x y) z)";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse multiply then grouped add" {
    const allocator = std.testing.allocator;
    const source = "x * (y + z)";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(* x (+ y z))";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse multiply is left associative" {
    const allocator = std.testing.allocator;
    const source = "x * y * z";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(* (* x y) z)";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse exponentiate is right associative" {
    const allocator = std.testing.allocator;
    const source = "x ^ y ^ z";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(^ x (^ y z))";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse greater has lower precedence then add" {
    const allocator = std.testing.allocator;
    const source = "a + b > c + d";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(> (+ a b) (+ c d))";
    try std.testing.expectEqualStrings(expected, actual);
}

test "parse grouped greater" {
    const allocator = std.testing.allocator;
    const source = "a + (b > c) + d";
    const actual = try atom.testing.parse(allocator, source);
    defer allocator.free(actual);
    const expected = "(+ a (+ (> b c) d))";
    try std.testing.expectEqualStrings(expected, actual);
}

test "type infer binary op add" {
    const allocator = std.testing.allocator;
    const source = "add = fn(x: i32, y: i32) i32 { x + y }";
    const actual = try atom.testing.typeInfer(allocator, source, "add");
    defer allocator.free(actual);
    const expected =
        \\define =
        \\    name = symbol{ name = add, type = fn(i32, i32) i32 }
        \\    type = void
        \\    value = 
        \\        function =
        \\            parameters =
        \\                symbol{ name = x, type = i32 }
        \\                symbol{ name = y, type = i32 }
        \\            return_type = i32
        \\            body = 
        \\                binary_op =
        \\                    kind = +
        \\                    left = symbol{ name = x, type = i32 }
        \\                    right = symbol{ name = y, type = i32 }
        \\                    type = i32
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "type infer binary op multiply" {
    const allocator = std.testing.allocator;
    const source = "multiply = fn(x: i32, y: i32) i32 { x * y }";
    const actual = try atom.testing.typeInfer(allocator, source, "multiply");
    defer allocator.free(actual);
    const expected =
        \\define =
        \\    name = symbol{ name = multiply, type = fn(i32, i32) i32 }
        \\    type = void
        \\    value = 
        \\        function =
        \\            parameters =
        \\                symbol{ name = x, type = i32 }
        \\                symbol{ name = y, type = i32 }
        \\            return_type = i32
        \\            body = 
        \\                binary_op =
        \\                    kind = *
        \\                    left = symbol{ name = x, type = i32 }
        \\                    right = symbol{ name = y, type = i32 }
        \\                    type = i32
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "type infer binary op multiply then add" {
    const allocator = std.testing.allocator;
    const source = "f = fn(x: i32, y: i32, z: i32) i32 { x * y + z }";
    const actual = try atom.testing.typeInfer(allocator, source, "f");
    defer allocator.free(actual);
    const expected =
        \\define =
        \\    name = symbol{ name = f, type = fn(i32, i32, i32) i32 }
        \\    type = void
        \\    value = 
        \\        function =
        \\            parameters =
        \\                symbol{ name = x, type = i32 }
        \\                symbol{ name = y, type = i32 }
        \\                symbol{ name = z, type = i32 }
        \\            return_type = i32
        \\            body = 
        \\                binary_op =
        \\                    kind = +
        \\                    left = 
        \\                        binary_op =
        \\                            kind = *
        \\                            left = symbol{ name = x, type = i32 }
        \\                            right = symbol{ name = y, type = i32 }
        \\                            type = i32
        \\                    right = symbol{ name = z, type = i32 }
        \\                    type = i32
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op i32.add" {
    const allocator = std.testing.allocator;
    const source = "start = fn() i32 { 42 + 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result i32)
        \\        (i32.add
        \\            (i32.const 42)
        \\            (i32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op i32.sub" {
    const allocator = std.testing.allocator;
    const source = "start = fn() i32 { 42 - 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result i32)
        \\        (i32.sub
        \\            (i32.const 42)
        \\            (i32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op f32.add" {
    const allocator = std.testing.allocator;
    const source = "start = fn() f32 { 42 + 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result f32)
        \\        (f32.add
        \\            (f32.const 42)
        \\            (f32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op f32.sub" {
    const allocator = std.testing.allocator;
    const source = "start = fn() f32 { 42 - 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result f32)
        \\        (f32.sub
        \\            (f32.const 42)
        \\            (f32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op i32.mul" {
    const allocator = std.testing.allocator;
    const source = "start = fn() i32 { 42 * 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result i32)
        \\        (i32.mul
        \\            (i32.const 42)
        \\            (i32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen binary op f32.mul" {
    const allocator = std.testing.allocator;
    const source = "start = fn() f32 { 42 * 29 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result f32)
        \\        (f32.mul
        \\            (f32.const 42)
        \\            (f32.const 29)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen nested binary op f32.add and f32.mul" {
    const allocator = std.testing.allocator;
    const source = "start = fn() f32 { 42 * 29 + 15 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (result f32)
        \\        (f32.add
        \\            (f32.mul
        \\                (f32.const 42)
        \\                (f32.const 29))
        \\            (f32.const 15)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen i32.eq" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: i32, y: i32) bool { x == y }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x i32) (param $y i32) (result i32)
        \\        (i32.eq
        \\            (local.get $x)
        \\            (local.get $y)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen f32.eq" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: f32, y: f32) bool { x == y }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x f32) (param $y f32) (result i32)
        \\        (f32.eq
        \\            (local.get $x)
        \\            (local.get $y)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen i32.rem_s" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: i32) bool { x % 2 == 0 }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x i32) (result i32)
        \\        (i32.eq
        \\            (i32.rem_s
        \\                (local.get $x)
        \\                (i32.const 2))
        \\            (i32.const 0)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen i32.or" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: bool, y: bool) bool { x or y }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x i32) (param $y i32) (result i32)
        \\        (i32.or
        \\            (local.get $x)
        \\            (local.get $y)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen i32.gt_s" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: i32, y: i32) bool { x > y }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x i32) (param $y i32) (result i32)
        \\        (i32.gt_s
        \\            (local.get $x)
        \\            (local.get $y)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "codegen f32.gt" {
    const allocator = std.testing.allocator;
    const source = "start = fn(x: f32, y: f32) bool { x > y }";
    const actual = try atom.testing.codegen(allocator, source);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $start (param $x f32) (param $y f32) (result i32)
        \\        (f32.gt
        \\            (local.get $x)
        \\            (local.get $y)))
        \\
        \\    (export "_start" (func $start)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
