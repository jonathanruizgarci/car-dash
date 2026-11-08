/// Sensores OBD2 (modo 01) con fórmula y explicación en español.
class PidDef {
  final String pid;
  final String name;
  final String unit;
  final int bytes;
  final int decimals;
  final String help;
  final double Function(List<int> b) f;

  const PidDef(this.pid, this.name, this.unit, this.bytes, this.decimals, this.help, this.f);
}

double _pct(List<int> b) => b[0] * 100 / 255;
double _temp(List<int> b) => b[0] - 40.0;
double _word(List<int> b) => (b[0] * 256 + b[1]).toDouble();
double _trim(List<int> b) => (b[0] - 128) * 100 / 128;

final List<PidDef> kPids = [
  PidDef('04', 'Carga del motor', '%', 1, 0,
      'Qué tanto esfuerzo está haciendo el motor comparado con su máximo. En crucero suele estar entre 20 y 50 %.', _pct),
  PidDef('05', 'Temperatura del motor', '°C', 1, 0,
      'Temperatura del anticongelante. Lo normal con el motor caliente es entre 85 y 105 °C. Arriba de 110 °C hay riesgo de sobrecalentamiento.', _temp),
  PidDef('06', 'Ajuste de combustible corto (B1)', '%', 1, 1,
      'Corrección inmediata que hace la computadora a la mezcla. Valores positivos = mezcla pobre (falta gasolina), negativos = mezcla rica. Normal entre -10 y +10 %.', _trim),
  PidDef('07', 'Ajuste de combustible largo (B1)', '%', 1, 1,
      'Corrección aprendida a largo plazo. Si pasa de ±10 % de forma constante puede haber fugas de vacío, inyectores sucios o sensor MAF sucio.', _trim),
  PidDef('08', 'Ajuste de combustible corto (B2)', '%', 1, 1,
      'Igual que el ajuste corto, pero para el banco 2 (el otro lado del motor en motores V6/V8).', _trim),
  PidDef('09', 'Ajuste de combustible largo (B2)', '%', 1, 1,
      'Corrección aprendida del banco 2. Compárala con la del banco 1 para ubicar fallas de un solo lado.', _trim),
  PidDef('0A', 'Presión de combustible', 'kPa', 1, 0,
      'Presión del combustible en el riel de inyectores.', (b) => b[0] * 3.0),
  PidDef('0B', 'Presión del múltiple de admisión', 'kPa', 1, 0,
      'Vacío/presión en la admisión. En ralentí suele estar entre 25 y 40 kPa; acelerando a fondo se acerca a la presión atmosférica.', (b) => b[0].toDouble()),
  PidDef('0C', 'Revoluciones (RPM)', 'rpm', 2, 0,
      'Vueltas por minuto del cigüeñal. En ralentí lo normal es entre 650 y 900 rpm.', (b) => (b[0] * 256 + b[1]) / 4),
  PidDef('0D', 'Velocidad', 'km/h', 1, 0,
      'Velocidad que reporta el sensor de velocidad del vehículo.', (b) => b[0].toDouble()),
  PidDef('0E', 'Avance del encendido', '°', 1, 1,
      'Grados antes del punto muerto superior en que salta la chispa. Si baja mucho al acelerar puede haber cascabeleo (detonación).', (b) => b[0] / 2 - 64),
  PidDef('0F', 'Temperatura del aire de admisión', '°C', 1, 0,
      'Temperatura del aire que entra al motor. Aire más frío = más potencia.', _temp),
  PidDef('10', 'Flujo de aire (MAF)', 'g/s', 2, 1,
      'Cantidad de aire que entra al motor. Se usa para calcular el consumo de gasolina. En ralentí suele ser de 2 a 7 g/s.', (b) => (b[0] * 256 + b[1]) / 100),
  PidDef('11', 'Posición del acelerador', '%', 1, 0,
      'Qué tan abierta está la mariposa de aceleración.', _pct),
  PidDef('14', 'Sensor de oxígeno B1S1', 'V', 2, 2,
      'Sensor de oxígeno antes del catalizador. Debe oscilar rápido entre 0.1 y 0.9 V cuando el motor está caliente.', (b) => b[0] / 200),
  PidDef('15', 'Sensor de oxígeno B1S2', 'V', 2, 2,
      'Sensor después del catalizador. Debe mantenerse más estable; si oscila igual que el primero, el catalizador puede estar dañado.', (b) => b[0] / 200),
  PidDef('18', 'Sensor de oxígeno B2S1', 'V', 2, 2,
      'Sensor de oxígeno antes del catalizador del banco 2.', (b) => b[0] / 200),
  PidDef('19', 'Sensor de oxígeno B2S2', 'V', 2, 2,
      'Sensor de oxígeno después del catalizador del banco 2.', (b) => b[0] / 200),
  PidDef('1F', 'Tiempo desde el arranque', 's', 2, 0,
      'Segundos que lleva encendido el motor en este viaje.', _word),
  PidDef('21', 'Distancia con check engine', 'km', 2, 0,
      'Kilómetros recorridos con la luz de check engine encendida.', _word),
  PidDef('2C', 'EGR comandada', '%', 1, 0,
      'Apertura que la computadora pide a la válvula EGR (recirculación de gases).', _pct),
  PidDef('2F', 'Nivel de combustible', '%', 1, 0,
      'Nivel del tanque según el flotador. Se usa para calcular la autonomía.', _pct),
  PidDef('31', 'Distancia desde borrado de códigos', 'km', 2, 0,
      'Kilómetros desde que se borraron los códigos o se desconectó la batería. Útil antes de la verificación: los monitores necesitan kilómetros para estar listos.', _word),
  PidDef('33', 'Presión barométrica', 'kPa', 1, 0,
      'Presión atmosférica. A nivel del mar ~101 kPa; en Puebla (≈2,100 m) ronda 78-80 kPa.', (b) => b[0].toDouble()),
  PidDef('42', 'Voltaje de la computadora', 'V', 2, 2,
      'Voltaje que recibe la computadora del motor. Con motor encendido debe estar entre 13.5 y 14.7 V (alternador cargando).', (b) => (b[0] * 256 + b[1]) / 1000),
  PidDef('43', 'Carga absoluta', '%', 2, 0,
      'Carga del motor calculada a partir de la masa de aire por ciclo.', (b) => (b[0] * 256 + b[1]) * 100 / 255),
  PidDef('44', 'Relación aire/combustible comandada', 'λ', 2, 2,
      'Mezcla que pide la computadora. 1.00 = mezcla ideal (14.7:1). Menor a 1 = rica.', (b) => (b[0] * 256 + b[1]) * 2 / 65536),
  PidDef('45', 'Posición relativa del acelerador', '%', 1, 0,
      'Apertura del acelerador relativa a su posición de reposo aprendida.', _pct),
  PidDef('46', 'Temperatura ambiente', '°C', 1, 0,
      'Temperatura exterior medida por el auto.', _temp),
  PidDef('47', 'Posición absoluta del acelerador B', '%', 1, 0,
      'Segundo sensor de posición del acelerador (redundancia de seguridad).', _pct),
  PidDef('49', 'Posición del pedal D', '%', 1, 0,
      'Qué tanto estás pisando el pedal del acelerador (acelerador electrónico).', _pct),
  PidDef('4C', 'Acelerador comandado', '%', 1, 0,
      'Apertura del acelerador que pide la computadora.', _pct),
  PidDef('5C', 'Temperatura del aceite', '°C', 1, 0,
      'Temperatura del aceite del motor. Normal entre 90 y 115 °C.', _temp),
  PidDef('5E', 'Consumo de combustible', 'L/h', 2, 1,
      'Litros por hora que está consumiendo el motor en este momento.', (b) => (b[0] * 256 + b[1]) / 20),
];

final Map<String, PidDef> kPidById = {for (final p in kPids) p.pid: p};
