import 'dart:math';

import 'normalize_word.dart';

/// Deterministic validation helpers for Co-Write (Fase 3).
///
/// Enforces the core rule: AI may generate story continuations and
/// linguistic feedback, but application code deterministically verifies
/// whether target words were actually used in a turn's text and whether a
/// student's input is a meaningful sentence rather than a bare word, a
/// fragment, or a list of target words.
///
/// Mirrored line-for-line in the Worker
/// (`vocably-ai-worker/src/cowriteValidator.ts`) — any change to the
/// semantics here must be made there too, with the same regression tests.

final RegExp _wordTokenRegex = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?");

/// List separators that mark a turn as an enumeration rather than a clause
/// (`"attack, button, ability"`).
final RegExp _listSeparatorRegex = RegExp(r'[,;/]');

const Set<String> _determiners = {
  'a',
  'an',
  'the',
  'my',
  'your',
  'his',
  'her',
  'its',
  'our',
  'their',
  'this',
  'that',
  'these',
  'those',
  'some',
  'any',
  'no',
  'every',
  'each',
};

/// Demonstratives can also stand alone as a subject pronoun ("This works.").
const Set<String> _singularDemonstratives = {'this', 'that'};
const Set<String> _pluralDemonstratives = {'these', 'those'};

const Set<String> _prepositions = {
  'in',
  'on',
  'at',
  'to',
  'for',
  'with',
  'from',
  'by',
  'of',
  'about',
  'into',
  'over',
  'after',
  'before',
  'under',
  'between',
  'through',
};

const Set<String> _listFillers = {
  'a',
  'an',
  'the',
  'and',
  'or',
};

/// Words that, directly before an `-er` form, make it a comparative
/// adjective ("is taller", "a bit taller") rather than an agent noun
/// ("a teacher", "the attacker").
const Set<String> _comparativeLeadIns = {
  'is',
  'am',
  'are',
  'was',
  'were',
  'be',
  'been',
  'being',
  'become',
  'becomes',
  'became',
  'becoming',
  'get',
  'gets',
  'got',
  'getting',
  'grow',
  'grows',
  'grew',
  'growing',
  'look',
  'looks',
  'looked',
  'feel',
  'feels',
  'felt',
  'seem',
  'seems',
  'seemed',
  'much',
  'even',
  'far',
  'slightly',
  'lot',
  'bit',
  'little',
};

/// Words that, directly before an `-est` form, make it a superlative
/// ("the tallest", "my biggest").
const Set<String> _superlativeLeadIns = {
  'the',
  'my',
  'your',
  'his',
  'her',
  'its',
  'our',
  'their',
};

/// Closed lookup table of common irregular English word forms mapped from
/// normalized base form -> set of valid surface inflections. Irregular
/// comparatives (`good` -> `better`) live here too, since they never
/// collide with an agent noun the way regular `-er` forms do.
///
/// `lie` deliberately does **not** list `lay`: `lay` is its own base verb
/// (lay/laid), and accepting it for `lie` credits the wrong word.
const Map<String, Set<String>> _irregularForms = {
  'be': {'am', 'is', 'are', 'was', 'were', 'been', 'being'},
  'have': {'has', 'had', 'having'},
  'do': {'does', 'did', 'done', 'doing'},
  'go': {'goes', 'went', 'gone', 'going'},
  'say': {'said', 'says', 'saying'},
  'run': {'ran', 'running', 'runs'},
  'eat': {'ate', 'eaten', 'eating', 'eats'},
  'drink': {'drank', 'drunk', 'drinking', 'drinks'},
  'see': {'saw', 'seen', 'seeing', 'sees'},
  'take': {'took', 'taken', 'taking', 'takes'},
  'give': {'gave', 'given', 'giving', 'gives'},
  'make': {'made', 'making', 'makes'},
  'come': {'came', 'coming', 'comes'},
  'know': {'knew', 'known', 'knowing', 'knows'},
  'get': {'got', 'gotten', 'getting', 'gets'},
  'find': {'found', 'finding', 'finds'},
  'think': {'thought', 'thinking', 'thinks'},
  'tell': {'told', 'telling', 'tells'},
  'become': {'became', 'becoming', 'becomes'},
  'show': {'showed', 'shown', 'showing', 'shows'},
  'leave': {'left', 'leaving', 'leaves'},
  'feel': {'felt', 'feeling', 'feels'},
  'put': {'putting', 'puts'},
  'bring': {'brought', 'bringing', 'brings'},
  'begin': {'began', 'begun', 'beginning', 'begins'},
  'keep': {'kept', 'keeping', 'keeps'},
  'hold': {'held', 'holding', 'holds'},
  'write': {'wrote', 'written', 'writing', 'writes'},
  'stand': {'stood', 'standing', 'stands'},
  'hear': {'heard', 'hearing', 'hears'},
  'let': {'letting', 'lets'},
  'mean': {'meant', 'meaning', 'means'},
  'set': {'setting', 'sets'},
  'meet': {'met', 'meeting', 'meets'},
  'pay': {'paid', 'paying', 'pays'},
  'sit': {'sat', 'sitting', 'sits'},
  'speak': {'spoke', 'spoken', 'speaking', 'speaks'},
  'lie': {'lain', 'lying', 'lies', 'lied'},
  'lead': {'led', 'leading', 'leads'},
  'read': {'reading', 'reads'},
  'grow': {'grew', 'grown', 'growing', 'grows'},
  'lose': {'lost', 'losing', 'loses'},
  'fall': {'fell', 'fallen', 'falling', 'falls'},
  'send': {'sent', 'sending', 'sends'},
  'build': {'built', 'building', 'builds'},
  'understand': {'understood', 'understanding', 'understands'},
  'draw': {'drew', 'drawn', 'drawing', 'draws'},
  'break': {'broke', 'broken', 'breaking', 'breaks'},
  'spend': {'spent', 'spending', 'spends'},
  'cut': {'cutting', 'cuts'},
  'rise': {'rose', 'risen', 'rising', 'rises'},
  'drive': {'drove', 'driven', 'driving', 'drives'},
  'buy': {'bought', 'buying', 'buys'},
  'wear': {'wore', 'worn', 'wearing', 'wears'},
  'choose': {'chose', 'chosen', 'choosing', 'chooses'},
  'seek': {'sought', 'seeking', 'seeks'},
  'throw': {'threw', 'thrown', 'throwing', 'throws'},
  'catch': {'caught', 'catching', 'catches'},
  'deal': {'dealt', 'dealing', 'deals'},
  'win': {'won', 'winning', 'wins'},
  'forget': {'forgot', 'forgotten', 'forgetting', 'forgets'},
  'forgive': {'forgave', 'forgiven', 'forgiving', 'forgives'},
  'lay': {'laid', 'laying', 'lays'},
  'sell': {'sold', 'selling', 'sells'},
  'fight': {'fought', 'fighting', 'fights'},
  'teach': {'taught', 'teaching', 'teaches'},
  'sing': {'sang', 'sung', 'singing', 'sings'},
  'strike': {'struck', 'striking', 'strikes'},
  'hang': {'hung', 'hanged', 'hanging', 'hangs'},
  'shake': {'shook', 'shaken', 'shaking', 'shakes'},
  'ride': {'rode', 'ridden', 'riding', 'rides'},
  'feed': {'fed', 'feeding', 'feeds'},
  'shoot': {'shot', 'shooting', 'shoots'},
  'fly': {'flew', 'flown', 'flying', 'flies'},
  'wake': {'woke', 'woken', 'waking', 'wakes', 'waked'},
  'sleep': {'slept', 'sleeping', 'sleeps'},
  'sweep': {'swept', 'sweeping', 'sweeps'},
  'swim': {'swam', 'swum', 'swimming', 'swims'},
  'steal': {'stole', 'stolen', 'stealing', 'steals'},
  'dig': {'dug', 'digging', 'digs'},
  'hide': {'hid', 'hidden', 'hiding', 'hides'},
  'shine': {'shone', 'shined', 'shining', 'shines'},
  'tear': {'tore', 'torn', 'tearing', 'tears'},
  'blow': {'blew', 'blown', 'blowing', 'blows'},
  'ring': {'rang', 'rung', 'ringing', 'rings'},
  'freeze': {'froze', 'frozen', 'freezing', 'freezes'},
  'bite': {'bit', 'bitten', 'biting', 'bites'},
  'hit': {'hitting', 'hits'},
  'hurt': {'hurting', 'hurts'},
  'cost': {'costing', 'costs'},
  'shut': {'shutting', 'shuts'},
  'lend': {'lent', 'lending', 'lends'},
  'bend': {'bent', 'bending', 'bends'},
  'light': {'lit', 'lighted', 'lighting', 'lights'},
  'bleed': {'bled', 'bleeding', 'bleeds'},
  'flee': {'fled', 'fleeing', 'flees'},
  'stick': {'stuck', 'sticking', 'sticks'},
  'swing': {'swung', 'swinging', 'swings'},
  'sink': {'sank', 'sunk', 'sinking', 'sinks'},
  'spin': {'spun', 'spinning', 'spins'},
  'slide': {'slid', 'sliding', 'slides'},
  'beat': {'beaten', 'beating', 'beats'},
  'wind': {'wound', 'winding', 'winds'},
  'weep': {'wept', 'weeping', 'weeps'},
  'creep': {'crept', 'creeping', 'creeps'},
  'swear': {'swore', 'sworn', 'swearing', 'swears'},
  'arise': {'arose', 'arisen', 'arising', 'arises'},
  'good': {'better', 'best'},
  'bad': {'worse', 'worst'},
  'child': {'children'},
  'person': {'people', 'persons'},
  'man': {'men'},
  'woman': {'women'},
  'foot': {'feet'},
  'tooth': {'teeth'},
  'mouse': {'mice'},
};

bool _isVowel(String ch) {
  return ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u';
}

/// Extracts normalized lowercase word tokens from [text], converting smart
/// apostrophes to ASCII apostrophes first.
List<String> extractWordTokens(String text) {
  final normalizedPunctuation = text.replaceAll('’', "'").replaceAll('‘', "'");
  return _wordTokenRegex
      .allMatches(normalizedPunctuation)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
}

/// Whether [clean] takes `-es` (rather than only `-s`): box -> boxes,
/// watch -> watches, bus -> buses, potato -> potatoes.
bool _takesEsSuffix(String clean) =>
    clean.endsWith('s') ||
    clean.endsWith('x') ||
    clean.endsWith('z') ||
    clean.endsWith('o') ||
    clean.endsWith('ch') ||
    clean.endsWith('sh');

/// Whether [clean] doubles its final consonant before `-ed`/`-ing`: only a
/// consonant-vowel-consonant ending (stop -> stopped, plan -> planning,
/// quit -> quitting, where `qu` acts as one consonant). Never for words
/// like `attack` (`-ck`), `need` (two vowels), or endings w/x/y.
bool _doublesFinalConsonant(String clean) {
  final len = clean.length;
  if (len < 3) return false;
  final last = clean[len - 1];
  final prev = clean[len - 2];
  final before = clean[len - 3];
  if (_isVowel(last) || last == 'w' || last == 'x' || last == 'y') return false;
  if (!_isVowel(prev)) return false;
  if (!_isVowel(before)) return true;
  return before == 'u' && len >= 4 && clean[len - 4] == 'q';
}

/// Generates the finite set of valid surface inflections for a single lowercase
/// word [base]. Excludes derivational suffixes like `-er` or `-ly` so words
/// like `attacker` or `counterattack` never match `attack` — comparative
/// `-er`/`-est` is handled separately, only in a comparative context (see
/// [containsTargetWordInText]).
///
/// Suffixes are applied by spelling rule, not blindly, so invalid forms are
/// never accepted: `attack` -> attacks/attacked/attacking but not
/// `attackked`, `attackes`, or `attackd`. Words with an entry in
/// [_irregularForms] get no generated regular past form (`be` never yields
/// `bed`, `see` never `seed`, `run` never `runned`) — their table lists the
/// valid ones.
Set<String> validFormsForSingleWord(String base) {
  final clean = normalizeWord(base);
  if (clean.isEmpty) return const {};

  final forms = <String>{clean};
  final irregular = _irregularForms[clean];
  if (irregular != null) forms.addAll(irregular);
  final regularPast = irregular == null;

  final len = clean.length;
  final last = clean[len - 1];
  final prev = len >= 2 ? clean[len - 2] : '';

  if (last == 'e' && len > 2) {
    // Silent -e: decide -> decides/decided/deciding; agree -> agreeing;
    // die -> dying; knife -> knives.
    forms.add('${clean}s');
    if (regularPast) forms.add('${clean}d');
    if (prev == 'i') {
      forms.add('${clean.substring(0, len - 2)}ying');
    } else if (prev == 'e' || prev == 'o' || prev == 'y') {
      forms.add('${clean}ing');
    } else {
      forms.add('${clean.substring(0, len - 1)}ing');
    }
    if (len > 3 && prev == 'f') forms.add('${clean.substring(0, len - 2)}ves');
  } else if (last == 'y' && len > 2 && !_isVowel(prev)) {
    // Consonant + y: carry -> carries/carried/carrying.
    final stem = clean.substring(0, len - 1);
    forms.add('${stem}ies');
    forms.add('${clean}ing');
    if (regularPast) forms.add('${stem}ied');
  } else {
    forms.add('${clean}s');
    forms.add('${clean}ing');
    if (regularPast) forms.add('${clean}ed');
    if (_takesEsSuffix(clean)) forms.add('${clean}es');
    // -f -> -ves (leaf -> leaves).
    if (last == 'f' && len > 2) forms.add('${clean.substring(0, len - 1)}ves');
    // -c -> -cked/-cking (panic -> panicked, panicking).
    if (last == 'c' && len > 2) {
      forms.add('${clean}king');
      if (regularPast) forms.add('${clean}ked');
    }
    // Consonant doubling (stop -> stopped/stopping).
    if (_doublesFinalConsonant(clean)) {
      forms.add('$clean$last' 'ing');
      if (regularPast) forms.add('$clean$last' 'ed');
    }
  }

  return forms;
}

/// Regular comparative (`suffix == 'er'`) or superlative (`suffix == 'est'`)
/// surface forms of [base]: tall -> taller, large -> larger, happy ->
/// happier, big -> bigger.
Set<String> _gradedForms(String base, String suffix) {
  final clean = normalizeWord(base);
  final len = clean.length;
  if (len < 2) return const {};

  final last = clean[len - 1];
  final prev = clean[len - 2];
  final forms = <String>{};

  if (last == 'e') {
    forms.add('${clean.substring(0, len - 1)}$suffix');
  } else if (last == 'y' && !_isVowel(prev)) {
    forms.add('${clean.substring(0, len - 1)}i$suffix');
  } else {
    forms.add('$clean$suffix');
    // Short consonant-vowel-consonant words double the final consonant.
    if (len >= 3 &&
        !_isVowel(last) &&
        last != 'w' &&
        last != 'x' &&
        last != 'y' &&
        _isVowel(prev) &&
        !_isVowel(clean[len - 3])) {
      forms.add('$clean$last$suffix');
    }
  }
  return forms;
}

String _stripPossessive(String surfaceToken) {
  var token = normalizeWord(surfaceToken).replaceAll('’', "'");
  if (token.endsWith("'s")) {
    token = token.substring(0, token.length - 2);
  } else if (token.endsWith("'")) {
    token = token.substring(0, token.length - 1);
  }
  return token;
}

/// Returns true if [surfaceToken] matches [targetBase] as an exact whole word
/// or standard grammatical inflection (including possessive `'s`). Does not
/// accept comparatives — those need sentence context, see
/// [containsTargetWordInText].
bool matchesSingleWordForm(String surfaceToken, String targetBase) {
  final token = _stripPossessive(surfaceToken);
  if (token.isEmpty) return false;
  return validFormsForSingleWord(targetBase).contains(token);
}

bool _isBeContraction(String token) =>
    token.endsWith("'s") || token.endsWith("'re") || token.endsWith("'m");

/// Whether `tokens[index]` is a comparative/superlative of [targetBase]
/// used in a comparative context: `-er` directly followed by `than` or
/// directly preceded by a linking verb/intensifier ("is taller", "taller
/// than"); `-est` directly preceded by `the` or a possessive ("the
/// tallest"). Agent nouns ("a teacher", "the attacker") never qualify.
bool _matchesGradedFormInContext(List<String> tokens, int index, String targetBase) {
  final token = _stripPossessive(tokens[index]);
  final previous = index > 0 ? tokens[index - 1] : null;
  final next = index + 1 < tokens.length ? tokens[index + 1] : null;

  if (_gradedForms(targetBase, 'er').contains(token)) {
    if (next == 'than') return true;
    if (previous != null &&
        (_comparativeLeadIns.contains(previous) || _isBeContraction(previous))) {
      return true;
    }
  }
  if (_gradedForms(targetBase, 'est').contains(token)) {
    if (previous != null && _superlativeLeadIns.contains(previous)) return true;
  }
  return false;
}

/// Returns true if [targetWord] (single word or multi-word phrase) appears in
/// [text] as a whole word (or valid inflection). Substring matches inside
/// unrelated words (e.g. `attack` inside `counterattack` or `attacker`) return
/// false. Comparatives/superlatives count only in a comparative context.
bool containsTargetWordInText(String text, String targetWord) {
  final targetTokens = extractWordTokens(targetWord);
  if (targetTokens.isEmpty) return false;

  final textTokens = extractWordTokens(text);
  if (textTokens.length < targetTokens.length) return false;

  if (targetTokens.length == 1) {
    final targetSingle = targetTokens.first;
    for (var i = 0; i < textTokens.length; i++) {
      if (matchesSingleWordForm(textTokens[i], targetSingle)) return true;
      if (_matchesGradedFormInContext(textTokens, i, targetSingle)) return true;
    }
    return false;
  }

  // Multi-word target phrase: match contiguous token window.
  final windowLen = targetTokens.length;
  for (var i = 0; i <= textTokens.length - windowLen; i++) {
    var allMatch = true;
    for (var j = 0; j < windowLen; j++) {
      if (!matchesSingleWordForm(textTokens[i + j], targetTokens[j])) {
        allMatch = false;
        break;
      }
    }
    if (allMatch) return true;
  }
  return false;
}

/// Whether [text] contains at least one of [targetWords] (whole word or
/// valid inflection).
bool containsAnyTargetWord(String text, Iterable<String> targetWords) {
  return targetWords
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .any((target) => containsTargetWordInText(text, target));
}

bool _looksLikeThirdPersonVerb(String token) =>
    token.length > 2 &&
    token.endsWith('s') &&
    !token.endsWith('ss') &&
    !token.endsWith('us') &&
    !token.endsWith('is');

/// "This works." / "That helped." / "Those failed." — a demonstrative used
/// as a subject pronoun followed by a verb, not a determiner + noun.
bool _isDemonstrativeSubjectClause(String first, String second) {
  if (_singularDemonstratives.contains(first)) {
    return _looksLikeThirdPersonVerb(second) || second.endsWith('ed');
  }
  if (_pluralDemonstratives.contains(first)) {
    return second.endsWith('ed');
  }
  return false;
}

/// Returns true when [text] is structurally not a sentence/clause:
///
/// 1. fewer than 2 word tokens (`"attack"`, `"button?"`, `"Okay."`);
/// 2. one word repeated (`"button button"`);
/// 3. a 2-word determiner + noun fragment (`"the button"`) — except a
///    demonstrative subject + verb (`"This works."`) — a 2-word
///    preposition fragment, or a 3-word preposition + determiner + noun
///    fragment (`"on the button"`);
/// 4. a list of target words: every content word is a target word (or an
///    inflection of one) **and** either the turn contains a list separator
///    (`,` `;` `/`) or no word is inflected (`"attack button completely"`,
///    `"the attack and the button"`). An all-target turn with an inflected
///    form and no separator (`"Birds fly."` with targets `bird`/`fly`) is
///    treated as a sentence.
///
/// This says nothing about whether a turn should be *rejected* — see
/// [shouldRejectStudentTurnLocally] — only that it cannot demonstrate
/// productive use of a target word.
bool isBareOrFragmentTurn(String text, Iterable<String> targetWords) {
  final tokens = extractWordTokens(text);

  if (tokens.length < 2) {
    return true;
  }

  if (tokens.toSet().length == 1) {
    return true;
  }

  if (tokens.length == 2 &&
      _determiners.contains(tokens[0]) &&
      !_isDemonstrativeSubjectClause(tokens[0], tokens[1])) {
    return true;
  }
  if (tokens.length == 2 && _prepositions.contains(tokens[0])) {
    return true;
  }
  if (tokens.length == 3 &&
      _prepositions.contains(tokens[0]) &&
      _determiners.contains(tokens[1])) {
    return true;
  }

  final normalizedTargets = targetWords
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .toSet();
  if (normalizedTargets.isNotEmpty) {
    final contentTokens =
        tokens.where((t) => !_listFillers.contains(t)).toList();
    final allTargets = contentTokens.isNotEmpty &&
        contentTokens.every(
          (token) => normalizedTargets.any(
            (target) => containsTargetWordInText(token, target),
          ),
        );
    if (allTargets) {
      final hasSeparator = _listSeparatorRegex.hasMatch(text);
      final noneInflected = contentTokens.every(
        (token) => normalizedTargets.contains(_stripPossessive(token)),
      );
      if (hasSeparator || noneInflected) return true;
    }
  }

  return false;
}

/// Whether a student's Co-Write input is rejected locally (never sent to
/// the Worker, never added to the transcript, never counted as a turn):
/// it mentions a target word but only as a bare word, fragment, or list.
///
/// Ordinary short replies that contain **no** target word (`"Okay."`,
/// `"Yes!"`) are not rejected — they are valid story turns that simply
/// don't use a target word (and count as a miss for the fallback counter).
bool shouldRejectStudentTurnLocally(String text, Iterable<String> targetWords) {
  return containsAnyTargetWord(text, targetWords) &&
      isBareOrFragmentTurn(text, targetWords);
}

/// Maps one model-reported word ([raw], e.g. `attacked`, `Attack.`,
/// `'attack'`, `"ATTACKS"`) to the eligible base target(s) it denotes.
///
/// Surrounding quotes/punctuation and casing are dropped by tokenizing. An
/// exact base-form match wins; otherwise every eligible target whose valid
/// inflections (or comparative/superlative forms) include the reported form
/// is returned. This only identifies *which* target the model meant — the
/// caller still requires that target to occur in the student's text.
List<String> _canonicalTargetsForClaim(String raw, Set<String> eligible) {
  final tokens = extractWordTokens(raw);
  if (tokens.isEmpty) return const [];
  final claim = tokens.join(' ');
  if (eligible.contains(claim)) return [claim];

  final matches = <String>[];
  for (final target in eligible) {
    final targetTokens = extractWordTokens(target);
    if (targetTokens.length != tokens.length) continue;
    var allMatch = true;
    for (var i = 0; i < tokens.length; i++) {
      final token = _stripPossessive(tokens[i]);
      final base = targetTokens[i];
      if (!validFormsForSingleWord(base).contains(token) &&
          !_gradedForms(base, 'er').contains(token) &&
          !_gradedForms(base, 'est').contains(token)) {
        allMatch = false;
        break;
      }
    }
    if (allMatch) matches.add(target);
  }
  return matches;
}

/// Validates AI-claimed student target words (`wordsUsedCorrectly`) against the
/// current [studentTurnText] and [eligibleTargetWords].
///
/// The model judges *meaning* (whether the student used the word
/// meaningfully, with an acceptable intended meaning — grammar errors don't
/// disqualify); this function enforces the deterministic part: each claim
/// must map to an eligible (remaining) target ([_canonicalTargetsForClaim]
/// accepts a reported surface form such as `attacked` for `attack`), that
/// target must actually occur in [studentTurnText] as a whole word or valid
/// inflection, and the turn must not be a bare word/fragment/list.
///
/// Returns canonical normalized target words from [eligibleTargetWords] in
/// stable order without duplicates.
List<String> validateStudentTargetWords({
  required Iterable<String> claimedWords,
  required String studentTurnText,
  required Iterable<String> eligibleTargetWords,
}) {
  final eligible = eligibleTargetWords
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .toSet();
  if (eligible.isEmpty) return const [];

  if (isBareOrFragmentTurn(studentTurnText, eligible)) {
    return const [];
  }

  final result = <String>[];
  final seen = <String>{};

  for (final raw in claimedWords) {
    for (final target in _canonicalTargetsForClaim(raw, eligible)) {
      if (seen.contains(target)) continue;
      if (!containsTargetWordInText(studentTurnText, target)) continue;

      seen.add(target);
      result.add(target);
    }
  }

  return result;
}

/// Validates and detects bot target words in [aiTurnText] against
/// [eligibleTargetWords].
///
/// Any word from [eligibleTargetWords] that actually occurs in [aiTurnText] as
/// a whole word or supported inflection is recognized deterministically — even
/// when [claimedWords] (`aiUsedWords`) is empty or omits it. Conversely, any
/// word in [claimedWords] that does not belong to [eligibleTargetWords] or
/// does not actually appear in [aiTurnText] is rejected.
///
/// Only used for the application-selected fallback word
/// (`eligibleTargetWords == [selectedWord]`): ordinary AI turns never
/// credit target words, see `LearningFlowController.sendTurn`.
///
/// Returns canonical normalized target words from [eligibleTargetWords] in
/// stable order without duplicates.
List<String> validateBotTargetWords({
  required Iterable<String> claimedWords,
  required String aiTurnText,
  required Iterable<String> eligibleTargetWords,
}) {
  final eligible = eligibleTargetWords
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .toSet();
  if (eligible.isEmpty || aiTurnText.trim().isEmpty) return const [];

  final result = <String>[];
  final seen = <String>{};

  for (final raw in [...claimedWords, ...eligibleTargetWords]) {
    final normalized = normalizeWord(raw);
    if (normalized.isEmpty || seen.contains(normalized)) continue;
    if (!eligible.contains(normalized)) continue;
    if (!containsTargetWordInText(aiTurnText, normalized)) continue;

    seen.add(normalized);
    result.add(normalized);
  }

  return result;
}

/// Number of consecutive student turns without valid target-word usage
/// after which the application forces the bot to use one remaining word.
const int kCowriteFallbackMissThreshold = 3;

/// Picks exactly one fallback word uniformly at random from [remainingWords]
/// (application-owned — the model never chooses). Returns `null` when
/// nothing remains.
String? selectFallbackWord(List<String> remainingWords, Random random) {
  if (remainingWords.isEmpty) return null;
  return remainingWords[random.nextInt(remainingWords.length)];
}

/// Unambiguous Indonesian function words, pronouns, and particles: none is
/// an ordinary English word. Deliberately excluded because they are also
/// English: `main`, `data`, `jam`, `bank`, `ban`, `pan`, `lama`, `ya`,
/// `yuk`, `dong`, `kok`, `situ`, `agar`, `tak`, `ku`.
const Set<String> _indonesianStrongMarkers = {
  // Pronouns.
  'aku', 'saya', 'kamu', 'kau', 'ia', 'kami', 'kita', 'mereka', 'beliau',
  // Prepositions / conjunctions.
  'yang', 'dengan', 'untuk', 'dari', 'ke', 'di', 'pada', 'dalam', 'oleh',
  'kepada', 'bagi', 'tentang', 'seperti', 'atau', 'lalu', 'kemudian',
  'karena', 'tetapi', 'tapi', 'jadi', 'kalau', 'jika', 'supaya', 'sehingga',
  // Demonstratives / place.
  'ini', 'itu', 'sini', 'sana',
  // Negation, aspect, adverbs.
  'tidak', 'bukan', 'belum', 'sudah', 'sedang', 'akan', 'telah', 'pernah',
  'masih', 'lagi', 'juga', 'saja', 'aja', 'hanya', 'sangat', 'sekali',
  'banget', 'gak', 'nggak', 'enggak',
  // Common verbs / modals.
  'adalah', 'bisa', 'ingin', 'harus', 'boleh', 'bantu', 'tolong', 'buat',
  'membuat', 'bikin',
  // Question words.
  'siapa', 'bagaimana', 'kenapa', 'mengapa', 'kapan', 'dimana', 'berapa',
  // Particles.
  'deh', 'sih', 'nih',
};

/// Indonesian words that are also common English names or acronyms (`Dan`,
/// `Ada`, `APA`). Each one counts only when another marker is also present,
/// so "Dan went home." is not flagged but "ini dan itu" is.
const Set<String> _indonesianWeakMarkers = {'dan', 'ada', 'anda', 'dia', 'mau', 'apa'};

final RegExp _caseSensitiveWordRegex = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

/// Deterministic, application-owned check: does [text] contain Indonesian
/// (i.e. is it an Indonesian or mixed Indonesian-English turn)?
///
/// Counts curated Indonesian markers ([_indonesianStrongMarkers]; a
/// [_indonesianWeakMarkers] word only alongside another marker) after
/// normalizing case and punctuation. Never counts a target word (in any
/// form) as a marker, never counts a capitalized word in mid-sentence (a
/// proper noun such as "I met Dan"), and ignores `yang` next to `yin`.
///
/// This is a heuristic, not language identification: Indonesian text that
/// uses none of the listed words (e.g. only content words like "makan nasi
/// goreng") is not detected, and an English sentence quoting one of these
/// words would be flagged. Mirrored in the Worker
/// (`containsIndonesianWords` in `src/cowriteValidator.ts`).
bool containsIndonesianWords(String text, Iterable<String> targetWords) {
  final normalizedTargets = targetWords
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .toList();
  final normalizedText = text.replaceAll('’', "'").replaceAll('‘', "'");
  final hasYin = extractWordTokens(normalizedText).contains('yin');

  var strong = 0;
  var weak = 0;
  for (final match in _caseSensitiveWordRegex.allMatches(normalizedText)) {
    final raw = match.group(0)!;
    final token = raw.toLowerCase();
    if (!_indonesianStrongMarkers.contains(token) &&
        !_indonesianWeakMarkers.contains(token)) {
      continue;
    }
    if (normalizedTargets.any((t) => containsTargetWordInText(token, t))) continue;
    if (token == 'yang' && hasYin) continue;
    if (_isCapitalizedMidSentence(raw, normalizedText, match.start)) continue;

    if (_indonesianStrongMarkers.contains(token)) {
      strong++;
    } else {
      weak++;
    }
  }
  return strong >= 1 || weak >= 2;
}

/// Whether [raw] starts with a capital letter and is not the first word of
/// a sentence (i.e. it is probably a proper noun).
bool _isCapitalizedMidSentence(String raw, String text, int start) {
  final first = raw[0];
  if (first.toUpperCase() != first || first.toLowerCase() == first) return false;
  for (var i = start - 1; i >= 0; i--) {
    final ch = text[i];
    if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '"' || ch == "'" || ch == '(') {
      continue;
    }
    return !(ch == '.' || ch == '!' || ch == '?' || ch == ':');
  }
  return false; // first word of the text
}
