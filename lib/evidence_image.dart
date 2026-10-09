import 'package:flutter/widgets.dart';

import 'evidence_image_stub.dart'
    if (dart.library.io) 'evidence_image_io.dart' as platform;

Widget evidenceImage(String imagePath) => platform.evidenceImage(imagePath);
