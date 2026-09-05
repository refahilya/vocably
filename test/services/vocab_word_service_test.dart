import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/services/vocab_word_service.dart';

class _CapturingVocabWordService extends VocabWordService {
  String? updatedWord;
  List<String>? updatedTopics;

  @override
  Future<void> updateTopics({
    required String normalizedWord,
    required List<String> topics,
  }) async {
    updatedWord = normalizedWord;
    updatedTopics = topics;
  }
}

void main() {
  group('VocabWordService', () {
    test('updateTopics sends the normalized word and updated topics list', () async {
      final service = _CapturingVocabWordService();

      await service.updateTopics(
        normalizedWord: 'apple',
        topics: const ['Buah', 'Makanan'],
      );

      expect(service.updatedWord, 'apple');
      expect(service.updatedTopics, ['Buah', 'Makanan']);
    });
  });
}
