part of 'main.dart';

enum SearchPhase { idle, searching, found, uncertain }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.scanner,
    this.autoScanGallery = false,
    this.showDemoContent = kIsWeb,
  });
  final GalleryScanner? scanner;
  final bool autoScanGallery;
  final bool showDemoContent;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query = TextEditingController();
  final page = ScrollController();
  SearchPhase phase = SearchPhase.idle;
  String category = 'All';
  List<Evidence> matches = [];
  String? answerText;
  bool scannerReady = false;
  String? scannerError;
  GalleryScanProgress scanProgress = const GalleryScanProgress();
  final Map<String, Evidence> galleryEvidence = {};
  int request = 0;
  final GalleryHelpdeskAi ai = GalleryHelpdeskAi();
  late final GalleryScanner scanner = widget.scanner ?? GalleryScanner();
  late Future<void> _scannerInitialization;
  final Map<String, AnalyzedScreenshot> _analyzedGallery = {};
  bool scanning = false;
  bool _autoScanning = false;
  Future<bool>? _galleryScanTask;
  int scannedCount = 0;
  int targetCount = 0;
  String status =
      'Enter a request and tap the purple arrow to scan your gallery.';
  bool _allowDeeper = false;
  String _lastQuery = '';
  SemanticSearch? _semantic;
  bool _semanticUsed = false;
  bool _remembering = false;
  final List<Evidence> _recentFinds = [];

  final SearchCounts _searchCounts = SearchCounts();
  SearchHistoryStorage? _historyStorage;
  Future<void> _historyWrite = Future.value();
  String? _historyError;

  void _clearFrequentSearches() {
    setState(() => _searchCounts.counts.clear());
    _saveSearchCounts();
  }

  void _saveSearchCounts() {
    final snapshot = Map<String, int>.of(_searchCounts.counts);
    _historyWrite = _historyWrite.then((_) async {
      try {
        await _historyStorage?.saveSearchCounts(snapshot);
        if (mounted) setState(() => _historyError = null);
      } catch (_) {
        if (mounted) {
          setState(
            () => _historyError =
                'Search history could not be saved on this device.',
          );
        }
      }
    });
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const Text(
                    'Recently found',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Results from this session. Demo examples are labeled. Clearing this list does not delete photos.',
                  ),
                  const SizedBox(height: 20),
                  if (_recentFinds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        'Your next find starts here.\nSearch for a screenshot to add it to this space.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ..._recentFinds.map((e) => EvidenceCard(evidence: e)),
                  if (_recentFinds.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(_recentFinds.clear);
                        updateSheet(() {});
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Clear session history'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    scanner.onProgress = (progress) {
      if (mounted) setState(() => scanProgress = progress);
    };
    scanner.onRecord = (record) {
      if (!mounted) return;
      setState(() {
        if (record.isFailed) {
          galleryEvidence.remove(record.assetId);
          _analyzedGallery.remove('gallery-${record.assetId}');
        } else {
          galleryEvidence[record.assetId] = _evidenceForRecord(record);
        }
      });
    };
    _scannerInitialization = _initializeScanner();
    unawaited(_scannerInitialization);
  }

  Future<void> _initializeScanner() async {
    try {
      await scanner.initialize();
      try {
        _historyStorage = await scanner.searchHistoryStorage();
        final counts = await _historyStorage?.loadSearchCounts();
        if (counts != null) _searchCounts.replace(counts);
      } catch (_) {
        _historyError = 'Saved search history could not be loaded.';
      }
      final semanticStore = await scanner.semanticStore();
      if (mounted && semanticStore != null && !kIsWeb) {
        _semantic = SemanticSearch(MiniLmEmbedder(), semanticStore);
      }
      if (!mounted) return;
      setState(() {
        scannerReady = true;
        scannerError = null;
        scanProgress = scanner.progress;
        for (final record in scanner.records.where(
          (record) => !record.isFailed,
        )) {
          galleryEvidence[record.assetId] = _evidenceForRecord(record);
        }
      });
      if (widget.autoScanGallery && scanner.isSupported) {
        unawaited(_startGalleryScan());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        scannerReady = true;
        scannerError = 'Could not load the local scan index: $error';
        status = 'Local storage could not start. Tap Scan gallery to retry.';
      });
    }
  }

  Future<void> _startGalleryScan() async {
    if (!mounted ||
        !scannerReady ||
        scanner.isRunning ||
        phase == SearchPhase.searching) {
      return;
    }
    if (scannerError != null) {
      _scannerInitialization = _initializeScanner();
      await _scannerInitialization;
      if (!mounted || scannerError != null) return;
    }
    setState(() {
      _autoScanning = true;
      status = 'Requesting gallery access...';
    });
    final task = scanner.scanGallery();
    _galleryScanTask = task;
    try {
      await task;
    } catch (_) {
      // The scanner publishes its recoverable permission/error status.
    } finally {
      if (mounted) {
        setState(() {
          _autoScanning = false;
          status = scanner.progress.message;
        });
      }
    }
  }

  List<Evidence> get _availableEvidence => [
    if (widget.showDemoContent) ...samples,
    ...galleryEvidence.values,
  ];

  Evidence _evidenceForRecord(GalleryScanRecord record) {
    final screenshotId = 'gallery-${record.assetId}';
    final blocks = record.blocks
        .map(
          (block) => OcrBlock(
            id: block.id,
            text: block.text,
            boundingBox:
                block.left == null ||
                    block.top == null ||
                    block.width == null ||
                    block.height == null
                ? null
                : OcrBoundingBox(
                    left: block.left!,
                    top: block.top!,
                    width: block.width!,
                    height: block.height!,
                  ),
          ),
        )
        .toList(growable: false);
    final analyzed = ai.analyze(
      OcrScreenshot(screenshotId: screenshotId, blocks: blocks),
    );
    _analyzedGallery[screenshotId] = analyzed;
    final category = switch (analyzed.category) {
      HelpdeskCategory.gcashReceipt => 'Receipts',
      HelpdeskCategory.order => 'Orders',
      HelpdeskCategory.announcement => 'Announcements',
      HelpdeskCategory.other || HelpdeskCategory.unknown => 'Other',
    };
    final preferredFields = switch (analyzed.category) {
      HelpdeskCategory.gcashReceipt => [
        ExtractedFieldType.referenceNumber,
        ExtractedFieldType.amount,
        ExtractedFieldType.transactionDate,
      ],
      HelpdeskCategory.order => [
        ExtractedFieldType.orderNumber,
        ExtractedFieldType.itemName,
        ExtractedFieldType.amount,
      ],
      HelpdeskCategory.announcement => [
        ExtractedFieldType.deadline,
        ExtractedFieldType.title,
      ],
      HelpdeskCategory.other || HelpdeskCategory.unknown => const [],
    };
    ExtractedField? primaryField;
    for (final type in preferredFields) {
      for (final field in analyzed.fields) {
        if (field.type == type) {
          primaryField = field;
          break;
        }
      }
      if (primaryField != null) break;
    }
    primaryField ??= analyzed.fields.firstOrNull;
    final firstLine = blocks
        .map((block) => block.text.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Scanned photo');
    final titleField = analyzed.fields.where(
      (field) =>
          field.type == ExtractedFieldType.itemName ||
          field.type == ExtractedFieldType.title,
    );
    final title = titleField.isNotEmpty ? titleField.first.rawValue : firstLine;
    final date = record.scannedAt.toLocal();
    final dateLabel =
        'Scanned ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final fieldLabel = switch (primaryField?.type) {
      ExtractedFieldType.referenceNumber => 'Reference number',
      ExtractedFieldType.orderNumber => 'Order number',
      ExtractedFieldType.amount => 'Amount',
      ExtractedFieldType.transactionDate => 'Transaction date',
      ExtractedFieldType.deadline => 'Deadline',
      ExtractedFieldType.title => 'Title',
      ExtractedFieldType.itemName => 'Item',
      null => 'Recognized text',
    };
    final recognizedText = record.recognizedText;
    return Evidence(
      title.length > 100 ? '${title.substring(0, 100)}...' : title,
      category,
      dateLabel,
      primaryField?.rawValue ?? firstLine,
      fieldLabel,
      primaryField?.rawValue ??
          (recognizedText.length > 160
              ? '${recognizedText.substring(0, 160)}...'
              : recognizedText),
      recognizedText,
      switch (category) {
        'Receipts' => Icons.receipt_long_outlined,
        'Orders' => Icons.shopping_bag_outlined,
        'Announcements' => Icons.school_outlined,
        _ => Icons.image_outlined,
      },
      sourceScreenshotId: screenshotId,
      matchingBlockIds: const [],
      sourceImagePath: record.imagePath,
      isGallerySource: true,
      fields: {
        for (final field in analyzed.fields)
          switch (field.type) {
            ExtractedFieldType.amount => 'Amount',
            ExtractedFieldType.referenceNumber => 'Reference number',
            ExtractedFieldType.orderNumber => 'Order number',
            ExtractedFieldType.transactionDate => 'Transaction date',
            ExtractedFieldType.deadline => 'Deadline',
            ExtractedFieldType.title => 'Title',
            ExtractedFieldType.itemName => 'Item',
          }: analyzed.fields
              .where((f) => f.type == field.type)
              .map((f) => f.rawValue)
              .toSet()
              .join(' / '),
      },
    );
  }

  Future<void> _retryFailedPhotos() async {
    try {
      await scanner.retryFailed();
    } catch (error) {
      _showScanMessage('Could not retry failed photos: $error');
    }
  }

  Future<void> _clearScannedPhotos() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove scanned photos?'),
        content: const Text(
          'This deletes the app’s private image copies and local OCR records. Original gallery photos will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep photos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove scan data'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    try {
      await _semantic?.forget();
      await scanner.clear();
      if (mounted) {
        setState(() {
          galleryEvidence.clear();
          _recentFinds.removeWhere((e) => e.isGallerySource);
          _analyzedGallery.clear();
          matches = [];
          answerText = null;
          phase = SearchPhase.idle;
          _allowDeeper = false;
          status = 'Search to scan photos on this device.';
        });
      }
    } catch (error) {
      _showScanMessage('Could not clear scan data: $error');
    }
  }

  void _showScanMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    request++;
    scanner.cancelScan();
    unawaited(_semantic?.close());
    scanner.onRecord = null;
    scanner.onProgress = null;
    query.dispose();
    page.dispose();
    super.dispose();
  }

  Future<void> search([String? suggestion]) async {
    if (suggestion != null) query.text = suggestion;
    await handleSearch(query.text);
  }

  Future<void> handleSearch(String rawQuery, {int? additionalCount}) async {
    if (rawQuery.trim().isEmpty || phase == SearchPhase.searching) return;
    if (_autoScanning) {
      scanner.cancelScan();
      try {
        await _galleryScanTask;
      } catch (_) {}
    }
    if (!mounted || phase == SearchPhase.searching || scanner.isRunning) {
      return;
    }
    FocusScope.of(context).unfocus();
    final ticket = ++request;
    final manual = additionalCount != null;
    final now = DateTime.now();
    final normalized = normalizeAmountWords(rawQuery.trim());
    final dateHint = parseDateHint(rawQuery, now: now);
    final parsed = ai.parseQuery(queryWithoutDateHint(normalized, now: now));
    setState(() {
      _semanticUsed = false;
      phase = SearchPhase.searching;
      category = 'All';
      answerText = null;
      matches = [];
      _allowDeeper = false;
      _lastQuery = rawQuery;
      status = 'Checking indexed photos...';
    });
    if (page.hasClients) page.jumpTo(0);
    try {
      await _scannerInitialization;
      if (!mounted || ticket != request) return;
      if (parsed.keywords.isEmpty &&
          parsed.category == null &&
          parsed.amount == null &&
          parsed.exactIdentifier == null &&
          parsed.requiredPhrases.isEmpty &&
          dateHint == null) {
        setState(() {
          phase = SearchPhase.uncertain;
          status = 'Please add a detail before scanning.';
          answerText = 'What screenshot are you looking for? Include a name, amount, topic, or words you remember.';
        });
        return;
      }
      if (scannerError != null) {
        _scannerInitialization = _initializeScanner();
        await _scannerInitialization;
        if (!mounted || ticket != request) return;
        if (scannerError != null) throw StateError(scannerError!);
      }
      if (!manual) {
        setState(() => _searchCounts.record(rawQuery));
        _saveSearchCounts();
      }
      var outcome = await _searchWith(parsed, dateHint, prepareSemantic: false);
      if (!mounted || ticket != request) return;
      // A cached gallery hit answers immediately; demo hits never stop scans.
      if (!manual && outcome.galleryMatches.isNotEmpty) {
        _showResults(
          outcome,
          parsed,
          allowDeeper: scanner.isSupported,
          message: 'Ready — showing indexed photos.',
        );
        return;
      }
      if (!scanner.isSupported || scannerError != null) {
        _showResults(
          outcome,
          parsed,
          allowDeeper: false,
          message:
              scannerError ?? 'Gallery scanning is available on Android/iOS.',
        );
        return;
      }
      scanner.refreshCatalog();
      final attempted = <String>{};
      for (var batch = 0; ; batch++) {
        if (!mounted || ticket != request) return;
        setState(() {
          scanning = true;
          scannedCount = 0;
          targetCount = additionalCount ?? 40;
          status = batch == 0
              ? 'Scanning on this device...'
              : 'Searching deeper...';
        });
        GalleryScanProgress? last;
        await for (final progress in scanner.scanUpTo(
          additionalCount: additionalCount ?? 40,
          dateFilter: dateHint,
          attemptedAssetIds: attempted,
        )) {
          if (!mounted || ticket != request) {
            scanner.cancelScan();
            break;
          }
          last = progress;
          setState(() {
            scannedCount = progress.processed;
            targetCount = progress.total;
            if (batch == 0 || !progress.isScanning) status = progress.message;
          });
        }
        if (!mounted || ticket != request) return;
        setState(() => scanning = false);
        outcome = await _searchWith(parsed, dateHint, prepareSemantic: false);
        if (!mounted || ticket != request) return;
        final ready = last?.status == 'ready';
        final hasMore = ready && last!.hasMore;
        if (ready && !hasMore && outcome.galleryMatches.isEmpty) {
          outcome = await _searchWith(parsed, dateHint);
          if (!mounted || ticket != request) return;
        }
        if (outcome.galleryMatches.isNotEmpty || !hasMore || manual) {
          final message = !ready
              ? last?.message ?? 'Scan stopped.'
              : outcome.galleryMatches.isNotEmpty
              ? 'Ready'
              : hasMore
              ? 'No matching gallery photos yet. You can search deeper.'
              : 'No matches found in accessible indexed photos. Failed photos may need retry.';
          _showResults(outcome, parsed, allowDeeper: hasMore, message: message);
          return;
        }
      }
    } catch (error) {
      if (!mounted || ticket != request) return;
      setState(() {
        scanning = false;
        phase = SearchPhase.uncertain;
        status = 'Could not complete search: $error';
      });
    }
  }

  Future<_SearchOutcome> _searchWith(
    HelpdeskQuery parsed,
    DateTimeRange? dateHint, {
    bool indexMore = false,
    bool prepareSemantic = true,
  }) async {
    final evidenceById = <String, Evidence>{};
    final gallery = <AnalyzedScreenshot>[];
    final dates = {
      for (final record in scanner.records)
        record.assetId: record.assetCreatedAt,
    };
    for (final entry in galleryEvidence.entries) {
      final evidence = entry.value;
      final created = dates[entry.key];
      if (dateHint != null &&
          (created == null ||
              created.isBefore(dateHint.start) ||
              created.isAfter(dateHint.end))) {
        continue;
      }
      final id = evidence.sourceScreenshotId!;
      evidenceById[id] = evidence;
      final analyzed = _analyzedGallery[id];
      if (analyzed != null) gallery.add(analyzed);
    }
    final demo = <AnalyzedScreenshot>[];
    for (final entry
        in (widget.showDemoContent ? samples : <Evidence>[]).asMap().entries) {
      final evidence = entry.value;
      final screenshotId = evidence.sourceScreenshotId ?? 'sample-${entry.key}';
      evidenceById[screenshotId] = evidence;
      demo.add(
        ai.analyze(
          OcrScreenshot(
            screenshotId: screenshotId,
            blocks: evidence.source
                .split('\n')
                .asMap()
                .entries
                .where((line) => line.value.trim().isNotEmpty)
                .map(
                  (line) => OcrBlock(
                    id: '$screenshotId-block-${line.key}',
                    text: line.value.trim(),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }
    var galleryAnswer = await ai.answer(parsed.originalText, gallery);
    _semanticUsed = galleryAnswer.sources.any((m) => m.isApproximate);
    if (dateHint != null &&
        parsed.keywords.isEmpty &&
        parsed.category == null &&
        parsed.amount == null &&
        parsed.exactIdentifier == null &&
        parsed.requiredPhrases.isEmpty) {
      galleryAnswer = GroundedAnswer(
        text: 'Screenshots saved in the requested date range.',
        sources: SearchService().search(
          parsed,
          gallery,
          allowUnconstrained: true,
        ),
        needsClarification: gallery.isEmpty,
      );
    }
    if ((galleryAnswer.sources.isEmpty || indexMore) &&
        _semantic != null &&
        gallery.isNotEmpty &&
        hasSemanticSearchAnchor(parsed, gallery)) {
      final ticket = request;
      final related = await _semantic!.search(
        parsed,
        gallery,
        indexMore: indexMore,
        prepareMissing: prepareSemantic,
        cancelled: () => !mounted || ticket != request,
        onProgress: (done, total) {
          if (mounted &&
              ticket == request &&
              (done % 10 == 0 || done == total)) {
            setState(
              () => status = 'Preparing local meaning index: $done / $total',
            );
          }
        },
      );
      if (related.isNotEmpty && galleryAnswer.sources.isEmpty) {
        _semanticUsed = true;
        galleryAnswer = GroundedAnswer(
          text: 'Related screenshots by meaning. Check the original before confirming a match.',
          sources: related,
          needsClarification: true,
        );
      }
    }
    final demoAnswer = await ai.answer(parsed.originalText, demo);
    List<Evidence> evidenceFor(GroundedAnswer answer) {
      final candidates = <Evidence>[];
      for (final source in answer.sources) {
        final evidence = evidenceById[source.screenshot.screenshotId];
        if (evidence != null) {
          candidates.add(
            evidence.withSourceMatches(
              screenshotId: source.screenshot.screenshotId,
              blockIds: source.matchingBlockIds,
            ),
          );
        }
      }
      return candidates;
    }

    return _SearchOutcome(
      evidenceFor(galleryAnswer),
      evidenceFor(demoAnswer),
      '${galleryAnswer.text}${demoAnswer.sources.isEmpty ? '' : '\n\nDemo content (fictional):\n${demoAnswer.text}'}',
    );
  }

  void _showResults(
    _SearchOutcome outcome,
    HelpdeskQuery parsedQuery, {
    required bool allowDeeper,
    required String message,
  }) {
    ScanTimings.report();
    setState(() {
      scanning = false;
      matches = [...outcome.galleryMatches, ...outcome.sampleMatches];
      for (final item in matches.reversed) {
        _recentFinds.removeWhere(
          (e) => e.sourceScreenshotId == item.sourceScreenshotId,
        );
        _recentFinds.insert(0, item);
      }
      if (_recentFinds.length > 50) {
        _recentFinds.removeRange(50, _recentFinds.length);
      }
      answerText = outcome.text;
      _allowDeeper = allowDeeper;
      status = message;
      phase = matches.isNotEmpty && !_semanticUsed
          ? SearchPhase.found
          : SearchPhase.uncertain;
      if (phase == SearchPhase.uncertain) {
        category = switch (parsedQuery.category) {
          HelpdeskCategory.gcashReceipt => 'Receipts',
          HelpdeskCategory.order => 'Orders',
          HelpdeskCategory.announcement => 'Announcements',
          HelpdeskCategory.other || HelpdeskCategory.unknown || null => 'All',
        };
      }
    });
    if (page.hasClients) page.jumpTo(0);
  }

  void reset() {
    request++;
    scanner.cancelScan();
    query.clear();
    setState(() {
      phase = SearchPhase.idle;
      category = 'All';
      matches = [];
      answerText = null;
      scanning = false;
      _allowDeeper = false;
      status = 'Search cancelled. Indexed photos are saved.';
    });
    if (page.hasClients) {
      page.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final browsing =
        phase == SearchPhase.idle ||
        (phase == SearchPhase.uncertain && !_semanticUsed && category != 'All');
    final evidence = _availableEvidence;
    final visible = (browsing ? evidence : matches)
        .where((e) => category == 'All' || e.category == category)
        .toList();
    final title = switch (phase) {
      SearchPhase.idle => 'What are you\nlooking for today?',
      SearchPhase.searching => 'Let me look in the box…',
      SearchPhase.found => 'Ta-da! Here’s what I found.',
      SearchPhase.uncertain => 'Let’s look together.',
    };
    final subtitle = switch (phase) {
      SearchPhase.idle => 'Ask about a receipt, order, or class announcement.',
      SearchPhase.searching =>
        'Searching your device gallery for your request.',
      SearchPhase.found =>
        '${matches.length} matching ${matches.length == 1 ? 'screenshot' : 'screenshots'}. Open one to check the details.',
      SearchPhase.uncertain => 'No exact match yet. Check gallery access and scan status, or browse possible screenshots below.',
    };
    return Scaffold(
      bottomNavigationBar: scanning
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scanning on this device. Nothing leaves your phone.',
                    ),
                    Text('$scannedCount / $targetCount'),
                    LinearProgressIndicator(
                      value: targetCount == 0
                          ? null
                          : (scannedCount / targetCount).clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            )
          : null,
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 24),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'SSeeker',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['serif'],
                  color: violet,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recently found',
            onPressed: _openHistory,
            icon: Badge(
              isLabelVisible: _recentFinds.isNotEmpty,
              child: const Icon(Icons.history_rounded),
            ),
          ),
          IconButton(
            tooltip: 'About SSeeker',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              useSafeArea: true,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85,
              ),
              builder: (_) => const SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSeeker by Code2Ten',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Find receipts, order details and student announcements buried in your gallery. SSeeker reads screenshots and searches their text on your device, helping you return to the source without scrolling through hundreds of photos.\n\nCreated by Code2Ten\nRalph Abaya\nKyle Israel Concepcion\nPatrick Gengania\nGuienne Jairo Reyes',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Clear scan removes the app’s copies and OCR index, not the original gallery photos.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            controller: page,
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 7, color: Color(0xFF658878)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !kIsWeb && galleryEvidence.isNotEmpty
                          ? 'Local gallery OCR + sample text · offline AI core'
                          : 'Sample OCR text · offline AI core',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              if (scanner.isSupported) ...[
                const SizedBox(height: 12),
                Material(
                  color: lavender,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _autoScanning
                              ? 'Indexing your gallery'
                              : 'Device gallery',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          scannerError != null
                              ? 'Local storage could not start. Tap Scan gallery to retry.'
                              : _autoScanning
                              ? scanProgress.message
                              : scanner.limitedGalleryAccess
                              ? 'Selected-photo access only. Allow all photos in Android settings to search the whole gallery.'
                              : scanProgress.status == 'permissionDenied' ||
                                    scanProgress.status == 'error' ||
                                    scanProgress.status == 'cancelled' ||
                                    scanProgress.status == 'complete'
                              ? scanProgress.message
                              : '${galleryEvidence.length} local photos indexed. No upload needed.',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (_autoScanning)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: _autoScanning
                                  ? scanner.cancelScan
                                  : scannerReady &&
                                        !scanner.isRunning &&
                                        phase != SearchPhase.searching
                                  ? _startGalleryScan
                                  : null,
                              icon: Icon(
                                _autoScanning
                                    ? Icons.pause
                                    : Icons.photo_library_outlined,
                              ),
                              label: Text(
                                _autoScanning ? 'Pause scan' : 'Scan gallery',
                              ),
                            ),
                            if (scanner.limitedGalleryAccess ||
                                scanProgress.status == 'permissionDenied')
                              TextButton(
                                onPressed: scanner.openGallerySettings,
                                child: const Text('Photo permissions'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Semantics(
                label: phase == SearchPhase.searching
                    ? 'Bot looking inside a box'
                    : 'Bot with a screenshot box',
                child: BotBox(phase: phase),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['serif'],
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
              if (phase == SearchPhase.searching ||
                  _semantic?.unavailableReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _semantic?.unavailableReason ?? status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (_semantic != null && phase != SearchPhase.searching)
                TextButton(
                  onPressed: _remembering
                      ? null
                      : () async {
                          await _semantic!.forget();
                          if (mounted) {
                            _showScanMessage(
                              'Local search learning and meaning index cleared. OCR is kept.',
                            );
                          }
                        },
                  child: const Text('Reset search learning'),
                ),
              if ((_semantic?.pendingDocuments ?? 0) > 0 &&
                  phase != SearchPhase.searching)
                TextButton.icon(
                  onPressed: _continueMeaningIndex,
                  icon: const Icon(Icons.manage_search),
                  label: Text(
                    'Prepare more saved screenshots (${_semantic!.pendingDocuments} remaining)',
                  ),
                ),
              if (answerText != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evidence-based answer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _semanticUsed
                            ? 'Possible match by spelling or meaning. Please check the source.'
                            : matches.isEmpty
                            ? 'No verified match yet. Try a more specific detail or browse below.'
                            : '${matches.length} candidate screenshots. Extracted details:',
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                      for (final item in matches.take(3)) ...[
                        const Divider(height: 20),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DetailScreen(evidence: item),
                            ),
                          ),
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!item.isGallerySource)
                          const Text(
                            'Demo content',
                            style: TextStyle(fontSize: 11),
                          ),
                        for (final field
                            in (item.fields.isEmpty
                                    ? {item.field: item.value}
                                    : item.fields)
                                .entries
                                .take(4))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${field.key}: ${field.value}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        if (item.isGallerySource && _semantic != null)
                          TextButton.icon(
                            onPressed: _remembering
                                ? null
                                : () => _rememberResult(item),
                            icon: const Icon(Icons.thumb_up_outlined, size: 16),
                            label: const Text('This is the one'),
                          ),
                      ],
                      Material(
                        color: Colors.transparent,
                        child: ExpansionTile(
                          title: const Text(
                            'Response details',
                            style: TextStyle(fontSize: 12),
                          ),
                          children: [
                            SelectableText(
                              answerText!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: query,
                onSubmitted: (_) => search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "Let's find it together.",
                  hintStyle: TextStyle(color: ink.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2DED6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2DED6)),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton.filled(
                      tooltip: phase == SearchPhase.searching
                          ? 'Search in progress'
                          : 'Find screenshot',
                      onPressed: phase == SearchPhase.searching
                          ? null
                          : () => search(),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              if (phase != SearchPhase.idle)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: reset,
                    child: Text(
                      phase == SearchPhase.searching
                          ? 'Cancel search'
                          : 'Start again',
                    ),
                  ),
                ),
              if (phase != SearchPhase.searching) ...[
                if (_recentFinds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor: lavender,
                    leading: const Icon(Icons.history_rounded, color: violet),
                    title: const Text('Pick up where you left off'),
                    subtitle: Text(
                      '${_recentFinds.length} recently found in this session',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onTap: _openHistory,
                  ),
                ],
                const SizedBox(height: 24),
                if (phase == SearchPhase.idle) ...[
                  _boxFolders(evidence),
                  const SizedBox(height: 24),
                  _frequentSearches(),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phase == SearchPhase.uncertain
                              ? 'Browse possible screenshots'
                              : phase == SearchPhase.found
                              ? 'Found in your box'
                              : 'Explore your box',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length} ${visible.length == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                'All',
                                'Receipts',
                                'Orders',
                                'Announcements',
                                'Other',
                              ]
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: ChoiceChip(
                                    label: Text(s),
                                    selected: category == s,
                                    showCheckmark: false,
                                    selectedColor: lavender,
                                    onSelected: (_) =>
                                        setState(() => category = s),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No scanned photos in this category. Try All.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...visible
                      .where((e) => e.isGallerySource)
                      .map((e) => EvidenceCard(evidence: e)),
                  if (visible.any((e) => !e.isGallerySource)) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Demo content',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...visible
                        .where((e) => !e.isGallerySource)
                        .map((e) => EvidenceCard(evidence: e)),
                  ],
                ],
                if (_allowDeeper)
                  TextButton(
                    onPressed: scanner.isRunning
                        ? null
                        : () => handleSearch(_lastQuery, additionalCount: 120),
                    child: const Text('Search deeper (add 120 more)'),
                  ),
              ],
              if (scanner.isSupported) ...[
                const SizedBox(height: 20),
                _galleryScanPanel(),
              ],
              const SizedBox(height: 20),
              const Text(
                'You’re in control. Every result has a source.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueMeaningIndex() async {
    if (phase == SearchPhase.searching || _lastQuery.isEmpty) return;
    final ticket = ++request;
    final now = DateTime.now();
    final parsed = ai.parseQuery(
      queryWithoutDateHint(normalizeAmountWords(_lastQuery), now: now),
    );
    setState(() {
      phase = SearchPhase.searching;
      status = 'Preparing more saved screenshots...';
    });
    final result = await _searchWith(
      parsed,
      parseDateHint(_lastQuery, now: now),
      indexMore: true,
    );
    if (!mounted || ticket != request) return;
    _showResults(
      result,
      parsed,
      allowDeeper: _allowDeeper,
      message: 'Searched the local meaning index.',
    );
  }

  Future<void> _rememberResult(Evidence item) async {
    final analyzed = _analyzedGallery[item.sourceScreenshotId];
    if (analyzed == null || _semantic == null || _remembering) return;
    setState(() => _remembering = true);
    try {
      await _semantic!.remember(
        queryWithoutDateHint(normalizeAmountWords(_lastQuery)),
        analyzed,
      );
      if (mounted) {
        _showScanMessage('Remembered on this device for similar searches.');
      }
    } catch (_) {
      if (mounted) {
        _showScanMessage(
          'Could not save this preference. Your screenshot is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _remembering = false);
    }
  }

  Widget _galleryScanPanel() {
    final running =
        scanning || scanner.isRunning || phase == SearchPhase.searching;
    final indexedCount = scanner.records
        .where((record) => !record.isFailed)
        .length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2DED6)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gallery scan controls',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            '$indexedCount indexed · ${scanner.failedCount} failed',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scans stay on this device. Clear scan removes the app’s copies and OCR data.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          if (scanning) ...[
            const SizedBox(height: 8),
            const Text('Scanning on this device. Nothing leaves your phone.'),
            Text('$scannedCount / $targetCount'),
            LinearProgressIndicator(
              value: targetCount == 0
                  ? null
                  : (scannedCount / targetCount).clamp(0.0, 1.0),
            ),
          ] else if (scanProgress.isScanning) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: running ? scanProgress.fraction : 1),
          ],
          const SizedBox(height: 6),
          Text(
            scannerError ??
                (scanProgress.isScanning && !scanning
                    ? scanProgress.message
                    : status),
            style: TextStyle(
              fontSize: 12,
              color: scannerError == null
                  ? Colors.black54
                  : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (scanner.failedCount > 0)
                TextButton.icon(
                  onPressed: scannerReady && !running
                      ? _retryFailedPhotos
                      : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry failed'),
                ),
              if (scanner.records.isNotEmpty)
                TextButton(
                  onPressed: scannerReady && !running
                      ? _clearScannedPhotos
                      : null,
                  child: const Text('Clear scan'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchOutcome {
  const _SearchOutcome(this.galleryMatches, this.sampleMatches, this.text);
  final List<Evidence> galleryMatches;
  final List<Evidence> sampleMatches;
  final String text;
}

class EvidenceCard extends StatelessWidget {
  final Evidence evidence;
  const EvidenceCard({super.key, required this.evidence});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DetailScreen(evidence: evidence),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 82,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: evidence.category == 'Receipts'
                      ? const Color(0xFFE9F0FF)
                      : evidence.category == 'Orders'
                      ? const Color(0xFFF9EBDD)
                      : const Color(0xFFEDE9F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    evidence.isGallerySource && evidence.sourceImagePath != null
                    ? evidenceImage(evidence.sourceImagePath!)
                    : Column(
                        children: [
                          Icon(evidence.icon, color: ink, size: 25),
                          const SizedBox(height: 9),
                          Container(height: 3, color: Colors.white),
                          const SizedBox(height: 5),
                          Container(height: 3, color: Colors.white),
                          const SizedBox(height: 5),
                          Container(height: 3, width: 22, color: Colors.white),
                        ],
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evidence.isGallerySource
                          ? evidence.category
                          : '${evidence.category} · Demo content',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      evidence.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      evidence.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      evidence.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
            ],
          ),
        ),
      ),
    ),
  );
}

class BotBox extends StatefulWidget {
  final SearchPhase phase;
  const BotBox({super.key, required this.phase});
  @override
  State<BotBox> createState() => _BotBoxState();
}

class _BotBoxState extends State<BotBox> with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateMotion();
  }

  @override
  void didUpdateWidget(BotBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateMotion();
  }

  void updateMotion() {
    if (widget.phase == SearchPhase.searching &&
        !MediaQuery.disableAnimationsOf(context)) {
      motion.repeat(reverse: true);
    } else if (widget.phase == SearchPhase.found &&
        !MediaQuery.disableAnimationsOf(context)) {
      motion.forward(from: 0);
    } else {
      motion.stop();
      motion.value = 0;
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 190,
    child: AnimatedBuilder(
      animation: motion,
      builder: (_, _) => CustomPaint(
        painter: BotPainter(widget.phase, motion.value),
        size: const Size(double.infinity, 190),
      ),
    ),
  );
}

class BotPainter extends CustomPainter {
  final SearchPhase phase;
  final double t;
  BotPainter(this.phase, this.t);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2 - 110, 5);
    final paint = Paint();
    void rect(Rect r, Color color, double radius) {
      paint.color = color;
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), paint);
    }

    void line(Offset a, Offset b, Color color, double width) {
      paint
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      c.drawLine(a, b, paint);
    }

    paint.color = const Color(0xFFE9E5DE);
    c.drawOval(const Rect.fromLTWH(42, 162, 146, 12), paint);
    final searching = phase == SearchPhase.searching;
    final happy = phase == SearchPhase.found;
    final bob = searching
        ? math.sin(t * math.pi * 2) * 6
        : happy
        ? -math.sin(t * math.pi) * 8
        : 0.0;
    // A robot dips into the open box, looking left and right.
    c.save();
    c.translate(searching ? (t - .5) * 12 : 0, searching ? 27 + bob : bob);
    line(const Offset(109, 49), const Offset(109, 35), ink, 3);
    paint.color = const Color(0xFFDF8869);
    c.drawCircle(const Offset(109, 32), 5, paint);
    rect(const Rect.fromLTWH(65, 49, 88, 58), violet, 18);
    rect(const Rect.fromLTWH(76, 60, 66, 33), const Color(0xFF293E43), 12);
    final eyes = searching ? (t - .5) * 9 : 0.0;
    for (final x in [94.0, 124.0]) {
      if (happy) {
        line(Offset(x - 4, 74), Offset(x, 70), const Color(0xFFE5F5CF), 2);
        line(Offset(x, 70), Offset(x + 4, 74), const Color(0xFFE5F5CF), 2);
      } else {
        paint.color = const Color(0xFFE5F5CF);
        c.drawCircle(Offset(x + eyes, 75), 3.5, paint);
      }
    }
    rect(const Rect.fromLTWH(84, 108, 50, 32), violet, 12);
    line(const Offset(84, 115), Offset(56, searching ? 140 : 120), violet, 9);
    line(
      const Offset(134, 115),
      Offset(happy ? 169 : 160, happy ? 86 : 137),
      violet,
      9,
    );
    c.restore();
    rect(const Rect.fromLTWH(57, 125, 107, 39), const Color(0xFFD7AC7A), 5);
    final flap = Path()
      ..moveTo(57, 125)
      ..lineTo(37, 108)
      ..lineTo(91, 108)
      ..lineTo(110, 125)
      ..close();
    paint.color = const Color(0xFFE9C899);
    c.drawPath(flap, paint);
    final flap2 = Path()
      ..moveTo(110, 125)
      ..lineTo(131, 108)
      ..lineTo(184, 108)
      ..lineTo(164, 125)
      ..close();
    paint.color = const Color(0xFFE6BF8B);
    c.drawPath(flap2, paint);
    line(
      const Offset(110, 129),
      const Offset(110, 160),
      const Color(0xFFBE9160),
      2,
    );
    rect(const Rect.fromLTWH(73, 138, 22, 13), const Color(0xFFF9E7CC), 3);
    if (happy) {
      c.save();
      c.translate(170, 70);
      c.rotate(-.13);
      rect(const Rect.fromLTWH(-17, -20, 35, 46), Colors.white, 5);
      rect(const Rect.fromLTWH(-11, -13, 23, 15), const Color(0xFFE1EBDC), 3);
      line(const Offset(-9, 10), const Offset(10, 10), violet, 2);
      line(const Offset(-9, 16), const Offset(4, 16), violet, 2);
      c.restore();
      for (final p in [
        const Offset(40, 62),
        const Offset(181, 37),
        const Offset(193, 100),
      ]) {
        line(p.translate(-4, 0), p.translate(4, 0), const Color(0xFFDF8869), 2);
        line(p.translate(0, -4), p.translate(0, 4), const Color(0xFFDF8869), 2);
      }
    }
    if (phase == SearchPhase.uncertain) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, const Offset(166, 57));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(BotPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.t != t;
}
