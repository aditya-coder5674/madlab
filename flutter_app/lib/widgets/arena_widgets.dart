import 'package:flutter/material.dart';

class SectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeading({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
        if (trailing != null)
          Text(trailing!,
              style: const TextStyle(color: Color(0xFFA8BBC5), fontSize: 12)),
      ]);
}

class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge(this.difficulty, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty.toLowerCase()) {
      'easy' => const Color(0xFF72D7A5),
      'medium' || 'moderate' => const Color(0xFFFFC46B),
      'hard' => const Color(0xFFFF8585),
      _ => const Color(0xFFA8BBC5),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5)),
      child: Text(difficulty,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class ApiNotice extends StatelessWidget {
  final String message;
  final bool error;

  const ApiNotice({super.key, required this.message, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFFF8585) : const Color(0xFF55DCE5);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline : Icons.info_outline,
            color: color, size: 18),
        const SizedBox(width: 9),
        Expanded(
            child: Text(message,
                style: const TextStyle(height: 1.35, fontSize: 13))),
      ]),
    );
  }
}

class LoadingPane extends StatelessWidget {
  final String label;

  const LoadingPane({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFFA8BBC5))),
        ]),
      );
}
