# 🎨 Guía Rápida: Modo Demo con Assets

## 📍 Cambio Principal Realizado

**Archivo**: `lib/screens/profile_screen.dart` (Línea ~1163)

```dart
// ANTES
final isLocalPath = profile.fotoPerfil.startsWith('/');
if (isLocalPath) {
  CircleAvatar(backgroundImage: FileImage(...))
} else {
  AppCachedAvatar(...)
}

// DESPUÉS
final isAssetPath = profile.fotoPerfil.startsWith('assets/');
final isLocalPath = profile.fotoPerfil.startsWith('/');

if (isAssetPath) {
  CircleAvatar(backgroundImage: AssetImage(profile.fotoPerfil))  // ✅ NEW
} else if (isLocalPath) {
  CircleAvatar(backgroundImage: FileImage(...))
} else {
  AppCachedAvatar(...)
}
```

---

## 🔗 Cómo Funciona

### Cuando isDemoMode = true:

```
Usuario Demo (demo_1, demo_2, etc.)
  ↓
fotoPerfil = 'assets/images/demo_people/...'
  ↓
Verifica: startsWith('assets/') ?
  ↓
SÍ → Image.asset() [Local, Sin red]
  ↓
Pantallas afectadas:
  - Discover (swipe cards)
  - Matches (chat list)
  - Chat Detail
  - Profile
  - Match Overlay
```

### Cuando isDemoMode = false:

```
Usuario Real (Firebase)
  ↓
fotoPerfil = 'https://...' o '/ruta/local/'
  ↓
Verifica: startsWith('assets/') ?
  ↓
NO → AppCachedAvatar() [Network o Local]
  ↓
Funciona como siempre
```

---

## 📸 Configuración en DemoService

```dart
// lib/services/demo_service.dart

UserProfile(
  uid: 'demo_1',
  nombre: 'Daniel Ruiz',
  fotoPerfil: 'assets/images/demo_people/daniel.jpg',      // ✅
  fotosPiso: const ['assets/images/demo_apartments/piso1.jpg'],  // ✅
),
UserProfile(
  uid: 'demo_2',
  nombre: 'Lucia Fernandez',
  fotoPerfil: 'assets/images/demo_people/lucia.jpg',       // ✅
  fotosPiso: const ['assets/images/demo_apartments/piso2.jpg'],  // ✅
),
UserProfile(
  uid: 'demo_3',
  nombre: 'Maria Gomez',
  fotoPerfil: 'assets/images/demo_people/maria.jpg',       // ✅
),
```

---

## 🎯 Pantallas Actualizadas

| Pantalla | Cambio |
|----------|--------|
| Discover | ✅ Avatares y pisos de assets |
| Matches | ✅ Miniaturas de assets |
| Chat | ✅ Avatar de assets |
| Profile | ✅ NUEVO - Soporta asset paths |
| Match Overlay | ✅ Avatares de assets |

---

## ⚡ AppCachedAvatar (Universal)

Ya soporta assets automáticamente:

```dart
AppCachedAvatar(
  imageUrl: 'assets/images/demo_people/...'  // Detecta automáticamente
)
```

**Lógica interna:**
```dart
if (imageUrl.startsWith('assets/')) {
  Image.asset()   // Local
} else {
  CachedNetworkImage()  // Network
}
```

---

## 📦 Assets Disponibles

```
assets/images/demo_people/
├── daniel.jpg
├── lucia.jpg
└── maria.jpg

assets/images/demo_apartments/
├── piso1.jpg
├── piso2.jpg
└── ... (más fotos disponibles)
```

---

## ✅ Verificación

```bash
# Sin errores
$ flutter analyze
Analyzing bizimatch_flutter... No issues found!

# Compilación
$ flutter pub get
Got dependencies!
```

---

## 🚀 Para Habilitar Demo Mode

```dart
// En cualquier pantalla
import 'package:bizimatch_flutter/services/demo_service.dart';

// Habilitar
DemoService.instance.enableDemo(true);

// Seleccionar usuario
DemoService.instance.selectDemoUserByUid('demo_1');

// Deshabilitar
DemoService.instance.enableDemo(false);
```

---

## 🔄 Flujo Completo

1. **Settings Screen** → Switch "Modo Demo"
2. **DemoService** → Activa isDemoMode
3. **Discover Screen** → Carga demoProfiles
4. **AppCachedAvatar** → Detecta "assets/" → Image.asset()
5. **Pantalla** → Muestra fotos locales
6. **Sin conexión a internet** → Todo funciona

---

## 💡 Notas Importantes

- ✅ Compatible con usuarios reales (Firebase)
- ✅ Fallback automático a network si es necesario
- ✅ Sin cambios en modelos o BD
- ✅ Completamente offline en modo demo
- ✅ Performance mejorado (assets son más rápidos)

---

**Estado**: ✅ Implementado y verificado
**Archivo clave**: `profile_screen.dart` (isAssetPath detection)
**Dependencia**: AppCachedAvatar ya soporta assets
