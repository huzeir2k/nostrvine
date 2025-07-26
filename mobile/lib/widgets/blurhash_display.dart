// ABOUTME: Widget for displaying blurhash placeholders with smooth transitions
// ABOUTME: Provides progressive image loading experience for video thumbnails

import 'package:flutter/material.dart';
import 'package:openvine/services/blurhash_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Widget that displays a blurhash as a placeholder image
class BlurhashDisplay extends StatefulWidget {
  const BlurhashDisplay({
    required this.blurhash,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });
  
  final String blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<BlurhashDisplay> createState() => _BlurhashDisplayState();
}

class _BlurhashDisplayState extends State<BlurhashDisplay> {
  BlurhashData? _blurhashData;
  
  @override
  void initState() {
    super.initState();
    _decodeBlurhash();
  }
  
  @override
  void didUpdateWidget(BlurhashDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurhash != widget.blurhash) {
      _decodeBlurhash();
    }
  }
  
  void _decodeBlurhash() {
    try {
      Log.debug(
        'Decoding blurhash: ${widget.blurhash.substring(0, 10)}...',
        name: 'BlurhashDisplay',
        category: LogCategory.ui,
      );
      
      final data = BlurhashService.decodeBlurhash(
        widget.blurhash,
        width: 32,  // Small size for performance
        height: 32,
      );
      
      if (mounted && data != null) {
        setState(() {
          _blurhashData = data;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to decode blurhash: $e',
        name: 'BlurhashDisplay',
        category: LogCategory.ui,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Use gradient from blurhash data if available
    if (_blurhashData != null) {
      final colors = _blurhashData!.colors;
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.isNotEmpty 
              ? (colors.length >= 2 
                  ? [
                      Color(colors[0].toARGB32()),
                      Color(colors[1].toARGB32()),
                    ]
                  : [
                      Color(colors[0].toARGB32()),
                      Color(colors[0].toARGB32()).withValues(alpha: 0.7),
                    ])
              : [
                  Color(_blurhashData!.primaryColor.toARGB32()),
                  Color(_blurhashData!.primaryColor.toARGB32()).withValues(alpha: 0.7),
                ],
          ),
        ),
      );
    }
    
    // Fallback gradient while decoding
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade800,
            Colors.grey.shade600,
          ],
        ),
      ),
    );
  }
}

/// Widget that displays a blurhash and smoothly transitions to the actual image
class BlurhashImage extends StatelessWidget {
  const BlurhashImage({
    required this.imageUrl,
    super.key,
    this.blurhash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.errorBuilder,
  });
  
  final String imageUrl;
  final String? blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration fadeInDuration;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  
  @override
  Widget build(BuildContext context) {
    // If no blurhash, just show the image with fade in
    if (blurhash == null || blurhash!.isEmpty) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: fadeInDuration,
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    }
    
    // Show blurhash while loading, then fade in the image
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Blurhash placeholder
        BlurhashDisplay(
          blurhash: blurhash!,
          width: width,
          height: height,
          fit: fit,
        ),
        // Actual image with fade in
        Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame == null) {
              return const SizedBox.shrink();
            }
            return AnimatedOpacity(
              opacity: 1,
              duration: fadeInDuration,
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      ],
    );
  }
}