part of 'main.dart';

enum SearchPhase { idle, searching, found, uncertain }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
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
  final GalleryScanner scanner = GalleryScanner();
  final ImagePicker imagePicker = ImagePicker();

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
        } else {
          galleryEvidence[record.assetId] = _evidenceForRecord(record);
        }
      });
    };
    unawaited(_initializeScanner());
  }

  Future<void> _initializeScanner() async {
    try {
      await scanner.initialize();
      if (!mounted) return;
      setState(() {
        scannerReady = true;
        scanProgress = scanner.progress;
        for (final record in scanner.records.where(
          (record) => !record.isFailed,
        )) {
          galleryEvidence[record.assetId] = _evidenceForRecord(record);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        scannerReady = true;
        scannerError = 'Could not load the local scan index: $error';
      });
    }
  }

  List<Evidence> get _availableEvidence => [
    ...samples,
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
      title,
      category,
      dateLabel,
      primaryField?.rawValue ?? firstLine,
      fieldLabel,
      primaryField?.rawValue ?? recognizedText,
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
    );
  }

  Future<void> _scanGallery() async {
    try {
      final granted = await scanner.scanGallery();
      if (!granted && mounted) {
        _showScanMessage(
          'Choose specific photos if you do not want to grant gallery access.',
        );
      }
    } catch (error) {
      _showScanMessage('Gallery scan failed: $error');
    }
  }

  Future<void> _choosePhotos() async {
    try {
      final images = await imagePicker.pickMultiImage();
      if (images.isEmpty) return;
      await scanner.scanPickedImages(images);
    } catch (error) {
      _showScanMessage('Selected-photo scan failed: $error');
    }
  }

  Future<void> _resumeInterruptedScan() async {
    try {
      await scanner.resumeInterruptedScan();
    } catch (error) {
      _showScanMessage('Could not resume the interrupted scan: $error');
    }
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
      await scanner.clear();
      if (mounted) {
        setState(() {
          galleryEvidence.clear();
          matches = [];
          answerText = null;
          phase = SearchPhase.idle;
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
    query.dispose();
    page.dispose();
    super.dispose();
  }

  Future<void> search([String? suggestion]) async {
    if (suggestion != null) query.text = suggestion;
    final input = query.text.trim();
    if (input.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ticket = ++request;
    setState(() {
      phase = SearchPhase.searching;
      category = 'All';
    });
    if (page.hasClients) {
      page.jumpTo(0);
    }
    final evidenceById = <String, Evidence>{};
    final indexedSamples = <AnalyzedScreenshot>[];
    final corpus = _availableEvidence;
    for (final entry in corpus.asMap().entries) {
      final evidence = entry.value;
      final screenshotId = evidence.sourceScreenshotId ?? 'sample-${entry.key}';
      evidenceById[screenshotId] = evidence;
      indexedSamples.add(
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
    final answer = await ai.answer(input, indexedSamples);
    if (!mounted || ticket != request) return;
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
    final parsedQuery = ai.parseQuery(input);
    setState(() {
      matches = candidates;
      answerText = answer.text;
      phase = candidates.isNotEmpty ? SearchPhase.found : SearchPhase.uncertain;
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
    query.clear();
    setState(() {
      phase = SearchPhase.idle;
      category = 'All';
      matches = [];
      answerText = null;
    });
    if (page.hasClients) {
      page.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final browsing =
        phase == SearchPhase.idle || phase == SearchPhase.uncertain;
    final evidence = _availableEvidence;
    final visible = (browsing ? evidence : matches)
        .where((e) => category == 'All' || e.category == category)
        .toList();
    final title = switch (phase) {
      SearchPhase.idle => 'A little help finding\nwhat you saved.',
      SearchPhase.searching => 'Let me look in the box…',
      SearchPhase.found => 'Ta-da! Here’s what I found.',
      SearchPhase.uncertain => 'Let’s look together.',
    };
    final subtitle = switch (phase) {
      SearchPhase.idle => 'Ask about a receipt, order, or class announcement.',
      SearchPhase.searching =>
        'Checking sample and locally scanned photos for your request.',
      SearchPhase.found =>
        '${matches.length} matching ${matches.length == 1 ? 'screenshot' : 'screenshots'}. Open one to check the details.',
      SearchPhase.uncertain => 'I couldn’t find an exact match. Browse these samples or try a different detail.',
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 24),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Gallery Helpdesk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About this preview',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your gallery, made easier.',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Search uses the offline Dart helpdesk core with fictional examples and any photos you choose to scan. Gallery images are copied to private app storage for OCR and source viewing; nothing is uploaded. First-use airplane-mode behavior still needs testing on the target tablet. ObjectBox, language-model inference, and notifications are not connected.',
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
              if (isGalleryScanningSupported) ...[
                const SizedBox(height: 12),
                _galleryScanPanel(),
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
                    fontSize: 27,
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
              if (answerText != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEE6),
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
                      SelectableText(
                        answerText!,
                        style: const TextStyle(fontSize: 13, height: 1.45),
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
                  hintText: 'Find my GCash receipt for 500…',
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
              if (phase == SearchPhase.idle) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 4,
                  children: ['GCash 500', 'Headphones', 'Proposal deadline']
                      .map(
                        (s) => ActionChip(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE2DED6)),
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: () => search(s),
                        ),
                      )
                      .toList(),
                ),
              ] else
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phase == SearchPhase.uncertain
                            ? 'Browse possible screenshots'
                            : phase == SearchPhase.found
                            ? 'Found in your box'
                            : 'Inside your sample box',
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
                        ['All', 'Receipts', 'Orders', 'Announcements', 'Other']
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(s),
                                  selected: category == s,
                                  showCheckmark: false,
                                  selectedColor: const Color(0xFFDDE7E0),
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
                ...visible.map((e) => EvidenceCard(evidence: e)),
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

  Widget _galleryScanPanel() {
    final running = scanProgress.isScanning;
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
            'Scan photos on this device',
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
          if (running || scanProgress.total > 0) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: running ? scanProgress.fraction : 1),
          ],
          const SizedBox(height: 6),
          Text(
            scannerError ?? scanProgress.message,
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
              OutlinedButton.icon(
                onPressed: scannerReady && !running
                    ? scanProgress.status == 'interrupted'
                        ? _resumeInterruptedScan
                        : _scanGallery
                    : null,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  switch (scanProgress.status) {
                    'interrupted'
                        when scanProgress.pendingPickedPhotos.isNotEmpty =>
                      'Resume selected photos',
                    'interrupted' => 'Resume gallery scan',
                    _ => 'Scan permitted gallery',
                  },
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: scannerReady && !running ? _choosePhotos : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Choose photos'),
              ),
              if (scanner.failedCount > 0 &&
                  scanProgress.pendingPickedPhotos.isEmpty)
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
                child: Column(
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
                      evidence.category,
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
    rect(const Rect.fromLTWH(65, 49, 88, 58), const Color(0xFF7B9A8B), 18);
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
    rect(const Rect.fromLTWH(84, 108, 50, 32), const Color(0xFF7B9A8B), 12);
    line(
      const Offset(84, 115),
      Offset(56, searching ? 140 : 120),
      const Color(0xFF7B9A8B),
      9,
    );
    line(
      const Offset(134, 115),
      Offset(happy ? 169 : 160, happy ? 86 : 137),
      const Color(0xFF7B9A8B),
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
      line(
        const Offset(-9, 10),
        const Offset(10, 10),
        const Color(0xFF7B9A8B),
        2,
      );
      line(
        const Offset(-9, 16),
        const Offset(4, 16),
        const Color(0xFF7B9A8B),
        2,
      );
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
