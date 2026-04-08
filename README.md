# 🏠 BiziMatch - Tu Vínculo Perfecto para Convivir

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![TFG](https://img.shields.io/badge/Status-TFG_Ready-success?style=for-the-badge)

**BiziMatch** no es solo una aplicación para buscar piso; es una plataforma integral diseñada para conectar a personas compatibles (Vínculos) basándose en su estilo de vida, hábitos y afinidad real. 

Nuestra misión es erradicar las malas convivencias mediante un algoritmo de compatibilidad profunda y herramientas de gestión del hogar post-mudanza.

---

## ✨ Características Principales (Features)

### 🔍 El Motor de Búsqueda (Core)
* **Swipe Inteligente:** Interfaz fluida (estilo Tinder) para descubrir perfiles con respuesta háptica y animaciones Premium.
* **Algoritmo de Afinidad:** Calcula un porcentaje de compatibilidad basado en hábitos clave (limpieza, horarios, fiestas, mascotas, teletrabajo).
* **Geolocalización Real:** Mapa interactivo con pines distribuidos para visualizar pisos disponibles y Puntos de Interés (Metro, Supermercados).
* **Filtros Avanzados:** Segmentación exhaustiva por presupuesto, edad, género y estilo de vida.

### 💬 Interacción y Comunidad
* **Match y Chat en Tiempo Real:** Sistema de "Doble Opt-in" que habilita un chat con base de datos en tiempo real (Firestore) solo cuando hay interés mutuo.
* **BiziBot (IA Integrada):** Asistente rompehielos que lee las biografías y sugiere el primer mensaje perfecto.
* **Notas de Voz en Perfil:** Biografías auditivas de 15 segundos para generar mayor empatía.
* **Sistema de Karma y Reseñas:** Validación social mediante medallas otorgadas por ex-compañeros (Limpieza, Respeto, Cocina).

### 🛡️ Seguridad y Moderación
* **Verificación de Identidad ("Tick Azul"):** Sistema de validación de usuarios para evitar perfiles falsos.
* **Reporte y Bloqueo:** Herramientas para mantener una comunidad segura cumpliendo las normativas de las App Stores.
* **Modo SOS / Urgencia:** Visibilidad prioritaria (tarjetas destacadas) para usuarios que necesitan alojamiento en menos de 7 días.

### 🛠️ Ecosistema Post-Match (La Convivencia)
* **Pacto de Convivencia:** Contrato digital y checklist colaborativo dentro del chat.
* **Gestor "Mi Casa":** Tablero de tareas gamificado ("BiziPuntos") para repartir las labores del hogar de forma justa.
* **Calculadora de Gastos:** Herramienta integrada para dividir equitativamente el alquiler y los suministros (Luz, Agua, Internet).

---

## 🏗️ Stack Tecnológico

La aplicación ha sido desarrollada siguiendo las mejores prácticas de la industria, garantizando rendimiento, escalabilidad y accesibilidad:

* **Frontend:** Flutter & Dart (Soporte nativo para Dark Mode y Haptic Feedback).
* **Backend as a Service (BaaS):** Firebase.
    * *Cloud Firestore:* Base de datos NoSQL con persistencia Offline (Modo Metro).
    * *Firebase Auth:* Autenticación segura y gestión de cuentas.
    * *Cloud Messaging:* Notificaciones Push (FCM).
    * *Crashlytics & Analytics:* Telemetría profesional y monitoreo de estabilidad.
* **Almacenamiento de Medios:** Integración con API de ImgBB y caché eficiente (`cached_network_image`).
* **Mapas:** `flutter_map` con datos de OpenStreetMap.

---

## 🚀 Instalación y Despliegue

Si deseas clonar y probar este proyecto en tu entorno local:

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/tu-usuario/bizimatch_flutter.git](https://github.com/tu-usuario/bizimatch_flutter.git)
    ```
2.  **Instalar dependencias:**
    ```bash
    cd bizimatch_flutter
    flutter pub get
    ```
3.  **Configurar Firebase:**
    Asegúrate de conectar la app con tu propio proyecto de Firebase usando `flutterfire configure`. Las reglas de Firestore deben permitir la escritura para pruebas locales.
4.  **Ejecutar la app:**
    ```bash
    flutter run
    ```

---

## 📱 Screenshots

*(Añade aquí capturas de pantalla de tu aplicación funcionando en el emulador o en tu Oppo. Puedes usar rutas relativas como `![Inicio](assets/screenshots/home.png)`)*

---

## 🎓 Contexto Académico

Este proyecto ha sido desarrollado como **Trabajo de Fin de Grado (TFG)**, con el objetivo de demostrar competencias avanzadas en el desarrollo multiplataforma, diseño de interfaces de usuario (UX/UI), integración de servicios en la nube y arquitectura de software.

Desarrollado con ☕ y pasión.