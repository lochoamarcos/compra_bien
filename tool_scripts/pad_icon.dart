import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/app_icon_final.png');
  if (!file.existsSync()) {
    print('Source file assets/app_icon_final.png missing');
    exit(1);
  }

  final bytes = file.readAsBytesSync();
  final src = decodeImage(bytes);
  
  if (src == null) {
      print('Could not decode image');
      exit(1);
  }

  // Create a larger canvas (add 50% padding = scale logo down to ~66%)
  // Android safe zone is 66% diameter circle. So we need the content to fit there.
  // If we increase canvas to 150%, the original content becomes 1/1.5 = 66% of new size. Perfect.
  
  final newWidth = (src.width * 1.5).toInt();
  final newHeight = (src.height * 1.5).toInt();
  
  print('Original size: ${src.width}x${src.height}');
  print('New size: ${newWidth}x${newHeight}');
  
  // Create transparent image
  final dst = Image(width: newWidth, height: newHeight, numChannels: 4); 
  // Ensure transparent background (default is 0,0,0,0 usually but explicit clear helps?)
  // clear(dst, color: ColorRgba8(0,0,0,0)); // New API might differ
  
  // Copy src to center
  compositeImage(dst, src, dstX: (newWidth - src.width) ~/ 2, dstY: (newHeight - src.height) ~/ 2);
  
  // Resize back to original size? 
  // Android adaptive icons are usually 108x108dp (432x432px xxxhdpi). 
  // flutter_launcher_icons handles resizing.
  // We just provide a padded source image. Keeping it high res is good.
  
  File('assets/app_icon_padded.png').writeAsBytesSync(encodePng(dst));
  print('Created assets/app_icon_padded.png');
}
