# 📑 BiziMatch - Contexto de Desarrollo para IA

## 🚀 Descripción del Proyecto
BiziMatch es una plataforma de convivencia integral para conectar usuarios compatibles, gestionar hogares y formalizar contratos de alquiler.

## 🛠️ Stack Tecnológico
- **Frontend:** Flutter (Dart).
- **Backend:** Firebase (Auth, Firestore, Storage).
- **Configuración Nativa:** Android usa Gradle con Kotlin DSL (`build.gradle.kts`).
- **Estado:** Usamos [Nombre de tu gestor de estado: Provider/Riverpod/Bloc].

## 🏗️ Arquitectura y Estilo de Código
- **Directorios:** - `lib/models/`: Modelos de datos (con `fromFirestore` y `toFirestore`).
  - `lib/screens/`: Pantallas de la UI.
  - `lib/services/`: Lógica de Firebase y APIs.
- **Reglas:** - Usar Clean Code y nombres de variables descriptivos en español/inglés.
  - Evitar el uso de `print()`, usar un Logger o `debugPrint`.
  - **IMPORTANTE:** Siempre que modifiques archivos de Android, recuerda que usamos `.kts`.

## 📍 Estado Actual del Proyecto (ACTUALIZAR SIEMPRE)
1. **Hecho:** Auth básica, Swipe de usuarios, Corrección de errores de compilación Release (Desugaring habilitado).
2. **En curso:** Implementación de las "9 Funcionalidades Pro".
3. **Próximo paso:** Implementar el "BiziBot" (IA Rompehielos).

Hola. Lee primero el archivo @AI_CONTEXT.md para situarte. Ahí tienes el stack, las reglas de arquitectura y por dónde nos quedamos ayer. No analices otros archivos hasta que te lo pida específicamente para ahorrar tokens. Confírmame que estás listo para seguir con el punto [X] de la lista de tareas.