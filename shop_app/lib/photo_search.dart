import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

/// Abre a câmera ou a galeria e devolve o caminho da foto escolhida,
/// ou `null` se o visitante cancelar.
typedef PhotoPicker = Future<String?> Function(ImageSource source);

/// Devolve o que foi reconhecido na foto, do mais provável ao menos provável.
typedef PhotoLabeler = Future<List<String>> Function(String path);

/// Os testes trocam estas funções por versões falsas.
PhotoPicker pickPhoto = _pickWithImagePicker;
PhotoLabeler labelPhoto = _labelWithMlKit;

Future<String?> _pickWithImagePicker(ImageSource source) async {
  final photo = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    imageQuality: 85,
  );

  return photo?.path;
}

/// Reconhecimento feito no próprio celular (Google ML Kit), sem enviar a
/// foto para a internet. Os rótulos vêm em inglês, por exemplo "Sneakers".
Future<List<String>> _labelWithMlKit(String path) async {
  final labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.55),
  );

  try {
    final labels = await labeler.processImage(InputImage.fromFilePath(path));
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));

    return labels.take(6).map((label) => label.label).toList();
  } finally {
    await labeler.close();
  }
}
