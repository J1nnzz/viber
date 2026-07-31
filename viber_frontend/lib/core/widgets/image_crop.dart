import 'package:easy_localization/easy_localization.dart';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';

/// Imagen ya recortada por el usuario, lista para subir.
class CroppedImage {
  final Uint8List bytes;
  final String name;
  const CroppedImage(this.bytes, this.name);
}

/// Abre el selector de archivos, deja al usuario recortar la imagen elegida y
/// devuelve los bytes recortados junto al nombre original.
///
/// Devuelve `null` si el usuario cancela en cualquiera de los dos pasos.
///
///  - [aspectRatio]: relación de aspecto fija del recorte (ej. 16/9 para
///    portadas). `null` = recorte libre.
///  - [circle]: muestra una guía circular y fija la relación a 1:1 (avatares).
Future<CroppedImage?> pickAndCropImage(
  BuildContext context, {
  double? aspectRatio,
  bool circle = false,
  String title = 'Ajustar imagen',
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  if (file.bytes == null) return null;
  if (!context.mounted) return null;

  final cropped = await Navigator.push<Uint8List>(
    context,
    fadeThroughRoute<Uint8List>(
      ImageCropperScreen(
        imageBytes: file.bytes!,
        aspectRatio: aspectRatio,
        circle: circle,
        title: title,
      ),
    ),
  );
  if (cropped == null) return null;

  return CroppedImage(cropped, file.name);
}

/// Pantalla a pantalla completa para recortar una imagen.
///
/// Recibe los bytes originales y, al pulsar "Listo", devuelve los bytes
/// recortados mediante `Navigator.pop`. Cancelar devuelve `null`.
class ImageCropperScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double? aspectRatio;
  final bool circle;
  final String title;

  const ImageCropperScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
    this.circle = false,
    this.title = 'Ajustar imagen',
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.pop(context, croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.crop_error'.tr())),
        );
    }
  }

  void _confirm() {
    setState(() => _cropping = true);
    // withCircleUi muestra una guía circular pero crop() recorta el cuadrado
    // que la contiene (sin transparencias), ideal para avatares en CircleAvatar.
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'common.cancel'.tr(),
          onPressed: _cropping ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (_cropping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: appAccent),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _confirm,
              child: Text(
                'common.done'.tr(),
                style: TextStyle(
                  color: appAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        onCropped: _onCropped,
        aspectRatio: widget.circle ? 1 : widget.aspectRatio,
        withCircleUi: widget.circle,
        baseColor: Colors.black,
        maskColor: Colors.black.withValues(alpha: 0.55),
        radius: widget.circle ? 0 : 8,
        cornerDotBuilder: (size, edgeAlignment) =>
            const DotControl(color: appAccent),
      ),
    );
  }
}
