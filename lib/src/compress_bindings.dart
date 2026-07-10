import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Mapeamento exato da Struct gerada no Rust
final class NativeCompressResult extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> bytes_ptr;

  @ffi.Size()
  external int bytes_len;

  @ffi.Uint32()
  external int width;

  @ffi.Uint32()
  external int height;
}

// Definições de tipo para as funções do FFI
typedef _RustCompressNative = NativeCompressResult Function(
  ffi.Pointer<ffi.Uint8> input_ptr,
  ffi.Size input_len,
  ffi.Uint8 quality,
  ffi.Int32 max_width,
  ffi.Int32 max_height,
);
typedef _RustCompressDart = NativeCompressResult Function(
  ffi.Pointer<ffi.Uint8> input_ptr,
  int input_len,
  int quality,
  int max_width,
  int max_height,
);

typedef _RustFreeBytesNative = ffi.Void Function(
    ffi.Pointer<ffi.Uint8> ptr, ffi.Size len);
typedef _RustFreeBytesDart = void Function(ffi.Pointer<ffi.Uint8> ptr, int len);

class NativeCompressor {
  late final _RustCompressDart _compressFn;
  late final _RustFreeBytesDart _freeFn;

  NativeCompressor() {
    _initDynamicLibrary();
  }

  void _initDynamicLibrary() {
    // Detecta o sistema operacional e carrega o arquivo binário correspondente
    final ffi.DynamicLibrary dylib;
    if (Platform.isAndroid || Platform.isLinux) {
      dylib = ffi.DynamicLibrary.open('libimage_compressor.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      dylib = ffi.DynamicLibrary
          .process(); // Em iOS/macOS estático linka direto no processo
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

  Uint8List performCompression(
      Uint8List inputBytes, int quality, int maxWidth, int maxHeight) {
    // 1. Aloca os bytes de entrada na memória nativa fora da Heap do Dart
    final ffi.Pointer<ffi.Uint8> inputPointer =
        malloc.allocate<ffi.Uint8>(inputBytes.length);

    // 2. Copia os dados controlados pelo Dart para a memória nativa recém-alocada
    final pointerList = inputPointer.asTypedList(inputBytes.length);
    pointerList.setAll(0, inputBytes);

    // 3. Executa a função C em Rust de altíssima performance
    final result = _compressFn(
      inputPointer,
      inputBytes.length,
      quality,
      maxWidth,
      maxHeight,
    );

    // Validação caso ocorra erro de decodificação no Rust
    if (result.bytes_ptr.address == 0) {
      malloc.free(inputPointer);
      throw ArgumentError(
          'O compressor nativo não conseguiu decodificar ou processar esta imagem.');
    }

    // 4. Cria uma cópia segura dos bytes processados de volta para o ecossistema do Dart (Gerenciado pelo Garbage Collector)
    final Uint8List outputBytes = Uint8List.fromList(
      result.bytes_ptr.asTypedList(result.bytes_len),
    );

    // 5. LIMPEZA ABSOLUTA DE MEMÓRIA (Evita vazamentos)
    malloc.free(inputPointer); // Libera o buffer que o Dart alocou
    _freeFn(
        result.bytes_ptr,
        result
            .bytes_len); // Manda o Rust liberar o buffer de saída que ele alocou

    return outputBytes;
  }
}
