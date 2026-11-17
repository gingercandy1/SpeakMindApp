import 'package:material_ui/material_ui.dart';

import '../models.dart';

/// Text colour for a score band, readable on both light and dark backgrounds.
Color levelColor(Level level, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (level) {
    Level.good => dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
    Level.fair => dark ? const Color(0xFFFFB74D) : const Color(0xFFB26A00),
    Level.poor => dark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
    Level.unknown => dark ? const Color(0xFFBDBDBD) : const Color(0xFF616161),
  };
}

String levelLabel(Level level) => switch (level) {
      Level.good => '很好',
      Level.fair => '还需练习',
      Level.poor => '需要纠正',
      Level.unknown => '未评分',
    };

/// The scored sentence: summary, tappable words, and the phonemes of the
/// selected word.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.result,
    required this.selectedWord,
    required this.onSelectWord,
  });

  final Assessment result;
  final int? selectedWord;
  final ValueChanged<int> onSelectWord;

  @override
  Widget build(BuildContext context) {
    final selected = selectedWord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(result: result),
        const SizedBox(height: 20),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final (i, word) in result.words.indexed)
              _WordChip(
                word: word,
                selected: i == selected,
                onTap: () => onSelectWord(i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (selected != null && selected < result.words.length)
          _WordDetail(word: result.words[selected])
        else
          Text(
            '点一个单词查看每个音的得分',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final Assessment result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = levelColor(result.level, theme.brightness);
    final fluency = result.fluency;
    final rate = fluency.phonemesPerSecond;

    return Row(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: result.accuracy / 100,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.18),
                ),
              ),
              Text(
                '${result.accuracy}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发音：${levelLabel(result.level)}',
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (rate != null) '语速 ${rate.toStringAsFixed(1)} 音/秒',
                  fluency.pauses.isEmpty
                      ? '没有明显停顿'
                      : '停顿 ${fluency.pauses.length} 次',
                ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              for (final pause in fluency.pauses)
                Text(
                  '“${pause.after}”之后停了 ${pause.seconds.toStringAsFixed(1)} 秒',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    required this.onTap,
  });

  final WordResult word;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = levelColor(word.level, theme.brightness);
    return Material(
      color: color.withValues(alpha: selected ? 0.28 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? color : Colors.transparent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            word.word,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _WordDetail extends StatelessWidget {
  const _WordDetail({required this.word});

  final WordResult word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = word.score;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score == null ? word.word : '${word.word} · $score 分',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (word.phonemes.isEmpty)
            Text('这个词暂时无法评分', style: theme.textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final phoneme in word.phonemes) _PhonemeTile(phoneme: phoneme),
              ],
            ),
        ],
      ),
    );
  }
}

class _PhonemeTile extends StatelessWidget {
  const _PhonemeTile({required this.phoneme});

  final PhonemeResult phoneme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = levelColor(phoneme.level, theme.brightness);
    final heard = phoneme.heard;
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '/${phoneme.ipa}/',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('${phoneme.score}', style: theme.textTheme.bodySmall?.copyWith(color: color)),
          if (heard != null)
            Text('像 /$heard/', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
