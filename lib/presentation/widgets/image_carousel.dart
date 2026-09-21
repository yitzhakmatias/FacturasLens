import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class ImageCarousel extends StatefulWidget {
  const ImageCarousel({super.key, required this.paths, this.onRemove});

  final List<String> paths;
  final ValueChanged<int>? onRemove;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.ink),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white.withValues(alpha: 0.6),
            size: 36,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.ink),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.paths.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                return Image.file(
                  File(widget.paths[index]),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _Badge(
              text: 'Captura ${_index + 1} de ${widget.paths.length}',
            ),
          ),
          if (widget.onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => widget.onRemove!(_index),
              ),
            ),
          if (widget.paths.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.paths.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
