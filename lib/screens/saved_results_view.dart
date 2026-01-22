import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/result_card.dart';

class SavedResultsView extends StatelessWidget {
  const SavedResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pinned = state.pinnedResults;
    final theme = Theme.of(context);

    if (pinned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'No pinned results yet.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pin a result from the chat to save it here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: pinned.length,
      itemBuilder: (context, index) {
        final item = pinned[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PinnedMetaLine(
                pinnedAt: item.pinnedAt,
                locationLabel: item.locationLabel,
              ),
              const SizedBox(height: 6),
              if (item.imagePaths.isNotEmpty)
                _PinnedImageStrip(
                  imagePaths: item.imagePaths,
                  onTap: (index) => _showImageViewer(
                    context,
                    item.imagePaths,
                    index,
                  ),
                ),
              if (item.imagePaths.isNotEmpty) const SizedBox(height: 8),
              ResultCard(
                result: item.result,
                action: FilledButton.tonalIcon(
                  onPressed: () => state.unpinResult(item),
                  icon: const Icon(Icons.close),
                  label: const Text('Unpin'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinnedMetaLine extends StatelessWidget {
  final DateTime pinnedAt;
  final String? locationLabel;

  const _PinnedMetaLine({required this.pinnedAt, this.locationLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd().add_jm().format(pinnedAt);
    final location = locationLabel?.trim();
    final suffix =
        (location == null || location.isEmpty) ? 'Location unavailable' : location;

    return Text(
      'Pinned $date • $suffix',
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PinnedImageStrip extends StatelessWidget {
  final List<String> imagePaths;
  final void Function(int index)? onTap;

  const _PinnedImageStrip({required this.imagePaths, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = imagePaths[index];
          return InkWell(
            onTap: onTap == null ? null : () => onTap!(index),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(path),
                width: 120,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showImageViewer(
  BuildContext context,
  List<String> imagePaths,
  int initialIndex,
) {
  showDialog(
    context: context,
    builder: (context) {
      final controller = PageController(initialPage: initialIndex);
      final currentIndex = ValueNotifier<int>(initialIndex);
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: imagePaths.length,
                  onPageChanged: (index) => currentIndex.value = index,
                  itemBuilder: (context, index) {
                    return _ZoomableImagePage(path: imagePaths[index]);
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: currentIndex,
                    builder: (context, value, _) {
                      return _PageDots(
                        count: imagePaths.length,
                        activeIndex: value,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ZoomableImagePage extends StatefulWidget {
  final String path;

  const _ZoomableImagePage({required this.path});

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _zoomedIn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;

    setState(() {
      if (_zoomedIn) {
        _controller.value = Matrix4.identity();
        _zoomedIn = false;
      } else {
        final scale = 2.5;
        _controller.value = Matrix4.identity()
          ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
          ..scale(scale);
        _zoomedIn = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _PageDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 6,
          height: isActive ? 10 : 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
