import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Load the original icon
  final originalFile = File('assets/images/app_icon.png');
  final originalImage = img.decodeImage(originalFile.readAsBytesSync())!;

  // Create a new 1024x1024 canvas with white background
  final paddedImage = img.Image(width: 1024, height: 1024);
  img.fill(paddedImage, color: img.ColorRgba8(255, 255, 255, 255));

  // Calculate padding (20% on each side = 60% icon size)
  // This creates a smaller icon within the adaptive icon safe zone
  final padding = (1024 * 0.18).round(); // 18% padding on each side
  final newSize = 1024 - (padding * 2);

  // Resize the original icon to fit within the padded area
  final resizedIcon = img.copyResize(originalImage, width: newSize, height: newSize);

  // Composite the resized icon onto the center of the padded canvas
  img.compositeImage(paddedImage, resizedIcon, dstX: padding, dstY: padding);

  // Save the padded foreground
  final outputFile = File('assets/images/app_icon_foreground.png');
  outputFile.writeAsBytesSync(img.encodePng(paddedImage));

  print('Created padded foreground icon: assets/images/app_icon_foreground.png');
  print('Original size: ${originalImage.width}x${originalImage.height}');
  print('Icon area: ${newSize}x${newSize} with ${padding}px padding');
}
