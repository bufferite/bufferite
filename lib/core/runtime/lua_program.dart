/// Skrip Lua yang dipakai bersama oleh runtime `lua_dart` dan runtime WASM.
///
/// Semantik harus identik: `transform(input, args)` menerima string input dan
/// tabel args, boleh mengembalikan string, dan output `print` ditangkap lalu
/// digabung dengan newline.
String buildLuaTransformScript(
  String source,
  String input,
  Map<String, Object?> args, {
  bool printResult = false,
  bool sandbox = false,
}) {
  final entry = printResult
      ? 'local __result = __bufferite_entry()\nprint = __print\nprint(__result)'
      : 'return __bufferite_entry()';
  final sandboxPrelude = sandbox
      ? '''
io = nil
package = nil
require = nil
debug = nil
dofile = nil
loadfile = nil
os.execute = nil
os.getenv = nil
os.exit = nil
os.remove = nil
os.tmpname = nil
'''
      : '';
  return '''
local __out = {}
local __print = print
print = function(...)
  local n = select('#', ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring((select(i, ...))) end
  __out[#__out + 1] = table.concat(parts, '\\t')
end
$sandboxPrelude
$source
function __bufferite_entry()
  if type(transform) ~= 'function' then
    error('transform(input, args) tidak didefinisikan', 2)
  end
  local ok, res = pcall(transform, ${luaStringLiteral(input)}, ${luaValueLiteral(args)})
  print = __print
  if not ok then error(res, 0) end
  if type(res) == 'string' then return res end
  if #__out == 0 then return '' end
  return table.concat(__out, '\\n') .. '\\n'
end
$entry
''';
}

/// Literal string Lua yang aman untuk byte apa pun.
String luaStringLiteral(String value) {
  final buffer = StringBuffer('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C:
        buffer.write(r'\\');
      case 0x22:
        buffer.write(r'\"');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      default:
        if (rune < 0x20) {
          buffer.write('\\${rune.toString().padLeft(3, '0')}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }
  buffer.write('"');
  return buffer.toString();
}

/// Literal tabel/angka/boolean Lua untuk nilai args.
String luaValueLiteral(Object? value) {
  if (value == null) {
    return 'nil';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is num) {
    return value.toString();
  }
  if (value is String) {
    return luaStringLiteral(value);
  }
  if (value is List<Object?>) {
    return '<${value.map(luaValueLiteral).join(', ')}>';
  }
  if (value is Map<String, Object?>) {
    return '{${value.entries.map((entry) => '[${luaStringLiteral(entry.key)}] = ${luaValueLiteral(entry.value)}').join(', ')}}';
  }
  return luaStringLiteral(value.toString());
}
