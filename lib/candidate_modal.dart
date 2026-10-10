import 'package:flutter/material.dart';

import 'evidence_image.dart';
import 'gallery_scanner.dart';

class CandidateModal extends StatelessWidget {
  const CandidateModal({
    super.key,
    required this.candidate,
    required this.onStopAsking,
  });

  final GalleryCandidate candidate;
  final VoidCallback onStopAsking;

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Text("Is this what you're looking for?"),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * .28).clamp(
                120.0,
                220.0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: candidate.imagePath == null
                    ? const Center(child: Icon(Icons.image_outlined, size: 56))
                    : evidenceImage(candidate.imagePath!),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              candidate.displayName.trim().isEmpty
                  ? 'Screenshot'
                  : candidate.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(CandidateAction.accept),
                  icon: const Icon(Icons.check),
                  label: const Text("Yes, that's it"),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(CandidateAction.reject),
                  icon: const Icon(Icons.close),
                  label: const Text('No, keep looking'),
                ),
                TextButton.icon(
                  onPressed: onStopAsking,
                  icon: const Icon(Icons.pause),
                  label: const Text('Stop asking for this query'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
