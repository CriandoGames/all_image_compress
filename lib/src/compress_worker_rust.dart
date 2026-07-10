import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'compress_config.dart';
import 'compress_format.dart';
import 'compress_result.dart';

// ── 1. PARÂMETROS DO TRABALHADOR ─────────────────────────────────────────────
/// Parâmetros mínimos e limpos passados para o isolate.
class _WorkerParams {
  const _WorkerParams({
    required this.bytes,
    required this.config,
  });
  final Uint8List bytes;
  final CompressConfig config;
}

// ── 2. STRUCT DE COMUNICAÇÃO FFI (IGUAL AO RUST) ──────────────────────────────
/// Mapeamento exato da Struct gerada no Rust para receber os dados de volta.
final class NativeCompressResult extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> bytes_ptr;

  @ffi.Size()
  external int bytes_len;

  @ffi.Uint32()
  external int width;

  @ffi.Uint32()
  external int height;
}

// Definições de tipos exigidas pelo sistema de FFI do Dart
typedef _RustCompressNative = NativeCompressResult Function(
  ffi.Pointer<ffi.Uint8> input_ptr,
  ffi.Size input_len,
  ffi.Uint8 quality,
  ffi.Int32 max_width,
  ffi.Int32 max_height,
  ffi.Int32 format_type,
);
typedef _RustCompressDart = NativeCompressResult Function(
  ffi.Pointer<ffi.Uint8> input_ptr,
  int input_len,
  int quality,
  int max_width,
  int max_height,
  int format_type,
);

typedef _RustFreeBytesNative = ffi.Void Function(
    ffi.Pointer<ffi.Uint8> ptr, ffi.Size len);
typedef _RustFreeBytesDart = void Function(ffi.Pointer<ffi.Uint8> ptr, int len);

// ── 3. PONTE DE COMUNICAÇÃO NATIVA (FFI) ─────────────────────────────────────
class NativeCompressor {
  late final _RustCompressDart _compressFn;
  late final _RustFreeBytesDart _freeFn;

  NativeCompressor() {
    _initDynamicLibrary();
  }

  void _initDynamicLibrary() {
    final ffi.DynamicLibrary dylib;

    if (Platform.isMacOS) {
      final currentPath = Directory.current.path;
      final dylibPath = '$currentPath/target/release/libimage_compressor.dylib';

      if (!File(dylibPath).existsSync()) {
        throw FileSystemException(
            'O binário do Rust não foi encontrado no caminho de desenvolvimento.\n'
            'Certifique-se de rodar "cargo build --release" na raiz do pacote.\n'
            'Caminho tentado: $dylibPath');
      }

      dylib = ffi.DynamicLibrary.open(dylibPath);
    } else if (Platform.isAndroid || Platform.isLinux) {
      dylib = ffi.DynamicLibrary.open('libimage_compressor.so');
    } else if (Platform.isIOS) {
      dylib = ffi.DynamicLibrary.process();
    } else if (Platform.isWindows) {
      dylib = ffi.DynamicLibrary.open('image_compressor.dll');
    } else {
      throw UnsupportedError(
          'Plataforma não suportada pelo compressor nativo.');
    }

    _compressFn = dylib
        .lookup<ffi.NativeFunction<_RustCompressNative>>('rust_compress')
        .asFunction<_RustCompressDart>();

    _freeFn = dylib
        .lookup<ffi.NativeFunction<_RustFreeBytesNative>>('rust_free_bytes')
        .asFunction<_RustFreeBytesDart>();
  }

  /// Converte o enum do Dart em um ID numérico inteligível para o motor do Rust
  int _getFormatType(CompressFormat format) {
    switch (format) {
      case CompressFormat.jpeg:
        return 0;
      case CompressFormat.png:
        return 1;
      case CompressFormat.webp:
        return 2;
      case CompressFormat.gif:
        return 3;
      case CompressFormat.bmp:
        return 4;
      case CompressFormat.tiff:
        return 5;
      default:
        return 0; // Fallback seguro para JPEG
    }
  }

  /// Resolve de forma autônoma o formato final de saída.
  /// Se o formato de configuração for nulo, lê o cabeçalho binário (Magic Numbers) da imagem original.
  CompressFormat _resolveOutputFormat(
      CompressFormat? configFormat, Uint8List bytes) {
    if (configFormat != null) {
      return configFormat;
    }

    // Se o usuário quer manter o original, analisamos os primeiros bytes da imagem
    if (bytes.length >= 4) {
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return CompressFormat.png;
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return CompressFormat.jpeg;
      }
      // WebP: Começa com RIFF [52 49 46 46] e tem WEBP na posição 8
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return CompressFormat.webp;
      }
      // GIF: "GIF8" [47 49 46 38]
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return CompressFormat.gif;
      }
      // BMP: "BM" [42 4D]
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return CompressFormat.bmp;
      }
    }

    // Fallback padrão universal caso o formato original não seja reconhecido
    return CompressFormat.jpeg;
  }

  /// Faz a chamada ao Rust cuidando da alocação e limpeza de memória nativa
  CompressResult execute(Uint8List inputBytes, CompressConfig config) {
    // 1. Resolve dinamicamente o formato usando análise binária (sem precisar de parâmetros extras)
    final outFormat = _resolveOutputFormat(config.outputFormat, inputBytes);

    // 2. Aloca os bytes da imagem na memória nativa (fora da Heap do Dart)
    final ffi.Pointer<ffi.Uint8> inputPointer =
        malloc.allocate<ffi.Uint8>(inputBytes.length);

    // 3. Copia os dados do Dart para essa memória nativa
    final pointerList = inputPointer.asTypedList(inputBytes.length);
    pointerList.setAll(0, inputBytes);

    // Traduz o formato resolvido para o índice numérico aceito no Rust
    final formatType = _getFormatType(outFormat);

    // 4. Executa a função em Rust enviando o formato mapeado
    final result = _compressFn(
      inputPointer,
      inputBytes.length,
      config.quality,
      config.maxWidth ?? -1,
      config.maxHeight ?? -1,
      formatType,
    );

    // Validação caso o Rust falhe em decodificar
    if (result.bytes_ptr.address == 0) {
      malloc.free(inputPointer);
      throw ArgumentError(
          'O compressor nativo não conseguiu decodificar ou processar esta imagem.');
    }

    // 5. Copia os bytes gerados pelo Rust de volta para o Dart
    final Uint8List outputBytes = Uint8List.fromList(
      result.bytes_ptr.asTypedList(result.bytes_len),
    );

    // 6. LIMPEZA DA MEMÓRIA NATIVA
    malloc.free(inputPointer);
    _freeFn(result.bytes_ptr, result.bytes_len);

    // Retorna o resultado com o formato real que foi resolvido e processado
    return CompressResult(
      bytes: outputBytes,
      width: result.width,
      height: result.height,
      format: outFormat,
      originalSizeBytes: inputBytes.length,
    );
  }
}

// Instanciamos o compressor globalmente dentro do worker para reutilizar os bindings nativos
final _nativeCompressor = NativeCompressor();

// ── 4. PIPELINE PRINCIPAL CHAMADO PELOS ISOLATES ─────────────────────────────

/// Função de alto nível que roda o pipeline de compressão de forma síncrona.
/// É chamada diretamente pelo `Isolate.run` na API assíncrona do arquivo principal.
CompressResult runCompressRust(Uint8List inputBytes, CompressConfig config) {
  return _doCompress(_WorkerParams(bytes: inputBytes, config: config));
}

/// Esta função de processamento é executada isoladamente e chama o compressor nativo
CompressResult _doCompress(_WorkerParams p) {
  return _nativeCompressor.execute(p.bytes, p.config);
}
