import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;
part 'home.dart';

void main() => runApp(const GalleryHelpdeskApp());
const ink = Color(0xFF303B54);
const paper = Color(0xFFF7F5F0);

class GalleryHelpdeskApp extends StatelessWidget {
  final String? fontFamily;
  const GalleryHelpdeskApp({super.key, this.fontFamily});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gallery Helpdesk',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: fontFamily,
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
      ),
    ),
    home: const HomeScreen(),
  );
}

class Evidence {
  final String title, category, date, summary, field, value, source;
  final IconData icon;
  const Evidence(
    this.title,
    this.category,
    this.date,
    this.summary,
    this.field,
    this.value,
    this.source,
    this.icon,
  );
}

const samples = [
  Evidence(
    'GCash · Project contribution',
    'Receipts',
    'Oct 9, 2026',
    'PHP 500.00 sent to Alex D.',
    'Reference number',
    'DEMO-8472-0196',
    'GCash\nMoney sent\n\nAlex D.\nPHP 500.00\n\nOctober 9, 2026 · 9:42 AM\nReference No. DEMO-8472-0196',
    Icons.receipt_long_outlined,
  ),
  Evidence(
    'Wireless headphones',
    'Orders',
    'Oct 8, 2026',
    'Order confirmation · PHP 1,290.00',
    'Order number',
    'DEMO-ORDER-1028',
    'Order confirmation\n\nWireless headphones\nQuantity: 1\nTotal: PHP 1,290.00\n\nOrder No. DEMO-ORDER-1028\nOctober 8, 2026',
    Icons.shopping_bag_outlined,
  ),
  Evidence(
    'Research proposal submission',
    'Announcements',
    'Oct 9, 2026',
    'Submit your proposal by October 12 at 5 PM.',
    'Deadline',
    'Oct 12, 2026 · 5:00 PM',
    'CLASS ANNOUNCEMENT\nResearch Methods\n\nPlease submit your research proposal by October 12, 2026 at 5:00 PM.\n\nInclude your title, objectives, and methodology.\nSubmit through the class portal.',
    Icons.school_outlined,
  ),
  Evidence(
    'GCash · Lunch payment',
    'Receipts',
    'Oct 8, 2026',
    'PHP 180.00 sent to Jamie R.',
    'Reference number',
    'DEMO-6301-5528',
    'GCash\nMoney sent\n\nJamie R.\nPHP 180.00\n\nOctober 8, 2026 · 12:15 PM\nReference No. DEMO-6301-5528',
    Icons.receipt_long_outlined,
  ),
];

class DetailScreen extends StatelessWidget {
  final Evidence evidence;
  const DetailScreen({super.key, required this.evidence});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Source details')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              evidence.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text('${evidence.category} · Fictional demo content'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEE6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(evidence.field),
                  const SizedBox(height: 8),
                  SelectableText(
                    evidence.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy detail'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: evidence.value),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sample detail copied')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Source preview',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Recreated sample, not an image from your gallery.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE1E5DD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText.rich(
                TextSpan(
                  style: const TextStyle(color: ink, fontSize: 16, height: 1.8),
                  children: evidence.source
                      .split('\n')
                      .map(
                        (line) => TextSpan(
                          text: '$line\n',
                          style:
                              line.contains(evidence.value) ||
                                  (evidence.category == 'Announcements' &&
                                      line.contains('October 12'))
                              ? const TextStyle(
                                  backgroundColor: Color(0xFFFFEDAC),
                                  fontWeight: FontWeight.w700,
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (evidence.category == 'Announcements')
              FilledButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: const Text('Preview reminder'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Confirm the deadline'),
                    content: const Text(
                      'October 12, 2026 at 5:00 PM\n\nThe finished app will let you edit this date. This preview does not save or send notifications.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Close preview'),
                      ),
                    ],
                  ),
                ),
              ),
            if (evidence.category == 'Receipts')
              const Text(
                'A screenshot does not verify that a payment is authentic.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
          ],
        ),
      ),
    ),
  );
}
