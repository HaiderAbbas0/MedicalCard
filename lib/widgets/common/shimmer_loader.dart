import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';

/// A single shimmering placeholder block.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const ShimmerBox(
      {super.key, this.width, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps children in a themed shimmer effect.
class ShimmerWrap extends StatelessWidget {
  final Widget child;
  const ShimmerWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1B2A24) : const Color(0xFFE9EFEC),
      highlightColor: dark ? const Color(0xFF243a32) : const Color(0xFFF6FAF8),
      child: child,
    );
  }
}

/// A reusable list-card skeleton (icon + two lines).
class ShimmerListCard extends StatelessWidget {
  const ShimmerListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.c.border),
      ),
      child: ShimmerWrap(
        child: Row(
          children: [
            const ShimmerBox(width: 46, height: 46, radius: 13),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 150, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [count] shimmer list cards.
class ShimmerList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const ShimmerList(
      {super.key,
      this.count = 5,
      this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [for (var i = 0; i < count; i++) const ShimmerListCard()],
    );
  }
}

/// Drives a fake 1.5s load then swaps to real content.
class FakeLoader extends StatefulWidget {
  final Widget skeleton;
  final WidgetBuilder builder;
  final Duration delay;

  const FakeLoader({
    super.key,
    required this.skeleton,
    required this.builder,
    this.delay = const Duration(milliseconds: 1500),
  });

  @override
  State<FakeLoader> createState() => _FakeLoaderState();
}

class _FakeLoaderState extends State<FakeLoader> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _loading
          ? KeyedSubtree(key: const ValueKey('sk'), child: widget.skeleton)
          : KeyedSubtree(
              key: const ValueKey('content'), child: widget.builder(context)),
    );
  }
}
