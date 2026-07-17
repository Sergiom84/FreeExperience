import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms, wellbeing }

extension LegalDocumentCopy on LegalDocument {
  String get title => switch (this) {
    LegalDocument.privacy => 'Privacidad',
    LegalDocument.terms => 'Términos',
    LegalDocument.wellbeing => 'Bienestar',
  };

  List<String> get paragraphs => switch (this) {
    LegalDocument.privacy => const [
      'SoulKey conserva el progreso, los favoritos y las descargas necesarios para prestar el servicio.',
      'Los diagnósticos técnicos excluyen grabaciones de sesión y datos personales por defecto.',
      'La eliminación de cuenta borra los datos asociados en remoto y en el dispositivo.',
    ],
    LegalDocument.terms => const [
      'El contenido se ofrece para uso personal y no puede redistribuirse sin autorización.',
      'Las recomendaciones externas pertenecen a sus respectivos autores y servicios.',
      'El acceso a la beta puede cambiar mientras el producto se encuentra en validación.',
    ],
    LegalDocument.wellbeing => const [
      'Las prácticas y meditaciones no sustituyen atención médica, psicológica ni profesional.',
      'Detén la reproducción si una práctica provoca malestar y busca apoyo profesional cuando sea necesario.',
      'No uses sesiones que requieran atención sostenida mientras conduces o manejas maquinaria.',
    ],
  };

  static LegalDocument parse(String value) => switch (value) {
    'terms' => LegalDocument.terms,
    'wellbeing' => LegalDocument.wellbeing,
    _ => LegalDocument.privacy,
  };
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
        itemCount: document.paragraphs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 22),
        itemBuilder: (context, index) => Text(
          document.paragraphs[index],
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
