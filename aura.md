# AURA Music — Archivo de Verdad & Guía del Proyecto

> **Última actualización:** 2026-04-26
> **Versión actual:** 1.1.0
> **Propósito:** Este documento es la fuente única de verdad del proyecto. Si cambias la arquitectura, el stack o las convenciones, actualiza este archivo primero.

---

## 1. Qué es AURA Music

AURA Music es un **reproductor de música offline para Android**, construido con Flutter. Está diseñado con un estética dark-mode moderna, enfocado en la reproducción de archivos locales del dispositivo. El proyecto ya cuenta con escaneo de medios, reproducción en segundo plano, cola de canciones, mini-player flotante, gestión básica de listas de reproducción, exploración por álbumes y artistas, y tema dinámico extraído de las carátulas.

---

## 2. Stack Tecnológico

| Capa | Tecnología / Paquete | Versión | Propósito |
|------|----------------------|---------|-----------|
| **Framework** | Flutter SDK | `>=3.0.0 <4.0.0` | UI multiplataforma (solo Android activo) |
| **Lenguaje** | Dart | 3.x | Lógica de negocio |
| **Reproducción** | `just_audio` | `^0.9.36` | Motor de audio subyacente |
| **Servicio en 2º plano** | `audio_service` | `^0.18.12` | Notificación media-style, controles hardware, background playback |
| **Consulta de medios** | `on_audio_query` | `^2.9.0` | Escaneo de biblioteca local (canciones, álbumes, artistas) |
| **Permisos** | `permission_handler` | `^11.1.0` | Solicitud de permisos de almacenamiento/audio |
| **Estado** | `provider` | `^6.1.1` | Inyección de dependencias y gestión reactiva de estado |
| **Base de datos** | `sqflite` + `path` | `^2.3.0` / `^1.8.3` | Persistencia de listas de reproducción |
| **Preferencias** | `shared_preferences` | `^2.2.2` | (Incluido, disponible para settings futuros) |
| **Streams** | `rxdart` | `^0.27.7` | Combinación de streams (`combineLatest3`) para posición/barra de progreso |
| **UI** | `flutter_slidable` | `^3.0.1` | (Incluido, disponible para acciones deslizables) |
| **Paleta de colores** | `palette_generator` | `^0.3.3+3` | (Incluido, disponible para theming dinámico por carátula) |

---

## 3. Arquitectura

El proyecto sigue una estructura modular por **features** (características), con separación de responsabilidades:

```
lib/
├── main.dart                     # Inicialización, DI vía Provider, AudioService
├── app.dart                      # MaterialApp + Shell con BottomNavigation + MiniPlayer
├── core/
│   └── theme/app_theme.dart      # Colores y ThemeData dark
├── data/
│   ├── models/
│   │   ├── song.dart             # Entidad Song (campos + formatter de duración)
│   │   └── playlist.dart         # Entidad Playlist (toMap/fromMap/copyWith)
│   └── repositories/
│       └── playlist_repository.dart  # CRUD de playlists con sqflite
├── features/
│   ├── library/
│   │   ├── library_screen.dart   # Lista de canciones, búsqueda, shuffle-all
│   │   └── library_controller.dart
│   ├── albums/
│   │   └── albums_screen.dart    # Grid de álbumes (QueryArtworkWidget)
│   ├── playlists/
│   │   └── playlists_screen.dart # CRUD básico de playlists (sin detalle aún)
│   ├── player/
│   │   ├── player_screen.dart    # Pantalla completa: carátula, seekbar, controles, cola
│   │   └── player_controller.dart
│   └── settings/
│       └── settings_screen.dart  # Placeholder visual de ajustes
├── services/
│   ├── audio_handler.dart        # AuraAudioHandler: BaseAudioHandler + QueueHandler + SeekHandler
│   └── media_scanner.dart        # Wrapper de on_audio_query + permission_handler
└── widgets/
    └── mini_player.dart          # BackdropFilter, progreso circular, navegación a PlayerScreen
```

### Patrones utilizados
- **Provider + ChangeNotifier** para gestión de estado reactiva.
- **Repository Pattern** para abstracción de persistencia (sqflite).
- **AudioHandler** como punto único de verdad de la reproducción (comunica con el sistema operativo vía `audio_service`).

---

## 4. Qué está implementado (Hecho)

### Reproducción
- [x] Reproducción de archivos locales vía `just_audio`.
- [x] Servicio en segundo plano (`audio_service`) con notificación persistente.
- [x] Controles desde notificación: Play/Pause, Next, Previous.
- [x] Soporte para modo aleatorio (shuffle).
- [x] Soporte para bucle: off / todas / una canción.
- [x] Seek (arrastrar la barra de progreso).
- [x] Controles hardware (media buttons) configurados en `AndroidManifest.xml`.

### Biblioteca
- [x] Escaneo de canciones locales filtrando archivos < 30s (para evitar ringtones).
- [x] Lista de canciones con carátula, título, artista y duración.
- [x] Búsqueda en tiempo real por título, artista o álbum.
- [x] Indicador visual de canción en reproducción (icono + color).
- [x] Botón "Aleatorio" (FloatingActionButton) para mezclar toda la biblioteca.
- [x] Refresh manual del escaneo.

### Álbumes
- [x] Grid de 2 columnas mostrando álbumes con carátula.
- [x] Datos extraídos de `on_audio_query`.

### Playlists
- [x] Crear lista de reproducción con nombre.
- [x] Eliminar lista.
- [x] Persistencia en SQLite (`sqflite`).
- [x] Reproducir primera canción de la lista al tocar (si tiene canciones).
- [x] Esquema de base de datos para guardar canciones dentro de playlists (`playlist_songs`).

### UI / UX
- [x] Tema oscuro propio (`AuraColors`) con púrpura (`#7C4DFF`) y cian (`#00E5FF`) como acentos.
- [x] Material 3 (`useMaterial3: true`).
- [x] Mini-player flotante con `BackdropFilter` (blur) y progreso circular.
- [x] Transición `SlideTransition` al abrir `PlayerScreen`.
- [x] Animación de escala en la carátula cuando pausa/reproduce.
- [x] Navegación inferior (`NavigationBar`) con 4 pestañas: Canciones, Álbumes, Listas, Ajustes.

### Permisos
- [x] Permisos para Android 13+ (`READ_MEDIA_AUDIO`) y legacy (`READ_EXTERNAL_STORAGE`).
- [x] Foreground service para reproducción en background.
- [x] WAKE_LOCK para mantener CPU activa durante reproducción.

---

## 5. Qué falta / TODO Prioritario

> Lista en orden de impacto para el usuario.

### Crítico — Experiencia básica incompleta
- [ ] **Detalle de álbum:** Tocar un álbum debería abrir una pantalla con las canciones de ese álbum. Ahora solo se muestra el grid.
- [ ] **Agregar canciones a playlist:** El repositorio soporta `addSong(int plId, Song song)`, pero la UI no tiene flujo para hacerlo (falta bottom-sheet o pantalla de selección al mantener presionado una canción).
- [ ] **Detalle de playlist:** Tocar una playlist debería mostrar sus canciones, permitir reordenar y eliminar individualmente. Ahora reproduce la primera si existe.
- [ ] **Artistas:** Pestaña o sección faltante. `media_scanner.dart` ya tiene `scanArtists()` pero no se usa en UI.
- [ ] **Favoritos / Me gusta:** No hay sistema de favoritos ni historial.

### Importante — Calidad de vida
- [ ] **Letras (Lyrics):** Buscar o mostrar letras de canciones.
- [ ] **Temporizador de sueño:** UI muestra "Desactivado", sin lógica.
- [ ] **Velocidad de reproducción:** UI muestra "1.0x", sin lógica de cambio.
- [ ] **Tema dinámico:** `palette_generator` está en dependencias pero no se usa. Se podría extraer la paleta dominante de la carátula para tintar la `PlayerScreen`.
- [ ] **Ajustes reales:** Toda la pantalla de Settings es placeholder.
- [ ] **Cola editable:** En la cola de reproducción se puede ver la lista, pero no eliminar ni reordenar elementos.
- [ ] **Swipe actions:** `flutter_slidable` está en dependencias pero no se usa en ninguna lista. Ideal para "Agregar a cola" o "Agregar a playlist".

### Técnico — Robustez & Mantenimiento
- [ ] **Manejo de errores de audio:** Si un archivo URI es inválido o fue eliminado, el reproductor no muestra mensaje amigable.
- [ ] **Estados de carga en PlayerScreen:** No hay indicador de buffering visible si la canción tarda en cargar.
- [ ] **Gestión del ciclo de vida:** El `AudioPlayer` podría liberarse más limpiamente al destruir el servicio.
- [ ] **Paginación / Virtualización:** La lista de canciones carga todo en memoria. Para bibliotecas grandes (>5k) puede haber lag.
- [ ] **Tests:** No hay pruebas unitarias ni de widget (solo `flutter_test` como devDependency por defecto).
- [ ] **Localización:** Todo el texto está en español hardcodeado. No hay sistema i18n.
- [ ] **Lint rules personalizadas:** Se usa `flutter_lints` por defecto; podría fortalecerse con reglas custom.

### Escalabilidad — Características avanzadas
- [ ] **Búsqueda global:** La búsqueda actual solo filtra canciones. Debería poder buscar también álbumes, artistas y playlists.
- [ ] **Widgets de escritorio / pantalla de bloqueo:** Integrar con `audio_service` para mostrar controles en lock screen de Android.
- [ ] **Importar/exportar playlists:** Compartir listas como archivo `.m3u` o JSON.
- [ ] **Equalizador:** Integración nativa con ecualizador del sistema o uno propio.

---

## 6. Recomendaciones de Mejora (Roadmap Sugerido)

### Fase 1 — Completar el núcleo (1-2 semanas)
1. **Pantalla de Detalle de Álbum:** cuando el usuario toque un álbum, navegar a `AlbumDetailScreen` pasando el `albumId`, mostrar `songsByAlbum(albumId)` en lista.
2. **Agregar a Playlist:** implementar un `BottomSheet` desde `_SongTile` o `PlayerScreen` que liste las playlists existentes y permita agregar la canción seleccionada vía `PlaylistRepository.addSong(...)`.
3. **Detalle de Playlist:** pantalla que muestre las canciones guardadas, permita eliminar canciones de la lista y reproducir desde cualquier posición.
4. **Pestaña de Artistas:** añadir a la `NavigationBar` o como sub-página; reutilizar lógica de `scanArtists()`.

### Fase 2 — Pulir UX (1-2 semanas)
5. **Tema dinámico:** usar `palette_generator` sobre la carátula actual para extraer colores dominantes y aplicarlos al fondo degradado de `PlayerScreen`.
6. **Swipe actions:** envolver `_SongTile` con `Slidable` para acciones rápidas ("Agregar a cola", "Agregar a playlist", "Eliminar").
7. **Ajustes funcionales:** implementar temporizador de sueño y selector de velocidad (0.5x - 2.0x).
8. **Animaciones:** mejorar transiciones entre pantallas y añadir micro-interacciones (icono de play/pause con `AnimatedSwitcher`).

### Fase 3 — Robustez & Performance (1 semana)
9. **Paginación lazy:** si `scanSongs()` retorna muchos resultados, considerar carga paginada o al menos caché en memoria optimizada.
10. **Manejo de errores:** capturar excepciones de `just_audio` al cargar URI inválido y mostrar `SnackBar`.
11. **Tests:** añadir al menos tests unitarios para `PlaylistRepository`, `LibraryController` y `PlayerController`.
12. **Refactor DI:** considerar `get_it` o `riverpod` si el árbol de providers crece demasiado (aunque `provider` es suficiente por ahora).

### Fase 4 — Diferenciación (Futuro)
13. **Búsqueda global** con tabs (Canciones / Álbumes / Artistas).
14. **Soporte para carpetas** como categoría de navegación.
15. **Soporte para formatos lossless** (FLAC, ALAC) si `just_audio` los soporta vía codecs nativos.
16. **Sincronización de estado multi-pantalla** (si la app crece a tabletas).

---

## 7. Convenciones del Proyecto

- **Idioma de UI:** Español (Latinoamérica / España).
- **Naming:**
  - Archivos: `snake_case.dart`
  - Clases: `PascalCase`
  - Variables/funciones: `camelCase`
  - Constantes de estilo: `static const` en `AuraColors`.
- **Organización:** Todo el código debe vivir dentro de `lib/`. Nomenclatura de carpetas:
  - `features/` → pantallas + controllers de cada módulo.
  - `services/` → wrappers de plugins y lógica de plataforma/audio.
  - `data/` → modelos puros + repositorios.
  - `core/` → temas, constantes, utils transversales.
  - `widgets/` → componentes reutilizables entre features.
- **UI:** Todo `Scaffold` debe usar `AuraColors.background`. No usar colores hardcodeados fuera de `app_theme.dart`.

---

## 8. Compilación & Ejecución

```bash
# Requisitos previos
flutter doctor         # Verificar que Android toolchain esté OK

# Obtener dependencias
flutter pub get

# Ejecutar en dispositivo/emulador Android
flutter run

# Build APK release
flutter build apk --release

# Build AAB (para Play Store)
flutter build appbundle --release
```

> **Nota:** El archivo `android/app/build.gradle` o `build.gradle.kts` no fue encontrado en el árbol actual. Verificar que el proyecto tenga la configuración de Android completa antes de compilar.

---

## 9. Dependencias Potencialmente Obsoletas / A Revisar

| Paquete | Estado actual | Recomendación |
|---------|---------------|---------------|
| `rxdart` | `^0.27.7` | Revisar si hay versión 0.28+ o migrar a `StreamBuilder` nativo si no se usa `combineLatest` en más lugares. |
| `on_audio_query` | `^2.9.0` | Mantener. Es fundamental y sigue activo. |
| `just_audio` | `^0.9.36` | Mantener. Estándar de la industria en Flutter. |
| `audio_service` | `^0.18.12` | Mantener. Versión estable para background playback. |

---

## 10. Contacto / Maintainers

- **Autor:** DavidDev (infiero del package name `com.daviddev.aura_music`)
- **Repositorio:** `/root/termux_home/aura_music`

---

> **Regla de oro:** Si no está en `aura.md`, no es parte del plan. Actualiza este documento antes de iniciar cualquier refactor mayor.
