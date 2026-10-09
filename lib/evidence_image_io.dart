import 'dart:io';

import 'package:flutter/material.dart';

Widget evidenceImage(String imagePath) => ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Image.file(
    File(imagePath),
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const SizedBox(
      height: 180,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.black38),
      ),
    ),
  ),
);
