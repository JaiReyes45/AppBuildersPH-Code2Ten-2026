import 'answer_generator.dart';
import 'classifier.dart';
import 'field_extractor.dart';
import 'models.dart';
import 'query_parser.dart';
import 'search_service.dart';

class GalleryHelpdeskAi {
  GalleryHelpdeskAi({EvidenceAnswerGenerator? answerGenerator})
    : _answerGenerator =
          answerGenerator ?? const DeterministicAnswerGenerator();

  final EvidenceAnswerGenerator _answerGenerator;
  final ScreenshotClassifier _classifier = ScreenshotClassifier();
  final FieldExtractor _fieldExtractor = FieldExtractor();
  final HelpdeskQueryParser _queryParser = HelpdeskQueryParser();
  final SearchService _searchService = SearchService();

  AnalyzedScreenshot analyze(OcrScreenshot screenshot) {
    final normalizedBlocks = screenshot.blocks
        .where((block) => block.id.trim().isNotEmpty)
        .toList(growable: false);
    return AnalyzedScreenshot(
      screenshotId: screenshot.screenshotId,
      category: _classifier.classify(normalizedBlocks),
      blocks: List.unmodifiable(normalizedBlocks),
      fields: _fieldExtractor.extract(normalizedBlocks),
    );
  }

  HelpdeskQuery parseQuery(String query) => _queryParser.parse(query);

  Future<GroundedAnswer> answer(
    String query,
    Iterable<AnalyzedScreenshot> screenshots,
  ) async {
    final parsedQuery = parseQuery(query);
    final matches = _searchService.search(parsedQuery, screenshots);
    return _answerGenerator.generate(parsedQuery, matches);
  }
}
