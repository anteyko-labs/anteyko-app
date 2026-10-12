import 'package:flutter/material.dart';

import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/features.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../motion.dart';

const starColor = Color(0xFFF5A524);

/// «★ 4.8 (12)» — компактно для карточек.
class RatingBadge extends StatelessWidget {
  final Product product;
  final double size;
  const RatingBadge({super.key, required this.product, this.size = 13});

  @override
  Widget build(BuildContext context) {
    if (!has(Feature.reviews)) return const SizedBox.shrink();
    final (avg, n) = AppState.of(context).ratingFor(product.id);
    if (n == 0) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: starColor),
        const SizedBox(width: 2),
        Text(
          avg.toStringAsFixed(1),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
        ),
        Text(
          ' ($n)',
          style: TextStyle(fontSize: size, color: muted),
        ),
      ],
    );
  }
}

class Stars extends StatelessWidget {
  final double value;
  final double size;
  const Stars(this.value, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: size,
          color: starColor,
        ),
    ],
  );
}

/// Блок отзывов на странице товара.
class ReviewsSection extends StatelessWidget {
  final Product product;
  const ReviewsSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    if (!has(Feature.reviews)) return const SizedBox.shrink();
    final t = Theme.of(context);
    final state = AppState.of(context);
    final (avg, n) = state.ratingFor(product.id);
    final list = state.reviewsFor(product.id);
    final dist = List.filled(5, 0);
    for (final r in list) {
      dist[(r.rating - 1).clamp(0, 4)]++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(S.reviews, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(S.writeReview),
              onPressed: () => _write(context),
            ),
          ],
        ),
        if (n == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(S.noReviews, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
          )
        else ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(avg.toStringAsFixed(1), style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  Stars(avg, size: 16),
                  const SizedBox(height: 2),
                  Text('$n', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (var s = 5; s >= 1; s--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(width: 14, child: Text('$s', style: t.textTheme.labelSmall)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: dist[s - 1] / n),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: v,
                                    minHeight: 6,
                                    color: starColor,
                                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, r) in list.take(5).indexed)
            FadeSlideIn(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 14, child: Text(r.name.characters.first, style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Stars(r.rating.toDouble(), size: 14),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.text),
                    const SizedBox(height: 6),
                    Text(
                      formatDate(r.createdAt).split(' ').first,
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _write(BuildContext context) {
    final state = AppState.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewForm(onSend: (rating, text) => state.addReview(product.id, rating, text)),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final Future<void> Function(int rating, String text) onSend;
  const _ReviewForm({required this.onSend});

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _rating = 5;
  final _text = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: AnimatedSwitcher(
        duration: motionMedium,
        child: _sent
            ? Column(
                key: const ValueKey('sent'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 56, color: Color(0xFF16A34A)),
                  const SizedBox(height: 12),
                  Text(S.reviewThanks, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
                  const SizedBox(height: 16),
                ],
              )
            : Column(
                key: const ValueKey('form'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(S.yourRating, style: t.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Pressable(
                          scale: 0.8,
                          onTap: () => setState(() => _rating = i),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedScale(
                              scale: i <= _rating ? 1.1 : 1,
                              duration: motionFast,
                              child: Icon(
                                i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 40,
                                color: starColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(hintText: S.reviewText),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (_text.text.trim().isEmpty) return;
                      await widget.onSend(_rating, _text.text.trim());
                      if (mounted) setState(() => _sent = true);
                    },
                    child: Text(S.send),
                  ),
                ],
              ),
      ),
    );
  }
}
