"""Ajusta el proyecto Android generado por `flutter create`:
permisos, modo launcher (HOME), visibilidad de apps y MainActivity nativa."""
import glob
import re
import sys

MANIFEST = "android/app/src/main/AndroidManifest.xml"

PERMISSIONS = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-feature android:name="android.hardware.bluetooth" android:required="false"/>
    <uses-feature android:name="android.hardware.location.gps" android:required="false"/>
"""

PACKAGES = [
    "com.waze",
    "com.google.android.apps.maps",
    "com.spotify.music",
    "com.google.android.apps.youtube.music",
    "com.google.android.projection.gearhead",
    "com.andrerinas.headunitrevived",
    "gb.xxy.trial",
    "gb.xxy.hr",
    "com.whatsapp",
]

QUERIES_INNER = "".join(
    f'\n        <package android:name="{p}"/>' for p in PACKAGES
) + """
        <intent>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="waze"/>
        </intent>"""

HOME_FILTER = """
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.HOME"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>"""


def patch_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        xml = f.read()

    # Permisos justo después de la etiqueta <manifest ...>
    m = re.search(r"<manifest[^>]*>", xml)
    if not m:
        sys.exit("No se encontró <manifest>")
    xml = xml[: m.end()] + PERMISSIONS + xml[m.end():]

    # Nombre visible de la app
    xml = re.sub(r'android:label="[^"]*"', 'android:label="AutoPanel"', xml, count=1)

    # Visibilidad de paquetes (Android 11+)
    if "<queries>" in xml:
        xml = xml.replace("<queries>", "<queries>" + QUERIES_INNER, 1)
    else:
        xml = xml.replace("</manifest>", "    <queries>" + QUERIES_INNER + "\n    </queries>\n</manifest>", 1)

    # Permitir usar la app como pantalla de inicio (launcher)
    lm = re.search(r'android\.intent\.category\.LAUNCHER"\s*/>\s*</intent-filter>', xml)
    if not lm:
        sys.exit("No se encontró el intent-filter LAUNCHER")
    xml = xml[: lm.end()] + HOME_FILTER + xml[lm.end():]

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Manifest actualizado")


def patch_activity():
    files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
    if not files:
        sys.exit("No se encontró MainActivity.kt")
    path = files[0]
    with open(path, encoding="utf-8") as f:
        original = f.read()
    pkg = re.search(r"^package\s+([\w.]+)", original, re.M).group(1)
    with open("native/MainActivity.kt", encoding="utf-8") as f:
        ours = f.read().replace("__PACKAGE__", pkg)
    with open(path, "w", encoding="utf-8") as f:
        f.write(ours)
    print(f"MainActivity reemplazada en {path} ({pkg})")


if __name__ == "__main__":
    patch_manifest()
    patch_activity()
