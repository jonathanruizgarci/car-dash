/// Descripciones en español de códigos de falla OBD2 comunes.
const Map<String, String> kDtcText = {
  'P0010': 'Circuito del actuador de posición del árbol de levas (banco 1)',
  'P0011': 'Tiempo del árbol de levas demasiado adelantado (banco 1)',
  'P0016': 'Correlación cigüeñal / árbol de levas (banco 1)',
  'P0030': 'Circuito del calentador del sensor de oxígeno B1S1',
  'P0100': 'Circuito del sensor de flujo de aire (MAF)',
  'P0101': 'Sensor MAF fuera de rango / desempeño (suele estar sucio)',
  'P0102': 'Sensor MAF: señal baja',
  'P0103': 'Sensor MAF: señal alta',
  'P0105': 'Circuito del sensor de presión absoluta (MAP)',
  'P0106': 'Sensor MAP fuera de rango',
  'P0110': 'Circuito del sensor de temperatura del aire de admisión',
  'P0113': 'Sensor de temperatura de aire de admisión: señal alta',
  'P0115': 'Circuito del sensor de temperatura del motor',
  'P0116': 'Sensor de temperatura del motor fuera de rango',
  'P0117': 'Sensor de temperatura del motor: señal baja',
  'P0118': 'Sensor de temperatura del motor: señal alta',
  'P0120': 'Circuito del sensor de posición del acelerador (TPS)',
  'P0121': 'Sensor TPS fuera de rango / desempeño',
  'P0122': 'Sensor TPS: señal baja',
  'P0123': 'Sensor TPS: señal alta',
  'P0125': 'El motor tarda demasiado en calentar (posible termostato)',
  'P0128': 'Termostato: temperatura del motor por debajo de lo normal',
  'P0130': 'Sensor de oxígeno B1S1: circuito',
  'P0131': 'Sensor de oxígeno B1S1: voltaje bajo',
  'P0132': 'Sensor de oxígeno B1S1: voltaje alto',
  'P0133': 'Sensor de oxígeno B1S1: respuesta lenta',
  'P0134': 'Sensor de oxígeno B1S1: sin actividad',
  'P0135': 'Calentador del sensor de oxígeno B1S1',
  'P0136': 'Sensor de oxígeno B1S2: circuito',
  'P0137': 'Sensor de oxígeno B1S2: voltaje bajo',
  'P0138': 'Sensor de oxígeno B1S2: voltaje alto',
  'P0140': 'Sensor de oxígeno B1S2: sin actividad',
  'P0141': 'Calentador del sensor de oxígeno B1S2',
  'P0150': 'Sensor de oxígeno B2S1: circuito',
  'P0155': 'Calentador del sensor de oxígeno B2S1',
  'P0171': 'Mezcla demasiado pobre (banco 1): posible fuga de vacío, MAF sucio o bomba débil',
  'P0172': 'Mezcla demasiado rica (banco 1)',
  'P0174': 'Mezcla demasiado pobre (banco 2): posible fuga de vacío, MAF sucio o bomba débil',
  'P0175': 'Mezcla demasiado rica (banco 2)',
  'P0200': 'Circuito de inyectores',
  'P0201': 'Circuito del inyector cilindro 1',
  'P0202': 'Circuito del inyector cilindro 2',
  'P0203': 'Circuito del inyector cilindro 3',
  'P0204': 'Circuito del inyector cilindro 4',
  'P0205': 'Circuito del inyector cilindro 5',
  'P0206': 'Circuito del inyector cilindro 6',
  'P0300': 'Fallas de encendido aleatorias en varios cilindros',
  'P0301': 'Falla de encendido en el cilindro 1',
  'P0302': 'Falla de encendido en el cilindro 2',
  'P0303': 'Falla de encendido en el cilindro 3',
  'P0304': 'Falla de encendido en el cilindro 4',
  'P0305': 'Falla de encendido en el cilindro 5',
  'P0306': 'Falla de encendido en el cilindro 6',
  'P0307': 'Falla de encendido en el cilindro 7',
  'P0308': 'Falla de encendido en el cilindro 8',
  'P0325': 'Circuito del sensor de detonación (cascabeleo) banco 1',
  'P0330': 'Circuito del sensor de detonación banco 2',
  'P0335': 'Circuito del sensor de posición del cigüeñal (CKP)',
  'P0340': 'Circuito del sensor de posición del árbol de levas (CMP)',
  'P0400': 'Flujo de recirculación de gases (EGR)',
  'P0401': 'Flujo EGR insuficiente (conductos tapados o válvula)',
  'P0402': 'Flujo EGR excesivo',
  'P0420': 'Eficiencia del catalizador por debajo del umbral (banco 1)',
  'P0430': 'Eficiencia del catalizador por debajo del umbral (banco 2)',
  'P0440': 'Sistema de emisiones evaporativas (EVAP)',
  'P0441': 'EVAP: flujo de purga incorrecto',
  'P0442': 'EVAP: fuga pequeña detectada (revisa el tapón de gasolina)',
  'P0446': 'EVAP: circuito de la válvula de ventilación',
  'P0455': 'EVAP: fuga grande detectada (tapón de gasolina flojo o dañado)',
  'P0456': 'EVAP: fuga muy pequeña detectada',
  'P0460': 'Circuito del sensor de nivel de combustible',
  'P0500': 'Sensor de velocidad del vehículo (VSS)',
  'P0505': 'Sistema de control de ralentí (IAC)',
  'P0506': 'Ralentí más bajo de lo esperado',
  'P0507': 'Ralentí más alto de lo esperado (posible fuga de vacío)',
  'P0562': 'Voltaje del sistema bajo (batería/alternador)',
  'P0563': 'Voltaje del sistema alto',
  'P0600': 'Falla de comunicación serial de la computadora',
  'P0603': 'Error de memoria interna de la computadora (KAM)',
  'P0700': 'Falla en el sistema de control de la transmisión',
  'P0705': 'Sensor de rango de la transmisión (selector)',
  'P0715': 'Sensor de velocidad de entrada de la transmisión',
  'P0720': 'Sensor de velocidad de salida de la transmisión',
  'P0740': 'Embrague del convertidor de par',
  'P0750': 'Solenoide de cambios A',
  'P0755': 'Solenoide de cambios B',
  'P1320': 'Señal de encendido (Nissan): revisar bobina / módulo',
  'P1400': 'Solenoide de control EGR (Nissan)',
  'P1402': 'Sistema EGR (Nissan)',
  'P1440': 'Sistema EVAP: fuga pequeña (Nissan)',
  'P1447': 'Sistema EVAP: falla de purga (Nissan)',
  'P1456': 'Sistema EVAP: fuga muy pequeña (Nissan)',
};

String dtcSystem(String code) {
  if (code.isEmpty) return '';
  switch (code[0]) {
    case 'P':
      break;
    case 'C':
      return 'Chasis (frenos, ABS, suspensión, dirección)';
    case 'B':
      return 'Carrocería (bolsas de aire, clima, eléctrico interior)';
    case 'U':
      return 'Red de comunicación entre módulos';
  }
  final generic = code.length > 1 && code[1] == '0';
  final sub = code.length > 2 ? code[2] : '';
  final base = switch (sub) {
    '0' => 'Medición de aire/combustible y controles auxiliares',
    '1' => 'Medición de aire y combustible',
    '2' => 'Medición de combustible (circuito de inyectores)',
    '3' => 'Sistema de encendido o fallas de encendido',
    '4' => 'Controles auxiliares de emisiones',
    '5' => 'Velocidad del vehículo, ralentí y entradas auxiliares',
    '6' => 'Computadora y circuitos de salida',
    '7' || '8' || '9' => 'Transmisión',
    _ => 'Tren motriz',
  };
  return generic ? base : '$base (código específico del fabricante)';
}

String dtcDescription(String code) => kDtcText[code] ?? dtcSystem(code);

/// Convierte 2 bytes en un código tipo P0301.
String decodeDtc(int a, int b) {
  const letters = ['P', 'C', 'B', 'U'];
  final l = letters[(a >> 6) & 0x3];
  final d1 = (a >> 4) & 0x3;
  final d2 = (a & 0xF).toRadixString(16).toUpperCase();
  final rest = b.toRadixString(16).toUpperCase().padLeft(2, '0');
  return '$l$d1$d2$rest';
}
