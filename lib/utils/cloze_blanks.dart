/// Fase 2's blank derivation (`SPEC.md` §5.2, `DATA_MODEL.md` §4) — built
/// entirely on top of `story_markers.dart`'s [parseStoryMarkers], never a
/// new marker-parsing implementation (`CLAUDE.md` §4). No AI call: blanks
/// and answer choices come straight from the already-generated, already-
/// marked story.
///
/// **One blank per target word.** If a target word's marker appears more
/// than once in the story, only the *first* occurrence becomes a blank —
/// every later occurrence of that same word is classified as
/// [ClozeHighlightSegment] instead (`DATA_MODEL.md` §4's original rule:
/// "hanya penanda pertama yang jadi blank; sisanya dirender sebagai teks
/// biasa").
///
/// As of Milestone 7 Phase 2 (Stages 1–2), a repeat occurrence should
/// never actually reach this function in the live app: the Worker
/// (`vocably-ai-worker/src/handlers/generateStory.ts`'s `validateMarkers()`)
/// and the client (`storyMarkersMatchWordIds`, below) both reject any
/// story where a target word is marked more than once, *before* it's ever
/// written to state or shown to a student. [ClozeHighlightSegment]
/// remains purely as a defensive fallback — see its own doc comment for
/// why it's kept rather than deleted, and Stage 4's note on how it must
/// be rendered if it's ever produced.
library;

import 'story_markers.dart';

/// One piece of a cloze-ified story: plain text, a repeated (non-blank)
/// highlighted occurrence, or an actual blank the student answers.
sealed class ClozeSegment {
  const ClozeSegment();
}

/// Plain text between/around markers — identical to
/// `PlainStorySegment`, just re-typed for this file's own sealed family.
class ClozePlainSegment extends ClozeSegment {
  const ClozePlainSegment(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is ClozePlainSegment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ClozePlainSegment($text)';
}

/// A target word's second-or-later occurrence — not turned into a blank
/// (grading is keyed by `targetWord`, one entry per word, so a second
/// occurrence has nowhere sensible to attach its own blank).
///
/// **Milestone 7 Phase 2 Stage 4:** despite the class name (kept for
/// minimal diff/history), this must be rendered as *plain* text, never
/// highlighted — a highlighted repeat would show the student the exact
/// answer to the blank they just left for this same word, defeating the
/// point of the cloze test (the original bug this stage fixed). See
/// [buildClozeSegments]'s doc comment for why this segment type should
/// no longer actually occur in the live app at all; kept only as a
/// defensive fallback so a violation of that invariant degrades to plain
/// text rather than leaking the answer or crashing.
class ClozeHighlightSegment extends ClozeSegment {
  const ClozeHighlightSegment(this.surfaceForm);
  final String surfaceForm;

  @override
  bool operator ==(Object other) =>
      other is ClozeHighlightSegment && other.surfaceForm == surfaceForm;

  @override
  int get hashCode => surfaceForm.hashCode;

  @override
  String toString() => 'ClozeHighlightSegment($surfaceForm)';
}

/// A target word's *first* occurrence — rendered as an answerable blank.
/// [targetWord] (base form) is the correct answer; the surface form that
/// was originally there is intentionally not exposed here, since the
/// whole point of a blank is that it no longer shows the answer.
class ClozeBlankSegment extends ClozeSegment {
  const ClozeBlankSegment(this.targetWord);
  final String targetWord;

  @override
  bool operator ==(Object other) => other is ClozeBlankSegment && other.targetWord == targetWord;

  @override
  int get hashCode => targetWord.hashCode;

  @override
  String toString() => 'ClozeBlankSegment($targetWord)';
}

/// Splits a marked `storyContent` string into cloze segments. Pure, no
/// I/O. The order of [ClozeBlankSegment]s in the result matches their
/// order of first appearance in the story.
List<ClozeSegment> buildClozeSegments(String markedStory) {
  final seen = <String>{};
  final segments = <ClozeSegment>[];

  for (final segment in parseStoryMarkers(markedStory)) {
    switch (segment) {
      case PlainStorySegment(:final text):
        segments.add(ClozePlainSegment(text));
      case MarkedStorySegment(:final targetWord, :final surfaceForm):
        if (seen.add(targetWord)) {
          segments.add(ClozeBlankSegment(targetWord));
        } else {
          segments.add(ClozeHighlightSegment(surfaceForm));
        }
    }
  }

  return segments;
}

/// The distinct target words that actually became a blank, in first-
/// appearance order — exactly the set [ClozeBlankSegment]s in
/// [buildClozeSegments]'s result cover. Used to build the dropdown answer
/// options (`SPEC.md` §5.2: "dropdown berisi daftar kata target dalam
/// bentuk dasar") and to know how many blanks must be answered before
/// "Submit" is enabled.
List<String> blankTargetWords(List<ClozeSegment> segments) {
  return [
    for (final segment in segments)
      if (segment is ClozeBlankSegment) segment.targetWord,
  ];
}

/// Cross-checks a marked story's target-word markers against the
/// session's actual [wordIds] (Milestone 7 Phase 2 Stage 2) — the
/// client-side mirror of `vocably-ai-worker/src/handlers/generateStory.
/// ts`'s `validateMarkers()`. The Worker already enforces this
/// server-side (Stage 1), but the client must not rely on the Worker
/// being perfect: a hallucinated/mismatched marker that somehow slips
/// through would otherwise become a real Cloze blank for a word nobody
/// actually requested — the exact chain behind the Phase 2 audit's
/// permission-denied bug (a `learningProgress` doc for a word that was
/// never in `wordIds` never gets created, then a later read of it 403s).
///
/// Deliberately operates on the **raw** parsed markers (via
/// [parseStoryMarkers]), not on [buildClozeSegments]'s already-deduped
/// output — [buildClozeSegments] intentionally collapses a repeated
/// target word down to one blank plus plain-highlight segments that no
/// longer carry a `targetWord` at all ([ClozeHighlightSegment] only
/// keeps [ClozeHighlightSegment.surfaceForm]), which would make a
/// duplicate marker invisible to this check if it ran on that output
/// instead.
///
/// Returns `true` only if every marker's `targetWord` is exactly one of
/// [wordIds] (no extra/unrequested or spelling/case-mismatched marker)
/// **and** every word in [wordIds] was marked exactly once (no missing,
/// no duplicate) — i.e. the set of marked target words is exactly equal
/// to [wordIds], element-for-element.
bool storyMarkersMatchWordIds(String markedStory, List<String> wordIds) {
  final requested = wordIds.toSet();
  final seen = <String>{};

  for (final segment in parseStoryMarkers(markedStory)) {
    if (segment is! MarkedStorySegment) continue;
    final targetWord = segment.targetWord;
    if (!requested.contains(targetWord)) return false; // extra/hallucinated or mismatched
    if (!seen.add(targetWord)) return false; // duplicate marker for the same word
  }

  return seen.length == requested.length; // every requested word got exactly one marker
}

/// Grades a completed cloze test: `{targetWord: wasCorrect}`, one entry
/// per blank. [answers] maps each blank's `targetWord` to whatever the
/// student currently has selected for it (or `null`/absent if
/// unanswered, which grades as incorrect — callers are expected to
/// disable "Submit" until every blank has an answer, but grading itself
/// doesn't assume that already happened).
///
/// Answer comparison is a plain string equality against the blank's own
/// [ClozeBlankSegment.targetWord] — the correct answer is always the
/// base form itself (`SPEC.md` §5.2), so there is nothing to normalize
/// beyond that.
Map<String, bool> gradeClozeAnswers(
  List<ClozeSegment> segments,
  Map<String, String?> answers,
) {
  return {
    for (final targetWord in blankTargetWords(segments))
      targetWord: answers[targetWord] == targetWord,
  };
}
