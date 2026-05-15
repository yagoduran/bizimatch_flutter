# 📸 Demo Mode - Image Assets Setup

## ✅ Configuración Completada

### 1. **DemoService - Usuarios Demo**

Cada usuario demo tiene sus fotos locales configuradas:

| Usuario | UID | Foto Perfil | Foto Piso | Estado |
|---------|-----|-------------|-----------|--------|
| **Daniel Ruiz** | `demo_1` | `assets/images/demo_people/daniel.jpg` | `assets/images/demo_apartments/piso1.jpg` | ✅ Tiene piso |
| **Lucia Fernandez** | `demo_2` | `assets/images/demo_people/lucia.jpg` | `assets/images/demo_apartments/piso2.jpg` | ✅ Tiene piso |
| **Maria Gomez** | `demo_3` | `assets/images/demo_people/maria.jpg` | - | ✅ Busca piso |

### 2. **Flujo de Carga de Imágenes**

#### A) **Pantalla Discover (Swipe Cards)**
```dart
// discover_screen.dart - _profileImageProvider()
if (user.fotoPerfil.startsWith('assets/')) {
  return AssetImage(user.fotoPerfil);  // ✅ Daniel, Lucia, Maria
}
if (user.fotoPerfil.startsWith('/')) {
  return FileImage(File(user.fotoPerfil));
}
// Fallback a Network
return CachedNetworkImageProvider(user.fotoPerfil);
```

**Resultado**: Las fotos de perfil se cargan desde assets/images/demo_people/

#### B) **Card Principal - Foto del Piso**
```dart
// discover_screen.dart - _profileCard()
final showPisoImage = user.tienePiso && demoMode;
if (showPisoImage) {
  // Muestra foto del piso como imagen principal
  Image.asset(user.fotosPiso.first)  // ✅ piso1.jpg, piso2.jpg
}
```

**Resultado**: El piso se muestra como fondo, avatar en esquina superior derecha

#### C) **Overlay de Match**
```dart
// discover_screen.dart - _DemoMatchOverlay
CircleAvatar(
  backgroundImage: me.fotoPerfil.startsWith('assets/')
    ? AssetImage(me.fotoPerfil)          // ✅ Avatar local
    : NetworkImage(me.fotoPerfil)
)
CircleAvatar(
  backgroundImage: other.fotoPerfil.startsWith('assets/')
    ? AssetImage(other.fotoPerfil)       // ✅ Avatar local
    : NetworkImage(other.fotoPerfil)
)
```

**Resultado**: Avatares en animación de match usan imágenes locales

#### D) **Pantalla de Matches (Chat List)**
```dart
// matches_screen.dart
AppCachedAvatar(
  imageUrl: user.fotoPerfil,  // 'assets/images/demo_people/...'
  radius: 26
)
```

**AppCachedAvatar Logic:**
```dart
// app_cached_network_image.dart - AppCachedAvatar
if (imageUrl.startsWith('assets/')) {
  return CircleAvatar(
    child: ClipOval(
      child: Image.asset(imageUrl, fit: BoxFit.cover)  // ✅ Carga local
    )
  );
}
// Fallback a Network
return CircleAvatar(
  child: AppCachedNetworkImage(...)  // CachedNetworkImage
);
```

**Resultado**: Las miniaturas de Daniel, Lucia, Maria en la lista usan assets

#### E) **Pantalla de Chat Detail**
```dart
// chat_detail_screen.dart
AppCachedAvatar(
  imageUrl: widget.avatarUrl,  // 'assets/images/demo_people/...'
  radius: 20
)
```

**Resultado**: Avatar en header del chat usa imagen local

#### F) **DemoChat Screen**
```dart
// demo_chat_screen.dart
CircleAvatar(
  backgroundImage: AssetImage(widget.otherUser.fotoPerfil)  // ✅ Imagen local
)
```

**Resultado**: Avatar en chat demo usa imagen local

#### G) **Profile Screen**
```dart
// profile_screen.dart
final isAssetPath = profile.fotoPerfil.startsWith('assets/');
final isLocalPath = profile.fotoPerfil.startsWith('/');

if (isAssetPath) {
  CircleAvatar(backgroundImage: AssetImage(profile.fotoPerfil))  // ✅ Assets
} else if (isLocalPath) {
  CircleAvatar(backgroundImage: FileImage(File(profile.fotoPerfil)))
} else {
  AppCachedAvatar(imageUrl: avatarUrl)  // Network
}
```

**Resultado**: Perfil del usuario usa imagen local en modo demo

### 3. **Archivos de Imagen Creados**

```
assets/images/demo_people/
├── daniel.jpg          (Profile picture)
├── lucia.jpg           (Profile picture)
├── maria.jpg           (Profile picture)
└── ... (descarga images for fallback)

assets/images/demo_apartments/
├── piso1.jpg           (Daniel's apartment)
├── piso2.jpg           (Lucia's apartment)
└── ... (apartment images available)
```

### 4. **Pantallas Afectadas ✅**

| Pantalla | Widget | Foto Cargada | Fuente |
|----------|--------|--------------|--------|
| **Discover** | Swipe Card Avatar | Daniel, Lucia, Maria | assets/ |
| **Discover** | Card Principal | Piso 1, Piso 2 | assets/ |
| **Match Overlay** | Avatares Match | Daniel, Lucia | assets/ |
| **Matches** | List Thumbnails | Daniel, Lucia | assets/ |
| **Chat Detail** | Header Avatar | Daniel, Lucia | assets/ |
| **Demo Chat** | Chat Header | Daniel, Lucia | assets/ |
| **Profile Detail** | Profile Avatar | User fotoPerfil | assets/ o network |

### 5. **Lógica de Fallback**

Si las imágenes de assets no se encuentran:
1. discover_screen.dart: Fallback a `NetworkImage`
2. AppCachedAvatar: Fallback a `CachedNetworkImage`
3. profile_screen.dart: Fallback a imagen por defecto de Unsplash

---

## 🚀 Demo Mode - Modo Completamente Offline

Con esta configuración, el **Modo Demo es completamente funcional sin conexión a internet**:

✅ Usuarios visibles con fotos de perfil  
✅ Tarjetas con fotos de pisos  
✅ Animación de match con avatares  
✅ Lista de chats con miniaturas  
✅ Ventanas de chat operacionales  
✅ Gestión de casa con fotos de salón  

---

## 📝 Cambios Realizados

### Archivos Modificados:
1. **lib/screens/profile_screen.dart** - Soporte para asset paths en foto de perfil
2. **lib/services/demo_service.dart** - Fotos configuradas (ya existía)
3. **lib/widgets/app_cached_network_image.dart** - Soporte asset paths (ya existía)

### Archivos Verificados ✅:
- discover_screen.dart - AssetImage para assets/
- matches_screen.dart - AppCachedAvatar soporta assets
- demo_chat_screen.dart - AssetImage directo
- chat_detail_screen.dart - AppCachedAvatar soporta assets
- profile_detail_screen.dart - AppCachedAvatar soporta assets

---

## ✨ Resultado Final

Las fotos de los usuarios demo se cargan **completamente desde assets** en:
- Cards de descubrimiento
- Overlay de match
- Lista de conversaciones
- Ventanas de chat
- Pantalla de perfil

**Modo demo 100% offline** ✅
