# AutoPanel 🚙

Tablero inteligente para tableta Android montada en el auto, hecho en Flutter. Funciona como pantalla de inicio (launcher).

## Funciones

- **Inicio**: velocímetro (OBD2 o GPS), RPM, temperatura del motor, voltaje de batería, autonomía, viaje, check engine, próximo recordatorio, clima, controles de música y accesos a Waze, Maps, Spotify y Android Auto.
- **Motor**: datos en vivo del OBD2 (adaptador Vgate/ELM327 Bluetooth). Muestra todos los sensores que reporta el auto, cada uno con su explicación en español.
- **Códigos**: lee los códigos de falla guardados y pendientes, los explica en español y permite borrarlos.
- **Viaje**: distancia, tiempo, velocidad promedio y máxima, combustible usado, rendimiento real (km/L) y costo.
- **Gasolina**: autonomía (nivel del OBD2 o manual) y gasolineras cercanas con el precio del día (datos públicos de la CRE). Al tocar una, Waze te lleva.
- **Clima**: actual, por hora y 7 días (Open-Meteo).
- **Modo día/noche** automático según el amanecer y el atardecer.
- **Pendientes**: verificación, tenencia, seguro y servicio con los días que faltan.

## Descargar el APK

Cada push a `main` compila el APK con GitHub Actions. Se descarga desde **Releases** → `AutoPanel.apk`.

## Desarrollo

```bash
flutter create --platforms=android --org mx.autopanel --project-name autopanel /tmp/gen
cp -r /tmp/gen/android ./android
python3 tool/patch_android.py   # permisos, modo launcher y MainActivity nativa
flutter run
```

La carpeta `android/` se genera; el código nativo propio (Bluetooth SPP del OBD2, abrir apps, teclas multimedia) vive en `native/MainActivity.kt`.

## Uso en el auto

1. Emparejar el adaptador OBD2 en Bluetooth de la tableta (PIN 1234 o 0000).
2. En **Ajustes** → *Elegir adaptador emparejado*.
3. Compartir internet desde el celular (hotspot) para el clima y los precios.
4. Presionar el botón de inicio y elegir AutoPanel → *Siempre*.
5. Para Android Auto: instalar *Headunit Revived* en la tableta.
