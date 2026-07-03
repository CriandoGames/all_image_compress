import 'package:flutter_test/flutter_test.dart';

import 'package:all_image_compress/src/semaphore.dart';

void main() {
  group('Semaphore', () {
    test('nunca excede maxConcurrent simultâneos', () async {
      const limit = 2;
      final sem = Semaphore(limit);
      int current = 0;
      int peak = 0;

      await Future.wait(
        List.generate(
            8,
            (_) => sem.run(() async {
                  current++;
                  if (current > peak) peak = current;
                  // Simula trabalho assíncrono
                  await Future.delayed(const Duration(milliseconds: 10));
                  current--;
                })),
      );

      expect(peak, lessThanOrEqualTo(limit),
          reason: 'pico de $peak excedeu o limite $limit');
    });

    test('todos os jobs completam mesmo com fila', () async {
      final sem = Semaphore(2);
      int completed = 0;

      await Future.wait(
        List.generate(
            10,
            (_) => sem.run(() async {
                  await Future.delayed(const Duration(milliseconds: 5));
                  completed++;
                })),
      );

      expect(completed, 10);
    });

    test('release aciona o próximo waiter da fila', () async {
      final sem = Semaphore(1);
      final order = <int>[];

      // Job 0 entra direto, jobs 1 e 2 ficam na fila
      await Future.wait([
        sem.run(() async {
          order.add(0);
          await Future.delayed(const Duration(milliseconds: 10));
        }),
        sem.run(() async {
          order.add(1);
        }),
        sem.run(() async {
          order.add(2);
        }),
      ]);

      // Com limit=1, a ordem de execução deve ser FIFO: 0, 1, 2
      expect(order, [0, 1, 2]);
    });

    test('acquire/release manuais funcionam sem run()', () async {
      final sem = Semaphore(1);
      await sem.acquire();
      var secondAcquired = false;

      // Segunda acquire fica bloqueada enquanto a primeira não liberar
      final second = sem.acquire().then((_) => secondAcquired = true);

      expect(secondAcquired, isFalse);
      sem.release();
      await second;
      expect(secondAcquired, isTrue);
      sem.release(); // limpa estado
    });
  });
}
