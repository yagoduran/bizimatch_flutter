# Configuración de Google Maps

Para que la pestaña de Mapa funcione correctamente, necesitas configurar una API Key de Google Maps.

## Pasos:

### 1. Crear un proyecto en Google Cloud Console

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Ve a "APIs y Servicios" > "Biblioteca"
4. Busca "Maps SDK for Android" y actívalo
5. Busca "Maps SDK for iOS" y actívalo

### 2. Generar una API Key

1. Ve a "APIs y Servicios" > "Credenciales"
2. Haz clic en "Crear credenciales" > "Clave de API"
3. Copia la clave generada

### 3. Restricciones de clave (Recomendado)

1. En la pantalla de credenciales, haz clic en tu clave
2. Ve a "Restricciones de aplicaciones"
3. Selecciona "Android" o "iOS" según donde quieras usarla
4. Para Android: añade el SHA-1 de tu app
5. Para iOS: añade los Bundle IDs

### 4. Configurar en la app

#### Android (`android/app/src/main/AndroidManifest.xml`):
Reemplaza `YOUR_GOOGLE_MAPS_API_KEY_HERE` con tu clave en:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE" />
```

#### iOS (`ios/Runner/Info.plist`):
Reemplaza `YOUR_GOOGLE_MAPS_API_KEY_HERE` con tu clave en:
```xml
<key>GMS_API_KEY</key>
<string>YOUR_GOOGLE_MAPS_API_KEY_HERE</string>
```

### 5. Verificar SHA-1 de tu app Android

Para obtener el SHA-1 de tu app:
```bash
cd android
./gradlew signingReport
```

Busca la línea que comienza con "SHA-1" bajo "debug" o "release".

## Notas

- Las coordenadas de los usuarios en el mapa son simuladas (basadas en el UID).
- En producción, deberías guardar lat/lng reales en Firestore.
- La API Key debe tener permisos para Maps SDK for Android y Maps SDK for iOS.
