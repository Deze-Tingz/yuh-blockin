import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // Load the cropped splash logo
  final file = File('assets/images/splash_logo.png');
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Failed to load image');
    return;
  }

  print('Original image size: ${image.width}x${image.height}');

  // Find the bounding box of non-white content
  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;

  // Threshold for "white" - pixels close to white will be made transparent
  const whiteThreshold = 245;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Check if pixel is NOT white/near-white
      if (r < whiteThreshold || g < whiteThreshold || b < whiteThreshold) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Content bounds: ($minX, $minY) to ($maxX, $maxY)');

  // Add small padding
  const padding = 10;
  minX = (minX - padding).clamp(0, image.width - 1);
  minY = (minY - padding).clamp(0, image.height - 1);
  maxX = (maxX + padding).clamp(0, image.width - 1);
  maxY = (maxY + padding).clamp(0, image.height - 1);

  // Crop to content
  final cropped = img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  print('Cropped size: ${cropped.width}x${cropped.height}');

  // Create a new image with transparency
  final transparent = img.Image(
    width: cropped.width,
    height: cropped.height,
    numChannels: 4,
  );

  // Copy pixels, making white/near-white pixels transparent
  for (int y = 0; y < cropped.height; y++) {
    for (int x = 0; x < cropped.width; x++) {
      final pixel = cropped.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // If pixel is white or near-white, make it transparent
      if (r >= whiteThreshold && g >= whiteThreshold && b >= whiteThreshold) {
        transparent.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        transparent.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  // Save the processed image
  final outputFile = File('assets/images/logo_transparent.png');
  await outputFile.writeAsBytes(img.encodePng(transparent));

  print('Saved transparent logo to: ${outputFile.path}');
  print('Final size: ${transparent.width}x${transparent.height}');
}
