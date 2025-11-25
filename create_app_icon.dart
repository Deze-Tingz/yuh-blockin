import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('Creating optimized app icon...');

  // Load the logo.PNG which has multiple variants
  final logoFile = File('assets/images/logo.PNG');
  if (!logoFile.existsSync()) {
    print('ERROR: assets/images/logo.PNG not found');
    exit(1);
  }

  final logoBytes = logoFile.readAsBytesSync();
  final logo = img.decodeImage(logoBytes);

  if (logo == null) {
    print('ERROR: Could not decode logo.PNG');
    exit(1);
  }

  print('Logo size: ${logo.width}x${logo.height}');

  // The top-right icon (two cars in rounded square) location
  // Tight crop to just the icon element
  final int iconLeft = (logo.width * 0.545).round();
  final int iconTop = (logo.height * 0.045).round();
  final int iconWidth = (logo.width * 0.38).round();
  final int iconHeight = (logo.height * 0.175).round();

  // Crop the icon region tightly
  final croppedIcon = img.copyCrop(
    logo,
    x: iconLeft,
    y: iconTop,
    width: iconWidth,
    height: iconHeight,
  );

  // Create a square canvas - icon fills entire space
  final int outputSize = 1024;

  // Create white background
  final output = img.Image(width: outputSize, height: outputSize);
  img.fill(output, color: img.ColorRgb8(255, 255, 255));

  // Stretch icon to fill the entire canvas (100%)
  final resized = img.copyResize(
    croppedIcon,
    width: outputSize,
    height: outputSize,
    interpolation: img.Interpolation.cubic,
  );

  // Place at origin (0,0) - fills entire canvas
  img.compositeImage(output, resized, dstX: 0, dstY: 0);

  // Save the app icon
  final outputFile = File('assets/images/app_icon.png');
  outputFile.writeAsBytesSync(img.encodePng(output));

  print('Created: assets/images/app_icon.png (${outputSize}x${outputSize})');
  print('');
  print('Now run: flutter pub run flutter_launcher_icons');
}
