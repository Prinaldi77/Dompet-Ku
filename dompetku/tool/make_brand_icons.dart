// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

const _source = 'assets/branding/dompetku-logo.png';
const _outDir = 'assets/branding';

void main() {
  final logo = img.decodeImage(File(_source).readAsBytesSync())!;

  // Wordmark starts around y=636; the wallet mark sits above it.
  final mark = _cropMark(logo);
  _removeOuterWhite(mark);
  final trimmed = _trimTransparent(mark);
  _save(trimmed, '$_outDir/dompetku-mark.png');

  final word = _cropWordmark(logo);
  _removeAllWhite(word);
  final wordTrim = _trimTransparent(word);
  _saveLockups(trimmed, wordTrim, dark: false);

  final darkMark = trimmed.clone();
  final darkWord = wordTrim.clone();
  _recolorNavy(darkMark);
  _recolorNavy(darkWord);
  _saveLockups(darkMark, darkWord, dark: true);

  _composeIcon(trimmed, '$_outDir/app_icon.png', background: _mint);
  _composeIcon(
    trimmed,
    '$_outDir/app_icon_foreground.png',
    background: null,
    widthFactor: 0.55,
  );
  _composeMonochrome(trimmed, '$_outDir/app_icon_monochrome.png');

  final splashDir = Directory('android/app/src/main/res/drawable-nodpi')
    ..createSync(recursive: true);
  final splash = img.copyResize(
    trimmed,
    width: 420,
    interpolation: img.Interpolation.cubic,
  );
  _save(splash, '${splashDir.path}/splash_logo.png');

  print('mark ${trimmed.width}x${trimmed.height}');
  print('wrote app_icon.png, app_icon_foreground.png, app_icon_monochrome.png');
  print('wrote lockup horizontal/vertical light+dark');
}

img.Image _cropWordmark(img.Image logo) {
  final startY = (logo.height * 0.6).round();
  var minX = logo.width, minY = logo.height, maxX = -1, maxY = -1;
  for (var y = startY; y < logo.height; y++) {
    for (var x = 0; x < logo.width; x++) {
      final p = logo.getPixel(x, y);
      final min = [p.r, p.g, p.b].reduce((a, b) => a < b ? a : b);
      if (255 - min > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  const pad = 4;
  minX = (minX - pad).clamp(0, logo.width - 1);
  minY = (minY - pad).clamp(0, logo.height - 1);
  maxX = (maxX + pad).clamp(0, logo.width - 1);
  maxY = (maxY + pad).clamp(0, logo.height - 1);
  return img.copyCrop(
    logo,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  ).convert(numChannels: 4);
}

/// Wordmark counters (holes in o/p/e) must also be transparent, so every
/// near-white pixel is cleared instead of only border-connected ones.
void _removeAllWhite(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final white = p.r >= 236 && p.g >= 236 && p.b >= 236;
      image.setPixelRgba(x, y, p.r, p.g, p.b, white ? 0 : 255);
    }
  }
}

/// Swaps navy ink for a near-white tone so the lockup stays legible on dark
/// surfaces; the green accent is left untouched.
void _recolorNavy(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final navy = p.a > 0 &&
          p.b >= p.g &&
          p.g >= p.r &&
          (p.b - p.r) > 14 &&
          p.b < 242;
      if (navy) {
        image.setPixelRgba(x, y, 245, 248, 251, p.a);
      }
    }
  }
}

void _saveLockups(img.Image mark, img.Image word, {required bool dark}) {
  final suffix = dark ? 'dark' : 'light';
  _composeHorizontal(mark, word, '$_outDir/lockup_horizontal_$suffix.png');
  _composeVertical(mark, word, '$_outDir/lockup_vertical_$suffix.png');
}

void _composeHorizontal(img.Image mark, img.Image word, String path) {
  const height = 160;
  const markHeight = 158;
  const wordHeight = 86;
  const gap = 34;

  final markW = (mark.width * markHeight / mark.height).round();
  final wordW = (word.width * wordHeight / word.height).round();
  final markScaled = img.copyResize(
    mark,
    width: markW,
    height: markHeight,
    interpolation: img.Interpolation.cubic,
  );
  final wordScaled = img.copyResize(
    word,
    width: wordW,
    height: wordHeight,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(
    width: markW + gap + wordW,
    height: height,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    canvas,
    markScaled,
    dstX: 0,
    dstY: (height - markHeight) ~/ 2,
  );
  img.compositeImage(
    canvas,
    wordScaled,
    dstX: markW + gap,
    dstY: (height - wordHeight) ~/ 2,
  );
  _save(canvas, path);
}

void _composeVertical(img.Image mark, img.Image word, String path) {
  const markWidth = 540;
  const wordWidth = 590;
  const gap = 24;
  const margin = 24;

  final markH = (mark.height * markWidth / mark.width).round();
  final wordH = (word.height * wordWidth / word.width).round();
  final markScaled = img.copyResize(
    mark,
    width: markWidth,
    height: markH,
    interpolation: img.Interpolation.cubic,
  );
  final wordScaled = img.copyResize(
    word,
    width: wordWidth,
    height: wordH,
    interpolation: img.Interpolation.cubic,
  );

  final width = (wordWidth > markWidth ? wordWidth : markWidth) + margin * 2;
  final canvas = img.Image(
    width: width,
    height: markH + gap + wordH,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    canvas,
    markScaled,
    dstX: (width - markWidth) ~/ 2,
    dstY: 0,
  );
  img.compositeImage(
    canvas,
    wordScaled,
    dstX: (width - wordWidth) ~/ 2,
    dstY: markH + gap,
  );
  _save(canvas, path);
}

const _mint = (r: 234, g: 246, b: 241);

img.Image _cropMark(img.Image logo) {
  var minX = logo.width, minY = logo.height, maxX = -1, maxY = -1;
  final limitY = (logo.height * 0.6).round();
  for (var y = 0; y < limitY; y++) {
    for (var x = 0; x < logo.width; x++) {
      final p = logo.getPixel(x, y);
      final min = [p.r, p.g, p.b].reduce((a, b) => a < b ? a : b);
      if (255 - min > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  const pad = 6;
  minX = (minX - pad).clamp(0, logo.width - 1);
  minY = (minY - pad).clamp(0, logo.height - 1);
  maxX = (maxX + pad).clamp(0, logo.width - 1);
  maxY = (maxY + pad).clamp(0, logo.height - 1);
  return img.copyCrop(
    logo,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  ).convert(numChannels: 4);
}

/// Makes white background pixels reachable from the border transparent while
/// keeping enclosed white highlights (wallet swoosh and buckle) intact.
void _removeOuterWhite(img.Image image) {
  final w = image.width;
  final h = image.height;
  final visited = List<bool>.filled(w * h, false);
  final queue = <int>[];

  bool isBackground(int x, int y) {
    final p = image.getPixel(x, y);
    return p.r >= 242 && p.g >= 242 && p.b >= 242;
  }

  void seed(int x, int y) {
    final i = y * w + x;
    if (visited[i] || !isBackground(x, y)) return;
    visited[i] = true;
    queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  for (var head = 0; head < queue.length; head++) {
    final i = queue[head];
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) seed(x - 1, y);
    if (x < w - 1) seed(x + 1, y);
    if (y > 0) seed(x, y - 1);
    if (y < h - 1) seed(x, y + 1);
  }

  for (final i in queue) {
    final p = image.getPixel(i % w, i ~/ w);
    image.setPixelRgba(i % w, i ~/ w, p.r, p.g, p.b, 0);
  }
}

img.Image _trimTransparent(img.Image image) {
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

void _composeIcon(
  img.Image mark,
  String path, {
  required ({int r, int g, int b})? background,
  double widthFactor = 0.66,
}) {
  const size = 1024;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  if (background == null) {
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  } else {
    img.fill(
      canvas,
      color: img.ColorRgba8(background.r, background.g, background.b, 255),
    );
  }
  final targetW = (size * widthFactor).round();
  final targetH = (targetW * mark.height / mark.width).round();
  final scaled = img.copyResize(
    mark,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    scaled,
    dstX: (size - targetW) ~/ 2,
    dstY: (size - targetH) ~/ 2,
  );
  _save(canvas, path);
}

void _composeMonochrome(img.Image mark, String path) {
  const size = 1024;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  const targetW = 580;
  final targetH = (targetW * mark.height / mark.width).round();
  final scaled = img.copyResize(
    mark,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );
  final offsetX = (size - targetW) ~/ 2;
  final offsetY = (size - targetH) ~/ 2;
  for (var y = 0; y < targetH; y++) {
    for (var x = 0; x < targetW; x++) {
      final a = scaled.getPixel(x, y).a;
      if (a > 0) {
        canvas.setPixelRgba(offsetX + x, offsetY + y, 255, 255, 255, a);
      }
    }
  }
  _save(canvas, path);
}

void _save(img.Image image, String path) {
  File(path).writeAsBytesSync(img.encodePng(image));
}
