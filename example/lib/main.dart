import 'dart:isolate';
import 'dart:typed_data';

import 'package:all_image_compress/all_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const ExampleApp());

// ─── App ─────────────────────────────────────────────────────────────────────

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'all_image_compress Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0055FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CompressPage(),
    );
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class _QualityResult {
  const _QualityResult({required this.quality, required this.result});
  final int quality;
  final CompressResult result;
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CompressPage extends StatefulWidget {
  const CompressPage({super.key});

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  bool _loading = false;
  String _status = 'Toque em um botão para rodar a demo.';

  int _originalSize = 0;
  List<_QualityResult> _qualityResults = [];
  List<CompressResult?> _batchResults = [];

  // ── Geração de imagem de teste (top-level para Isolate.run) ────────────────

  static Uint8List _makeGradientJpeg(List<int> dims) {
    final image = img.Image(width: dims[0], height: dims[1]);
    for (final pixel in image) {
      pixel
        ..r = (pixel.x * 255 ~/ dims[0])
        ..g = (pixel.y * 255 ~/ dims[1])
        ..b = ((pixel.x + pixel.y) * 255 ~/ (dims[0] + dims[1]));
    }
    return img.encodeJpg(image, quality: 95);
  }

  static Uint8List _makeColorJpeg(List<int> args) {
    // args: [width, height, hue-shift]
    final image = img.Image(width: args[0], height: args[1]);
    final shift = args[2];
    for (final pixel in image) {
      pixel
        ..r = (pixel.x + shift * 30) % 256
        ..g = (pixel.y + shift * 20) % 256
        ..b = (pixel.x + pixel.y + shift * 15) % 256;
    }
    return img.encodeJpg(image, quality: 90);
  }

  // ── Demo 1: qualidade variada ───────────────────────────────────────────────

  Future<void> _runQualityDemo() async {
    setState(() {
      _loading = true;
      _status = 'Gerando imagem de teste 1920×1080…';
      _qualityResults = [];
      _batchResults = [];
    });

    // Gera a imagem em isolate para não bloquear a UI
    final rawBytes = await Isolate.run(() => _makeGradientJpeg([1920, 1080]));
    _originalSize = rawBytes.length;

    setState(() => _status = 'Comprimindo em 4 níveis de qualidade…');

    // Batch com 4 configurações distintas
    const configs = [
      (90, CompressConfig(quality: 90, maxWidth: 1920, maxHeight: 1080)),
      (70, CompressConfig(quality: 70, maxWidth: 1280, maxHeight: 720)),
      (50, CompressConfig(quality: 50, maxWidth: 800, maxHeight: 450)),
      (20, CompressConfig(quality: 20, maxWidth: 480, maxHeight: 270)),
    ];

    final results = await AllImageCompress.batch(
      items: configs.map((c) => (rawBytes, c.$2)).toList(),
      maxConcurrent: 2,
      onProgress: (done, total) {
        setState(() => _status = 'Comprimindo… $done/$total');
      },
    );

    setState(() {
      _qualityResults = List.generate(
        results.length,
        (i) => _QualityResult(quality: configs[i].$1, result: results[i]!),
      );
      _loading = false;
      _status = 'Pronto! Original: ${_formatSize(_originalSize)}';
    });
  }

  // ── Demo 2: batch com progresso ─────────────────────────────────────────────

  Future<void> _runBatchDemo() async {
    setState(() {
      _loading = true;
      _batchResults = [];
      _qualityResults = [];
      _status = 'Gerando 8 imagens para batch…';
    });

    // 8 imagens geradas em isolate (tamanhos crescentes)
    final images = await Future.wait(
      List.generate(
        8,
        (i) =>
            Isolate.run(() => _makeColorJpeg([200 + i * 100, 150 + i * 75, i])),
      ),
    );

    setState(
      () => _status = 'Executando batch de 8 imagens (maxConcurrent: 3)…',
    );

    final results = await AllImageCompress.batchUniform(
      images: images,
      config: const CompressConfig(quality: 65, maxWidth: 400, maxHeight: 300),
      maxConcurrent: 3,
      onProgress: (done, total) {
        setState(() => _status = 'Batch: $done/$total concluídos');
      },
    );

    setState(() {
      _batchResults = results;
      _loading = false;
      _status = 'Batch finalizado — ${results.length} imagens processadas!';
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  static Color _qualityColor(int quality) {
    if (quality >= 80) return Colors.green;
    if (quality >= 60) return Colors.lightGreen;
    if (quality >= 40) return Colors.orange;
    return Colors.red;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('all_image_compress'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status ───────────────────────────────────────────────────────
            _SectionCard(
              title: '🗜️ Demo',
              child: Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Botões ───────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _runQualityDemo,
                    icon: const Icon(Icons.tune),
                    label: const Text('Qualidade variada'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _runBatchDemo,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Batch (8 imagens)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Progress ─────────────────────────────────────────────────────
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],

            // ── Resultados: qualidade ─────────────────────────────────────────
            if (_qualityResults.isNotEmpty) ...[
              _SectionCard(
                title:
                    '📊 Qualidade variada — original: ${_formatSize(_originalSize)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._qualityResults.map(
                      (r) => _ResultRow(
                        label:
                            'Q${r.quality} — ${r.result.width}×${r.result.height}px',
                        size: _formatSize(r.result.compressedSizeBytes),
                        savings:
                            '-${r.result.savedPercent.toStringAsFixed(1)}%',
                        color: _qualityColor(r.quality),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Preview (qualidade 20):',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _qualityResults.last.result.bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Resultados: batch ─────────────────────────────────────────────
            if (_batchResults.isNotEmpty) ...[
              _SectionCard(
                title: '🗂️ Batch — ${_batchResults.length} imagens',
                child: Column(
                  children: _batchResults.indexed
                      .map(
                        (e) => _ResultRow(
                          label:
                              'Imagem ${e.$1 + 1} — ${e.$2!.width}×${e.$2!.height}px',
                          size: _formatSize(e.$2!.compressedSizeBytes),
                          savings: '-${e.$2!.savedPercent.toStringAsFixed(1)}%',
                          color: theme.colorScheme.tertiary,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Código de exemplo ─────────────────────────────────────────────
            _SectionCard(
              title: '📝 Como usar',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r'''// Compressão simples (roda em Isolate)
final result = await AllImageCompress.fromBytes(
  bytes: imageBytes,
  config: CompressConfig(
    quality: 80,
    maxWidth: 1920,
    maxHeight: 1080,
  ),
);
print(result.summary);
// → "3.20MB → 410KB (-87.5%) 1920×1080px [JPEG]"

// Batch com progresso
final results = await AllImageCompress.batchUniform(
  images: myImages,
  config: CompressConfig(quality: 70, maxWidth: 800),
  maxConcurrent: 3,
  onProgress: (done, total) => print('$done/$total'),
);''',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.size,
    required this.savings,
    required this.color,
  });
  final String label;
  final String size;
  final String savings;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            size,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(savings, style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
