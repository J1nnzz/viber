import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Comprueba la integridad de las traducciones sin arrancar la app.
///
/// El fallo que motivó este test: una clave puede invocarse desde el código y
/// no existir en los JSON. easy_localization no avisa — pinta el identificador
/// crudo en pantalla ("youtube.add_n_songs"), así que solo se detecta mirando
/// esa pantalla concreta en la app. Comparar es.json con en.json no lo pilla,
/// porque la clave falta en los dos a la vez.

/// Aplana {"a": {"b": "x"}} a {"a.b": "x"}. Los diccionarios de plural
/// (one/other/...) se tratan como hoja, no como rama.
Map<String, Object> _flatten(Map<String, dynamic> node, [String prefix = '']) {
  const formasPlural = {'zero', 'one', 'two', 'few', 'many', 'other'};
  final out = <String, Object>{};
  node.forEach((k, v) {
    final key = prefix.isEmpty ? k : '$prefix.$k';
    if (v is Map<String, dynamic>) {
      if (v.keys.any(formasPlural.contains)) {
        out[key] = v;
      } else {
        out.addAll(_flatten(v, key));
      }
    } else {
      out[key] = v as Object;
    }
  });
  return out;
}

Map<String, Object> _load(String locale) {
  final file = File('assets/translations/$locale.json');
  return _flatten(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

void main() {
  final es = _load('es');
  final en = _load('en');

  // 'alguna.clave'.tr(  |  'alguna.clave'.plural(
  final referencia = RegExp(
      r"'([a-z][a-zA-Z_0-9]*(?:\.[a-zA-Z_0-9]+)+)'\s*\.\s*(tr|plural)\s*\(");

  final usos = <String, String>{}; // clave -> primer sitio donde aparece
  final llamadasPlural = <String>{};

  setUpAll(() {
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in referencia.allMatches(f.readAsStringSync())) {
        final clave = m.group(1)!;
        usos.putIfAbsent(clave, () => f.path);
        if (m.group(2) == 'plural') llamadasPlural.add(clave);
      }
    }
  });

  test('los dos idiomas definen exactamente las mismas claves', () {
    expect(es.keys.toSet().difference(en.keys.toSet()), isEmpty,
        reason: 'claves que están en es.json pero no en en.json');
    expect(en.keys.toSet().difference(es.keys.toSet()), isEmpty,
        reason: 'claves que están en en.json pero no en es.json');
  });

  test('toda clave usada en el código existe en ambos idiomas', () {
    final faltan = usos.entries
        .where((e) => !es.containsKey(e.key) || !en.containsKey(e.key))
        .map((e) => '${e.key}  (${e.value})')
        .toList()
      ..sort();

    expect(faltan, isEmpty,
        reason: 'Estas claves se invocan pero no están traducidas. '
            'En pantalla se vería el identificador en crudo:\n'
            '${faltan.join('\n')}');
  });

  test('.plural() se usa solo sobre claves con formas plurales', () {
    final malUsadas = llamadasPlural
        .where((k) => es.containsKey(k) && es[k] is! Map)
        .toList()
      ..sort();

    expect(malUsadas, isEmpty,
        reason: '.plural() sobre una clave que es un texto plano: '
            '${malUsadas.join(', ')}');
  });

  test('ninguna traducción queda vacía', () {
    for (final mapa in {'es': es, 'en': en}.entries) {
      final vacias = mapa.value.entries
          .where((e) => e.value is String && (e.value as String).trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(vacias, isEmpty, reason: 'claves vacías en ${mapa.key}.json');
    }
  });
}
