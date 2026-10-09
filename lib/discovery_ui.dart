part of 'main.dart';

/// Decorative welcome only: the child initializes its real local index in parallel.
/// Never represents gallery scan progress or asks for photo permission.
class StartupReveal extends StatefulWidget {
  final Widget child;
  const StartupReveal({super.key, required this.child});
  @override
  State<StartupReveal> createState() => _StartupRevealState();
}

class _StartupRevealState extends State<StartupReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Timer? timer;
  bool showing = true;
  late final List<int> photos = ([0, 1, 2, 3]..shuffle(math.Random()));
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 2200), finish);
  }

  void finish() {
    if (!mounted || !showing) return;
    timer?.cancel();
    motion.stop();
    setState(() => showing = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
    } else if (showing) {
      motion.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Offstage(
        offstage: showing,
        child: TickerMode(enabled: !showing, child: widget.child),
      ),
      if (showing)
        Scaffold(
          backgroundColor: paper,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 18, 30, 24),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: finish,
                            child: const Text('Skip intro'),
                          ),
                        ),
                        Semantics(
                          label: 'Decorative photos with a searching magnifying glass',
                          image: true,
                          child: ExcludeSemantics(
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1,
                              child: SizedBox(
                                height: 430,
                                child: AnimatedBuilder(
                                  animation: motion,
                                  builder: (context, _) => Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: 12,
                                        left: 5,
                                        child: _MemoryPhoto(
                                          index: photos[0],
                                          angle: -.13,
                                        ),
                                      ),
                                      Positioned(
                                        top: 53,
                                        right: 0,
                                        child: _MemoryPhoto(
                                          index: photos[1],
                                          angle: .12,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 0,
                                        child: _MemoryPhoto(
                                          index: photos[2],
                                          angle: .1,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 23,
                                        right: 2,
                                        child: _MemoryPhoto(
                                          index: photos[3],
                                          angle: -.12,
                                        ),
                                      ),
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'SSeeker',
                                              style: editorial.copyWith(
                                                fontSize: 66,
                                                color: violet,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Bawat sandali, may balikan.',
                                              style: TextStyle(
                                                color: ink,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 35 + motion.value * 280,
                                        left:
                                            65 +
                                            math.sin(
                                                  motion.value * math.pi * 2,
                                                ) *
                                                55,
                                        child: Container(
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: lavender.withValues(
                                              alpha: .92,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: violet.withValues(
                                                  alpha: .15,
                                                ),
                                                blurRadius: 16,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.search_rounded,
                                            color: violet,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'A little magic. A lot easier to find.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: violet),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Opening your screenshot helpdesk...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _MemoryPhoto extends StatelessWidget {
  final int index;
  final double angle;
  const _MemoryPhoto({required this.index, required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 108,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 104,
            child: ClipRect(
              child: OverflowBox(
                alignment: [
                  Alignment.topLeft,
                  Alignment.topRight,
                  Alignment.bottomLeft,
                  Alignment.bottomRight,
                ][index],
                maxWidth: 192,
                maxHeight: 208,
                child: Image.asset(
                  'assets/images/welcome_memories.png',
                  width: 192,
                  height: 208,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: lavender,
                    child: SizedBox(
                      width: 192,
                      height: 208,
                      child: Icon(Icons.landscape_outlined, color: violet),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            [
              'a little escape',
              'small joys',
              'slow mornings',
              'little moments',
            ][index],
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
