import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/features.dart';
import '../../core/models.dart';
import '../motion.dart';
import '../screens/home_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Кружки сторис на главной (функция «Сторис»). Содержимое — баннеры из админки.
class StoriesRow extends StatefulWidget {
  final EdgeInsets padding;
  const StoriesRow({super.key, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8)});

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  final _seen = <int>{};

  @override
  Widget build(BuildContext context) {
    if (!has(Feature.stories)) return const SizedBox.shrink();
    final banners = AppState.of(context).catalog?.banners ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: banners.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final b = banners[i];
          final color = b.color ?? t.colorScheme.primary;
          final seen = _seen.contains(i);
          return FadeSlideIn(
            index: i,
            offset: const Offset(20, 0),
            child: Pressable(
              onTap: () async {
                final open = await Navigator.of(context).push<PromoBanner>(
                  PageRouteBuilder(
                    opaque: false,
                    transitionDuration: motionMedium,
                    reverseTransitionDuration: motionMedium,
                    pageBuilder: (_, _, _) => StoryViewer(banners: banners, initial: i),
                    transitionsBuilder: (_, a, _, child) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: a, curve: motionCurve)),
                        child: child,
                      ),
                    ),
                  ),
                );
                if (!context.mounted) return;
                setState(() => _seen.add(i));
                if (open != null) openBanner(context, open);
              },
              child: SizedBox(
                width: 68,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: motionMedium,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: seen ? null : SweepGradient(colors: [color, shiftHue(color, 50, lighten: 0.1), color]),
                        color: seen ? t.colorScheme.outlineVariant : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: t.colorScheme.surface),
                        child: ClipOval(
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: b.image != null
                                ? AppImage(src: b.image, color: color)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [color, shiftHue(color, 30, lighten: 0.1)]),
                                    ),
                                    child: Center(
                                      child: Text(
                                        b.title.characters.first,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Полноэкранный просмотр: полоски прогресса, автопереход, тап влево/вправо, свайп вниз — закрыть.
class StoryViewer extends StatefulWidget {
  final List<PromoBanner> banners;
  final int initial;
  const StoryViewer({super.key, required this.banners, required this.initial});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _i = widget.initial;
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    })
    ..forward();
  double _drag = 0;

  void _next() {
    if (_i < widget.banners.length - 1) {
      setState(() => _i++);
      _c.forward(from: 0);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banners[_i];
    final color = b.color ?? Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTapUp: (d) => d.localPosition.dx < size.width / 3 ? _prev() : _next(),
      onLongPressStart: (_) => _c.stop(),
      onLongPressEnd: (_) => _c.forward(),
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 400)),
      onVerticalDragEnd: (_) {
        if (_drag > 120) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _drag = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Transform.scale(
          scale: 1 - _drag / 2000,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_drag > 0 ? 24 : 0),
            child: Material(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: motionMedium,
                    child: KeyedSubtree(
                      key: ValueKey(_i),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color, shiftHue(color, 40, lighten: -0.1)],
                              ),
                            ),
                          ),
                          if (b.image != null) AppImage(src: b.image, color: color),
                          // Медленный «кен бёрнс» по декоративным кругам.
                          Breathing(
                            period: const Duration(seconds: 5),
                            builder: (_, v) => Stack(
                              children: [
                                Positioned(right: -80 + v * 30, top: 80 - v * 20, child: _circle(260, 0.12)),
                                Positioned(left: -60 - v * 20, bottom: 160 + v * 30, child: _circle(200, 0.08)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(24, top + 80, 24, bottom + 110),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FadeSlideIn(
                                  child: Text(
                                    b.title,
                                    style: Theme.of(context).textTheme.displaySmall
                                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05),
                                  ),
                                ),
                                if (b.subtitle != null) ...[
                                  const SizedBox(height: 12),
                                  FadeSlideIn(
                                    index: 2,
                                    child: Text(b.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Полоски прогресса.
                  Positioned(
                    top: top + 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      spacing: 4,
                      children: [
                        for (var k = 0; k < widget.banners.length; k++)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: AnimatedBuilder(
                                animation: _c,
                                builder: (_, _) => LinearProgressIndicator(
                                  value: k < _i ? 1 : (k == _i ? _c.value : 0),
                                  minHeight: 3,
                                  color: Colors.white,
                                  backgroundColor: Colors.white30,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: top + 20,
                    left: 12,
                    right: 4,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Text(
                            brand.appName.characters.first,
                            style: TextStyle(color: color, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            brand.appName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                  if (b.categoryId != null || b.productId != null)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: bottom + 32,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color),
                        onPressed: () => Navigator.of(context).pop(b),
                        child: Text(S.lang == 'en' ? 'Shop now' : 'Смотреть'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}
