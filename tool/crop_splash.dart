import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // Load the original image
  final file = File('assets/images/logo.PNG');
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Failed to load image');
    return;
  }

  print('Original image size: ${image.width}x${image.height}');

  // The top-left logo is in the first quadrant
  // Crop approximately the top-left quarter of the image
  final cropWidth = image.width ~/ 2;
  final cropHeight = image.height ~/ 2;

  final cropped = img.copyCrop(
    image,
    x: 0,
    y: 0,
    width: cropWidth,
    height: cropHeight,
  );

  print('Cropped image size: ${cropped.width}x${cropped.height}');

  // Save the cropped image
  final outputFile = File('assets/images/splash_logo.png');
  await outputFile.writeAsBytes(img.encodePng(cropped));

  print('Saved cropped splash logo to: ${outputFile.path}');
}
