enum DesignDirection { umbral, materia, mineral }

extension DesignDirectionLabel on DesignDirection {
  String get label => switch (this) {
    DesignDirection.umbral => 'Umbral nocturno',
    DesignDirection.materia => 'Materia quieta',
    DesignDirection.mineral => 'Silencio mineral',
  };

  String get shortLabel => switch (this) {
    DesignDirection.umbral => 'Umbral',
    DesignDirection.materia => 'Materia',
    DesignDirection.mineral => 'Mineral',
  };
}
