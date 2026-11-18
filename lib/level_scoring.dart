/// F1: pure star and pronunciation scoring for a level.
///
/// Kept free of Flutter so the rules can be unit-tested directly.
/// Star rules (levels dev doc §6, W1-W2):
///
/// * 1★ — dialogue rounds finished + challenge passed.
/// * 2★ — 1★ + the pronunciation average reaches the world's pass line.
/// * 3★ — 2★ + the challenge sentence is "excellent" (GOP >= 90).
///
/// W1-W2 hints are unlimited, so no hint cap applies here.
///
/// The pronunciation average is the mean GOP of every scored spoken item
/// (the shadowing sentences plus the challenge sentence). A sentence that
/// was never scored — skipped after a scoring failure — counts as 0, so
/// skipping never helps. Dialogue turns are free speech and cannot be
/// GOP-scored; they only count toward the 1★ rounds requirement.
library;

/// GOP threshold for a challenge sentence to count as "excellent".
const int challengeExcellentGop = 90;

/// How many shadowing sentences must reach the pass line to move on:
/// 2 of 3 when there are 3 sentences, all of them when there are fewer.
int neededShadowPasses(int sentenceCount) =>
    sentenceCount >= 3 ? 2 : sentenceCount;

/// Mean GOP of the scored spoken items, unscored items counting as 0.
double pronunciationAverage(List<int?> scores) {
  if (scores.isEmpty) return 0;
  var sum = 0;
  for (final s in scores) {
    sum += s ?? 0;
  }
  return sum / scores.length;
}

/// Stars earned for a finished level (0 only when the gates were not met).
int computeStars({
  required bool dialogueDone,
  required bool challengePassed,
  required bool challengeExcellent,
  required double pronunciationAvg,
  required int passGop,
}) {
  if (!dialogueDone || !challengePassed) return 0;
  if (pronunciationAvg < passGop) return 1;
  return challengeExcellent ? 3 : 2;
}

/// Brasa's encouragement line on the results screen, by stars earned.
String brasaComment(int stars) => switch (stars) {
      3 => '¡Increíble! 三颗星，发音和任务都超棒，继续冲！',
      2 => '¡Muy bien! 两颗星，挑战句子再练练就能拿满星。',
      _ => '¡Buen trabajo! 通关啦，再打一次，星星会越来越多。',
    };
