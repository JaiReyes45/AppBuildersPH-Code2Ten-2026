part of 'main.dart';

extension _BoxLibrary on _HomeScreenState {
  Widget _boxFolders(List<Evidence> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Explore your box',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Your scanned images, neatly collected. Tap a folder to explore.',
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5
              ? 1
              : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final name in ['All', 'Receipts', 'Orders', 'Announcements'])
                SizedBox(
                  width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                  child: _folderTile(
                    name,
                    items
                        .where((e) => name == 'All' || e.category == name)
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _folderTile(String name, List<Evidence> items) => Material(
    color: name == 'All' ? lavender : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      key: ValueKey('folder-$name'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _BoxFolderScreen(name: name, items: items),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.folder_rounded, color: violet, size: 38),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${items.length} images',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _frequentSearches() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Most Frequently Searched',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (_searchCounts.counts.isEmpty)
        const Text(
          'Your repeated searches will appear here. Search for something to get started.',
        ),
      for (final entry in _searchCounts.top())
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.manage_search, color: violet),
          title: Text(entry.key, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${entry.value} ${entry.value == 1 ? "search" : "searches"}',
          ),
          trailing: const Icon(Icons.arrow_forward_rounded, color: violet),
          onTap: () {
            query.text = entry.key;
            handleSearch(entry.key);
          },
        ),
      if (_historyError != null)
        Text(_historyError!, style: const TextStyle(color: Colors.red)),
      if (_searchCounts.counts.isNotEmpty)
        TextButton(
          onPressed: () {
            _clearFrequentSearches();
          },
          child: const Text('Clear frequent searches'),
        ),
    ],
  );
}

class _BoxFolderScreen extends StatelessWidget {
  const _BoxFolderScreen({required this.name, required this.items});
  final String name;
  final List<Evidence> items;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$name (${items.length})')),
    body: SafeArea(
      child: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This folder is empty. Search or scan your gallery to add images.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      constraints.maxWidth < 330 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? 1
                      : constraints.maxWidth > 650
                      ? 3
                      : 2,
                  mainAxisExtent: 250,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScreen(evidence: item),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: item.sourceImagePath != null
                                ? evidenceImage(item.sourceImagePath!)
                                : ColoredBox(
                                    color: lavender,
                                    child: Icon(
                                      item.icon,
                                      color: violet,
                                      size: 42,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.isGallerySource
                                      ? item.category
                                      : 'Demo content',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}
