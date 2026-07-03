import 'dart:async';

/// Limita quantas operações assíncronas rodam simultaneamente.
///
/// Usado pelo batch para evitar spawnar dezenas de isolates ao mesmo tempo,
/// o que causaria picos de memória e degradação de performance.
///
/// Exemplo — processar 50 imagens com no máximo 4 simultâneas:
/// ```dart
/// final sem = Semaphore(4);
/// await Future.wait(images.map((img) async {
///   await sem.acquire();
///   try { await process(img); } finally { sem.release(); }
/// }));
/// ```
class Semaphore {
  Semaphore(this.maxConcurrent) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  int _running = 0;
  final _queue = <Completer<void>>[];

  /// Aguarda uma vaga disponível e a ocupa.
  Future<void> acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final slot = Completer<void>();
    _queue.add(slot);
    await slot.future;
    _running++;
  }

  /// Libera a vaga, desbloqueando o próximo waiter da fila (se houver).
  void release() {
    _running--;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    }
  }

  /// Executa [fn] protegido pelo semáforo (acquire → fn → release).
  Future<T> run<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}
