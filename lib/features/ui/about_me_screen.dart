import 'package:flutter/material.dart';

// Texto provisional. Sustituir por el texto definitivo editando estas
// constantes.
const _aboutTitle = 'Quien Soy';
const _aboutBody = '''
Acompaño desde hace años a personas que buscan un espacio propio de escucha, calma y conexión.

Este portal reúne mis canalizaciones, meditaciones y prácticas, grabadas con el mismo cuidado con el que me gustaría recibirlas.

Gracias por estar aquí.''';

/// Presentación de la autora dentro del perfil.
class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: [
          Text(_aboutBody, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
