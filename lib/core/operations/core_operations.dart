import '../plugin/operation.dart';
import 'analysis.dart';
import 'crypto.dart';
import 'encode_decode.dart';
import 'format.dart';
import 'hash.dart';
import 'random_ops.dart';
import 'utility.dart';

/// Semua operasi bawaan paket `core.berp` (F13).
///
/// Daftar ini menjadi sumber tunggal untuk manifest paket (dibuat oleh
/// `tool/build_core_berp.dart`) dan untuk registrasi executor saat bootstrap.
final List<Operation> coreOperations = List<Operation>.unmodifiable(<Operation>[
  // Encode/Decode.
  const Base64EncodeOperation(),
  const Base64DecodeOperation(),
  const HexEncodeOperation(),
  const HexDecodeOperation(),
  const UrlEncodeOperation(),
  const UrlDecodeOperation(),
  const HtmlEntityEncodeOperation(),
  const HtmlEntityDecodeOperation(),
  const Base32EncodeOperation(),
  const Base32DecodeOperation(),
  // Format.
  const JsonPrettifyOperation(),
  const JsonMinifyOperation(),
  const JwtDecodeOperation(),
  // Analysis.
  const EntropyOperation(),
  const FrequencyOperation(),
  const FileTypeOperation(),
  const StringsOperation(),
  // Crypto.
  ...hashOperations,
  ...cryptoOperations,
  // Utility.
  const UpperCaseOperation(),
  const LowerCaseOperation(),
  const TitleCaseOperation(),
  const ReverseOperation(),
  const FindReplaceOperation(),
  const RegexReplaceOperation(),
  const SliceOperation(),
  const SortLinesOperation(),
  const UniqueLinesOperation(),
  // Acak.
  const RandomHexOperation(),
  const RandomBytesOperation(),
]);

/// Peta ID operasi ke implementasi Dart-nya.
final Map<String, Operation> coreOperationsById =
    Map<String, Operation>.unmodifiable(<String, Operation>{
      for (final operation in coreOperations) operation.id: operation,
    });
