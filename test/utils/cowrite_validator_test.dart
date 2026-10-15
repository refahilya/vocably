import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/utils/cowrite_validator.dart';

void main() {
  group('containsTargetWordInText', () {
    test('matches exact base form case-insensitively', () {
      expect(containsTargetWordInText('I pressed the button.', 'button'), isTrue);
      expect(containsTargetWordInText('BUTTON was red.', 'button'), isTrue);
    });

    test('matches regular and irregular inflections of target words', () {
      expect(containsTargetWordInText('I ran to the store.', 'run'), isTrue);
      expect(containsTargetWordInText('She is running fast.', 'run'), isTrue);
      expect(containsTargetWordInText('He pressed the red switch.', 'press'), isTrue);
      expect(containsTargetWordInText('They carried the heavy bags.', 'carry'), isTrue);
      expect(containsTargetWordInText('We bought a souvenir.', 'buy'), isTrue);
      expect(containsTargetWordInText("The baby's toy fell.", 'baby'), isTrue);
    });

    test('rejects substring false positives inside unrelated words', () {
      expect(containsTargetWordInText('The attacker ran away.', 'attack'), isFalse);
      expect(containsTargetWordInText('They launched a counterattack.', 'attack'), isFalse);
      expect(containsTargetWordInText('That apple is crunchy.', 'run'), isFalse);
      expect(containsTargetWordInText('She is a fast runner.', 'run'), isFalse);
      expect(containsTargetWordInText('She buttoned nothing.', 'ton'), isFalse);
    });
  });

  group('isBareOrFragmentTurn', () {
    const targets = ['attack', 'button', 'completely', 'souvenir', 'baby', 'breakfast'];

    test('rejects bare single words and single words with punctuation', () {
      expect(isBareOrFragmentTurn('attack', targets), isTrue);
      expect(isBareOrFragmentTurn('button', targets), isTrue);
      expect(isBareOrFragmentTurn('button?', targets), isTrue);
      expect(isBareOrFragmentTurn('button!', targets), isTrue);
      expect(isBareOrFragmentTurn('breakfast', targets), isTrue);
    });

    test('rejects repeated single words', () {
      expect(isBareOrFragmentTurn('button button', targets), isTrue);
      expect(isBareOrFragmentTurn('attack, attack!', targets), isTrue);
    });

    test('rejects short determiner or preposition noun fragments', () {
      expect(isBareOrFragmentTurn('the button', targets), isTrue);
      expect(isBareOrFragmentTurn('a souvenir', targets), isTrue);
      expect(isBareOrFragmentTurn('the baby', targets), isTrue);
      expect(isBareOrFragmentTurn('on the button', targets), isTrue);
    });

    test('rejects bare lists of target words without sentence structure', () {
      expect(isBareOrFragmentTurn('attack button completely', targets), isTrue);
      expect(isBareOrFragmentTurn('attack, button, and completely', targets), isTrue);
      expect(isBareOrFragmentTurn('the attack and the button', targets), isTrue);
    });

    test('accepts valid EFL sentences and clauses', () {
      expect(isBareOrFragmentTurn('I pressed the button.', targets), isFalse);
      expect(isBareOrFragmentTurn('He decided to attack the monster.', targets), isFalse);
      expect(isBareOrFragmentTurn('I ate breakfast this morning.', targets), isFalse);
      expect(isBareOrFragmentTurn('The baby is sleeping.', targets), isFalse);
      expect(isBareOrFragmentTurn('I ran today.', const ['run', 'souvenir']), isFalse);
    });
  });

  group('authoritative regressions (Co-Write Phase 2)', () {
    test('"Birds fly." is a sentence even when both words are targets', () {
      const targets = ['bird', 'fly'];
      expect(isBareOrFragmentTurn('Birds fly.', targets), isFalse);
      expect(shouldRejectStudentTurnLocally('Birds fly.', targets), isFalse);
      expect(
        validateStudentTargetWords(
          claimedWords: const ['bird', 'fly'],
          studentTurnText: 'Birds fly.',
          eligibleTargetWords: targets,
        ),
        equals(['bird', 'fly']),
      );
      expect(isBareOrFragmentTurn('Dogs and cats run.', const ['dog', 'cat', 'run']), isFalse);
    });

    test('"This works." is a sentence when "this" is a target word', () {
      const targets = ['this', 'button'];
      expect(isBareOrFragmentTurn('This works.', targets), isFalse);
      expect(shouldRejectStudentTurnLocally('This works.', targets), isFalse);
      expect(isBareOrFragmentTurn('That helped.', targets), isFalse);
      // A demonstrative + noun is still a fragment.
      expect(isBareOrFragmentTurn('this button', targets), isTrue);
      expect(isBareOrFragmentTurn('these buttons', targets), isTrue);
    });

    test('ordinary replies with no target word are never rejected locally', () {
      const targets = ['attack', 'button'];
      for (final reply in ['Okay.', 'Yes!', 'Wow', 'The end.']) {
        expect(shouldRejectStudentTurnLocally(reply, targets), isFalse, reason: reply);
      }
      // ...but they still can't credit anything.
      expect(isBareOrFragmentTurn('Okay.', targets), isTrue);
    });

    test('bare target words, lists, and fragments are still rejected locally', () {
      const targets = ['attack', 'button', 'ability'];
      for (final input in [
        'attack',
        'attack, button, ability',
        'attack button ability',
        'attacks, buttons',
        'the button',
        'button button',
        'the attack and the button',
      ]) {
        expect(shouldRejectStudentTurnLocally(input, targets), isTrue, reason: input);
      }
    });

    test('valid target-word sentences from the requirements are accepted', () {
      const targets = ['attack', 'button', 'ability'];
      for (final input in [
        'I can attack the problem from another angle.',
        'The button is broken.',
      ]) {
        expect(isBareOrFragmentTurn(input, targets), isFalse, reason: input);
        expect(shouldRejectStudentTurnLocally(input, targets), isFalse, reason: input);
      }
    });

    test('irregular forms: said -> say, bit/bitten -> bite', () {
      expect(containsTargetWordInText('He said hello.', 'say'), isTrue);
      expect(containsTargetWordInText('The dog bit me.', 'bite'), isTrue);
      expect(containsTargetWordInText('I was bitten by a mosquito.', 'bite'), isTrue);
    });

    test('"lay" is not accepted as a form of "lie" (but still of "lay")', () {
      expect(containsTargetWordInText('I lay the book down.', 'lie'), isFalse);
      expect(containsTargetWordInText('She is lying on the bed.', 'lie'), isTrue);
      expect(containsTargetWordInText('Hens lay eggs.', 'lay'), isTrue);
      expect(containsTargetWordInText('She laid the table.', 'lay'), isTrue);
    });

    test('comparatives and superlatives count in a comparative context', () {
      expect(containsTargetWordInText('She is taller now.', 'tall'), isTrue);
      expect(containsTargetWordInText('He is taller than me.', 'tall'), isTrue);
      expect(containsTargetWordInText("She's a bit taller.", 'tall'), isTrue);
      expect(containsTargetWordInText('He is the tallest boy.', 'tall'), isTrue);
      expect(containsTargetWordInText('My dog is bigger than yours.', 'big'), isTrue);
      expect(containsTargetWordInText('Today is happier than yesterday.', 'happy'), isTrue);
      expect(containsTargetWordInText('This box is larger.', 'large'), isTrue);
      expect(containsTargetWordInText('This is better than before.', 'good'), isTrue);
    });

    test('agent nouns are not mistaken for comparatives', () {
      expect(containsTargetWordInText('He is a teacher.', 'teach'), isFalse);
      expect(containsTargetWordInText('The attacker ran away.', 'attack'), isFalse);
      expect(containsTargetWordInText('She is a fast runner.', 'run'), isFalse);
      expect(containsTargetWordInText('The workers went home.', 'work'), isFalse);
    });
  });

  group('CW-05: reliable target-word crediting', () {
    List<String> credit(List<String> claimed, String text, [List<String> eligible = const ['attack']]) =>
        validateStudentTargetWords(
          claimedWords: claimed,
          studentTurnText: text,
          eligibleTargetWords: eligible,
        );

    test('grammar, tense, and agreement errors do not block credit the model reports', () {
      for (final text in [
        'Yesterday the monster attack the village.',
        'one day a monster came and attack the village',
        'The monsters attacks the village.',
        'He attack me yesterday.',
      ]) {
        expect(credit(['attack'], text), ['attack'], reason: text);
      }
    });

    test('meaningful uses of attack / attacked / attacks / attacking are credited', () {
      for (final text in [
        'The dragon will attack the castle.',
        'The dragon attacked the castle.',
        'The dragon attacks the castle every night.',
        'The dragon is attacking the castle.',
      ]) {
        expect(credit(['attack'], text), ['attack'], reason: text);
      }
    });

    test('a model-reported surface form or formatted string maps to the remaining base target', () {
      expect(credit(['attacked'], 'The dragon attacked the castle.'), ['attack']);
      expect(credit(['attacks'], 'The dragon attacks the castle.'), ['attack']);
      expect(credit(['attacking'], 'The dragon is attacking the castle.'), ['attack']);
      expect(credit(['Attack.'], 'The dragon will attack the castle.'), ['attack']);
      expect(credit(["'attack'"], 'The dragon will attack the castle.'), ['attack']);
      expect(credit(['"ATTACKS"'], 'The dragon attacks the castle.'), ['attack']);
      // A reported form need not equal the student's form — the target only
      // has to occur in the student's text.
      expect(credit(['attacked'], 'The dragon attacks the castle.'), ['attack']);
    });

    test('other supported inflections map to their base targets', () {
      expect(
        credit(['carried'], 'She carried the heavy box.', ['carry']),
        ['carry'],
      );
      expect(credit(['ran'], 'I ran to school.', ['run']), ['run']);
      expect(credit(['babies'], 'The babies are sleeping.', ['baby']), ['baby']);
      expect(credit(['stopped'], 'The bus stopped suddenly.', ['stop']), ['stop']);
      expect(credit(['taller'], 'She is taller than her brother.', ['tall']), ['tall']);
      expect(credit(['said'], 'He said goodbye to us.', ['say']), ['say']);
    });

    test('no credit when the reported target is absent from the student text', () {
      expect(credit(['attack'], 'The dragon flew over the castle.'), isEmpty);
      expect(credit(['attacked'], 'The dragon flew over the castle.'), isEmpty);
    });

    test('no credit for a word that is not a remaining target', () {
      expect(credit(['button'], 'I pressed the button.', ['attack']), isEmpty);
      // Already credited earlier in the session (no longer remaining).
      expect(credit(['attack'], 'They attacked again.', ['village']), isEmpty);
    });

    test('no credit for substrings or derived words', () {
      expect(credit(['attack'], 'The attacker ran away.'), isEmpty);
      expect(credit(['attacker'], 'The attacker ran away.'), isEmpty);
      expect(credit(['attack'], 'They launched a counterattack.'), isEmpty);
      expect(credit(['counterattack'], 'They launched a counterattack.'), isEmpty);
    });

    test('no credit for bare words, fragments, or lists even if the model reports them', () {
      for (final text in [
        'attack',
        'attacked',
        'Attack!',
        'the attack',
        'attack, button, ability',
        'attack button ability',
      ]) {
        expect(credit(['attack'], text, ['attack', 'button', 'ability']), isEmpty, reason: text);
      }
    });

    test('invalid over-inflections are not forms of the target', () {
      for (final bad in ['attackked', 'attackking', 'attackes', 'attackd']) {
        expect(matchesSingleWordForm(bad, 'attack'), isFalse, reason: bad);
        expect(credit([bad], 'The dragon $bad the castle.'), isEmpty, reason: bad);
      }
      expect(validFormsForSingleWord('be'), isNot(contains('bed')));
      expect(validFormsForSingleWord('see'), isNot(contains('seed')));
      expect(validFormsForSingleWord('run'), isNot(contains('runned')));
    });

    test('valid spelling-rule inflections are still accepted', () {
      expect(validFormsForSingleWord('attack'), containsAll(['attacks', 'attacked', 'attacking']));
      expect(validFormsForSingleWord('stop'), containsAll(['stops', 'stopped', 'stopping']));
      expect(validFormsForSingleWord('quit'), contains('quitting'));
      expect(validFormsForSingleWord('decide'), containsAll(['decides', 'decided', 'deciding']));
      expect(validFormsForSingleWord('agree'), containsAll(['agreed', 'agreeing']));
      expect(validFormsForSingleWord('die'), containsAll(['died', 'dying']));
      expect(validFormsForSingleWord('carry'), containsAll(['carries', 'carried', 'carrying']));
      expect(validFormsForSingleWord('box'), contains('boxes'));
      expect(validFormsForSingleWord('watch'), contains('watches'));
      expect(validFormsForSingleWord('potato'), contains('potatoes'));
      expect(validFormsForSingleWord('knife'), contains('knives'));
      expect(validFormsForSingleWord('panic'), containsAll(['panicked', 'panicking']));
      expect(validFormsForSingleWord('play'), containsAll(['plays', 'played', 'playing']));
    });

    test('mere mention and nonsense rely on the model judgement (documented boundary)', () {
      // Deterministic code cannot judge meaning: if the model (wrongly)
      // reports these, structure and presence alone let them through. The
      // Worker prompt instructs the model not to report them; that is
      // prompt-contract-tested in the Worker, not proven here.
      expect(credit([], 'I do not know the word attack.'), isEmpty);
      expect(credit([], 'The attack is blue cheese singing.'), isEmpty);
    });
  });

  group('containsIndonesianWords (deterministic language check)', () {
    test('flags Indonesian and mixed Indonesian-English turns', () {
      for (final text in [
        'aku attack temanku',
        'lalu aku tertawa hahaha',
        'gpt, bantu aku membuat list packing barang yang dibutuhkan untuk camping',
        'Saya pergi ke pasar.',
        'The monster attack desa itu.',
        'ini dan itu',
      ]) {
        expect(containsIndonesianWords(text, const ['attack']), isTrue, reason: text);
      }
    });

    test('normalizes capitalization and punctuation', () {
      expect(containsIndonesianWords('AKU attack temanku!!', const ['attack']), isTrue);
      expect(containsIndonesianWords('"Lalu," kata dia.', const []), isTrue);
      expect(containsIndonesianWords('Tolong... bantu aku?', const []), isTrue);
    });

    test('does not flag ordinary English, including off-topic English', () {
      for (final text in [
        'The monster attacked the village.',
        'Yesterday the monster attack the village.',
        'how many sorting algorithms are there',
        'what is 22+300*7/2',
        'Okay.',
        'The data on the main screen was wrong.',
        'We had jam and bread for breakfast.',
        'She put the pan in the bank of snow.',
        'Ya know, it was a long day.',
      ]) {
        expect(containsIndonesianWords(text, const ['attack']), isFalse, reason: text);
      }
    });

    test('name-like weak markers need a second marker; mid-sentence names are ignored', () {
      expect(containsIndonesianWords('Dan went home early.', const []), isFalse);
      expect(containsIndonesianWords('I met Dan and Ada at school.', const []), isFalse);
      expect(containsIndonesianWords('My friend Dia is kind.', const []), isFalse);
      expect(containsIndonesianWords('dan dia pulang', const []), isTrue);
      expect(containsIndonesianWords('ada dia', const []), isTrue);
    });

    test('yin and yang is English', () {
      expect(containsIndonesianWords('The yin and yang symbol was on the door.', const []), isFalse);
      expect(containsIndonesianWords('buku yang merah', const []), isTrue);
    });

    test('a target vocabulary word never counts as an Indonesian marker', () {
      // "dari" and "lagi" are markers, but not when they are the target words.
      expect(containsIndonesianWords('I bought dari yesterday.', const ['dari']), isFalse);
      expect(containsIndonesianWords('I bought dari yesterday.', const []), isTrue);
      expect(containsIndonesianWords('The attack was loud.', const ['attack']), isFalse);
    });
  });

  group('selectFallbackWord', () {
    test('returns null when nothing remains', () {
      expect(selectFallbackWord(const [], Random(1)), isNull);
    });

    test('always returns exactly one of the remaining words', () {
      const remaining = ['attack', 'button', 'ability'];
      final random = Random(42);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final picked = selectFallbackWord(remaining, random);
        expect(remaining, contains(picked));
        seen.add(picked!);
      }
      // Uniform selection eventually reaches every remaining word.
      expect(seen, remaining.toSet());
    });
  });

  group('validateStudentTargetWords', () {
    const eligible = ['attack', 'button', 'completely', 'run', 'souvenir'];

    test('credits target word only when present in a valid student sentence', () {
      expect(
        validateStudentTargetWords(
          claimedWords: ['button', 'attack'],
          studentTurnText: 'I pressed the button carefully.',
          eligibleTargetWords: eligible,
        ),
        equals(['button']),
      );
    });

    test('returns empty when student turn is bare or fragment even if AI claims usage', () {
      expect(
        validateStudentTargetWords(
          claimedWords: ['attack', 'button', 'completely'],
          studentTurnText: 'attack button completely',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
      expect(
        validateStudentTargetWords(
          claimedWords: ['button'],
          studentTurnText: 'the button',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
    });

    test('rejects words not in eligibleTargetWords or only matching as substrings', () {
      expect(
        validateStudentTargetWords(
          claimedWords: ['attack', 'unknown'],
          studentTurnText: 'The attacker ran away.',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
    });
  });

  group('validateBotTargetWords', () {
    const eligible = ['run', 'souvenir', 'baby', 'attack', 'button', 'carry'];

    test('credits bot word when in eligibleTargetWords and present in aiTurnText', () {
      expect(
        validateBotTargetWords(
          claimedWords: ['souvenir'],
          aiTurnText: 'I also bought a souvenir there.',
          eligibleTargetWords: eligible,
        ),
        equals(['souvenir']),
      );
    });

    test('detects eligible bot target words even when claimedWords (aiUsedWords) is empty', () {
      expect(
        validateBotTargetWords(
          claimedWords: const [],
          aiTurnText: 'I also bought a souvenir there.',
          eligibleTargetWords: eligible,
        ),
        equals(['souvenir']),
      );
    });

    test('detects inflected forms of eligible bot target words when claimedWords is empty', () {
      expect(
        validateBotTargetWords(
          claimedWords: const [],
          aiTurnText: 'The guard attacked the door and pressed two buttons while he ran and carried the baby.',
          eligibleTargetWords: eligible,
        ),
        equals(['run', 'baby', 'attack', 'button', 'carry']),
      );
    });

    test('only the application-selected word is credited when eligibility is narrowed to it', () {
      expect(
        validateBotTargetWords(
          claimedWords: const ['souvenir', 'run'],
          aiTurnText: 'She ran back and bought a souvenir.',
          eligibleTargetWords: const ['souvenir'],
        ),
        equals(['souvenir']),
      );
    });

    test('rejects bot word when absent from aiTurnText or not in eligibleTargetWords', () {
      expect(
        validateBotTargetWords(
          claimedWords: ['souvenir'],
          aiTurnText: 'They walked to the quiet park.',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
      expect(
        validateBotTargetWords(
          claimedWords: ['unlisted'],
          aiTurnText: 'That unlisted item was nice.',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
    });

    test('rejects substring-only matches in aiTurnText (e.g. crunchy for run, unbuttoned for button)', () {
      expect(
        validateBotTargetWords(
          claimedWords: const ['run', 'button', 'attack'],
          aiTurnText: 'The crunchy snack fell on his unbuttoned coat near the attacker.',
          eligibleTargetWords: eligible,
        ),
        isEmpty,
      );
    });
  });
}

