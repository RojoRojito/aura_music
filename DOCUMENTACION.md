# AURA Music - Documentación del Código

## Visión General

AURA Music es un reproductor de música offline para Android construido con Flutter/Dart. La aplicación permite reproducir archivos de audio locales almacenados en el dispositivo, con soporte para organización por canciones, álbumes, artistas y listas de reproducción personalizadas.

---

## Arquitectura del Proyecto

```
lib/
├── main.dart                      # Punto de entrada e inicialización
├── app.dart                       # Configuración de la UI principal
├── core/
│   └── theme/
│       └── app_theme.dart         # Tema y colores personalizados
├── data/
│   ├── models/                    # Modelos de datos
│   │   ├── song.dart
│   │   ├── playlist.dart
│   │   └── artist.dart
│   └── repositories/              # Capa de persistencia
│       └── playlist_repository.dart
├── features/                      # Características organizadas
│   ├── library/                   # Biblioteca de canciones
│   ├── albums/                    # Explorador de álbumes
│   ├── artists/                   # Explorador de artistas
│   ├── playlists/                 # Gestión de listas
│   ├── player/                    # Reproductor
│   └── settings/                  # Configuración
├── services/                      # Servicios del sistema
│   ├── audio_handler.dart         # Manejo de audio
│   ├── media_scanner.dart         # Escaneo de medios
│   └── dynamic_theme_service.dart # Tema dinámico
└── widgets/                       # Widgets reutilizables
    ├── mini_player.dart
    ├── song_tile.dart
    └── add_to_playlist_sheet.dart
```

---

## Archivos Principales

### `main.dart` - Punto de Entrada

**Propósito:** Inicializar la aplicación y configurar la inyección de dependencias.

**Funcionamiento:**
1. `WidgetsFlutterBinding.ensureInitialized()` - Inicializa el binding de Flutter
2. `SystemChrome.setPreferredOrientations()` - Fuerza orientación vertical
3. `AudioService.init()` - Inicializa el servicio de reproducción en segundo plano
4. `MultiProvider` - Registra todos los servicios y controladores:
   - `AuraAudioHandler` - Manejo de audio
   - `MediaScanner` - Escaneo de medios
   - `PlayerController` - Control del reproductor
   - `LibraryController` - Control de biblioteca
   - `PlaylistRepository` - Repositorio de playlists
   - `SettingsController` - Configuración

**Patrones:** Dependency Injection, Service Locator

---

### `app.dart` - Shell de la Aplicación

**Propósito:** Definir la estructura UI principal con navegación y tema.

**Componentes:**
- `AuraApp` - Widget raíz con MaterialApp configurado
- `_Shell` - Estado principal que maneja:
  - Navegación por 5 pestañas (NavigationBar)
  - Mini-player flotante sobre el contenido
  - IndexedStack para mantener el estado de cada pantalla

**Navegación:**
1. Canciones (LibraryScreen)
2. Álbumes (AlbumsScreen)
3. Artistas (ArtistsScreen)
4. Listas (PlaylistsScreen)
5. Ajustes (SettingsScreen)

---

## Capa Core

### `core/theme/app_theme.dart` - Tema Personalizado

**Propósito:** Definir la identidad visual de la aplicación.

**Componentes:**
- `AuraColors` - Paleta de colores:
  - `background` (#0A0A0F) - Fondo principal
  - `surface` (#13131A) - Superficies/cards
  - `primary` (#7C4DFF) - Color primario púrpura
  - `secondary` (#00E5FF) - Color secundario cian
  - `accent` (#FF4081) - Color de acento rosa

- `AuraTheme.dark()` - Configuración del tema Material 3:
  - ColorScheme oscuro
  - Tema de NavigationBar personalizado
  - Tema de Slider personalizado

---

## Capa de Datos

### `data/models/song.dart` - Modelo de Canción

**Propósito:** Representar una canción en la aplicación.

**Propiedades:**
- `id`, `title`, `artist`, `album` - Metadatos básicos
- `uri`, `albumArtUri` - URIs de reproducción y carátula
- `duration` - Duración en milisegundos
- `albumId`, `artistId` - Referencias a álbum/artista
- `genre`, `year`, `trackNumber` - Metadatos adicionales

**Métodos:**
- `durationFormatted` - Convierte duración a formato MM:SS
- Operadores de igualdad basados en `id`

---

### `data/models/playlist.dart` - Modelo de Playlist

**Propósito:** Representar una lista de reproducción.

**Propiedades:**
- `id` - Identificador en base de datos
- `name` - Nombre de la playlist
- `songs` - Lista de canciones
- `createdAt` - Fecha de creación

**Métodos:**
- `songCount` - Cantidad de canciones (getter)
- `totalDuration` - Duración total calculada
- `copyWith()` - Crear copia modificada
- `toMap()` / `fromMap()` - Serialización para SQLite

---

### `data/models/artist.dart` - Modelo de Artista

**Propósito:** Representar un artista (wrapper de ArtistModel de on_audio_query).

**Propiedades:**
- `id`, `artist`, `numberOfAlbums`, `numberOfTracks`

---

### `data/repositories/playlist_repository.dart` - Repositorio de Playlists

**Propósito:** Gestionar el CRUD de playlists en SQLite.

**Base de Datos:**
- Tabla `playlists` - Almacena nombre y fecha
- Tabla `playlist_songs` - Tabla intermedia con canciones

**Métodos:**
- `database` - Inicializa/obtiene la BD SQLite
- `loadPlaylists()` - Carga todas las playlists con sus canciones
- `createPlaylist(name)` - Crea nueva playlist
- `deletePlaylist(id)` - Elimina playlist y sus canciones
- `addSong(playlistId, song)` - Agrega canción a playlist
- `removeSong(playlistId, songId)` - Elimina canción de playlist

**Patrón:** Repository Pattern con ChangeNotifier para reactividad

---

## Servicios

### `services/audio_handler.dart` - Manejador de Audio

**Propósito:** Envolver just_audio y audio_service para reproducción con soporte de background.

**Herencia:** Extiende `BaseAudioHandler` con `QueueHandler` y `SeekHandler`

**Estado:**
- `_player` - Instancia de AudioPlayer (just_audio)
- `_queue` - Cola de reproducción
- `_currentIndex` - Índice de canción actual
- `_errorController` - Stream de errores

**Métodos Principales:**
- `play()` / `pause()` - Control de reproducción
- `seek(position)` - Saltar a posición
- `playSong(song, queue, index)` - Reproducir canción con cola opcional
- `skipToNext()` / `skipToPrevious()` - Siguiente/anterior
- `addToQueue(song)` - Agregar a la cola
- `playNext(song)` - Reproducir después de la actual
- `setRepeatMode(mode)` - Modo de repetición
- `setShuffleMode(mode)` - Modo aleatorio
- `setSpeed(speed)` - Velocidad de reproducción

**Streams:**
- `playingStream` - Estado de reproducción
- `positionDataStream` - Posición, buffer y duración (usa RxDart)
- `errorStream` - Errores de reproducción

**Características:**
- Sincronización con notificación del sistema
- Auto-avance al completar canción
- Manejo de errores con reintento automático

---

### `services/media_scanner.dart` - Escáner de Medios

**Propósito:** Escanear y obtener medios del dispositivo usando on_audio_query.

**Métodos:**
- `requestPermission()` - Solicita permisos de audio/almacenamiento
- `scanSongs()` - Obtiene todas las canciones (filtra < 30 segundos)
- `scanAlbums()` - Obtiene todos los álbumes
- `scanArtists()` - Obtiene todos los artistas
- `songsByArtist(artistId)` - Canciones de un artista
- `albumsByArtist(artistId)` - Álbumes de un artista
- `songsByAlbum(albumId)` - Canciones de un álbum

**Mapeo:** Convierte `SongModel` de on_audio_query a `Song` del dominio

---

### `services/dynamic_theme_service.dart` - Tema Dinámico

**Propósito:** Extraer colores de las carátulas de álbum para personalizar la UI.

**Patrón:** Singleton

**Funcionamiento:**
1. Obtiene la carátula del álbum actual
2. Extrae paleta de colores con `PaletteGenerator`
3. Actualiza colores dominante y vibrante

**Propiedades:**
- `dominantColor` - Color dominante de la carátula
- `accentColor` - Color vibrante para acentos

**Métodos:**
- `updateFromAlbumArt(albumId)` - Actualiza colores desde carátula
- `reset()` - Restablece a colores por defecto

---

## Features (Características)

### `features/library/library_controller.dart` - Controlador de Biblioteca

**Propósito:** Gestionar el estado y lógica de la biblioteca de canciones.

**Estado:**
- `_all` - Todas las canciones escaneadas
- `_filtered` - Canciones filtradas por búsqueda
- `isLoading` - Estado de carga
- `error` - Mensaje de error si ocurre

**Métodos:**
- `scanLibrary()` - Escanea canciones del dispositivo
- `search(query)` - Filtra por título, artista o álbum
- `playSong(song)` - Reproduce canción con toda la biblioteca como cola
- `shuffleAll()` - Mezcla todas las canciones y reproduce

**Patrón:** ChangeNotifier para estado reactivo

---

### `features/library/library_screen.dart` - Pantalla de Biblioteca

**Propósito:** Mostrar lista de canciones con búsqueda y acciones.

**UI Components:**
- AppBar con búsqueda toggle y botón de refresh
- Lista de canciones con indicador de carga/error/vacío
- FloatingActionButton para reproducción aleatoria
- `_SongTile` - Widget de canción con Slidable

**_SongTile:**
- Muestra carátula, título, artista, duración
- Indicador visual de canción en reproducción
- Acción deslizable para agregar a playlist

---

### `features/albums/albums_screen.dart` - Pantalla de Álbumes

**Propósito:** Mostrar grid de álbumes del dispositivo.

**Funcionamiento:**
- Escanea álbumes al iniciar
- GridView de 2 columnas
- Cada álbum muestra carátula, nombre y artista

**_AlbumCard:**
- Navega al detalle del álbum al tocar

---

### `features/albums/album_detail_screen.dart` - Detalle de Álbum

**Propósito:** Mostrar canciones de un álbum específico.

**UI Components:**
- SliverAppBar con carátula expandida
- Información del álbum (cantidad de canciones, artista)
- Botón para reproducir todo
- Lista de canciones
- FloatingActionButton para reproducción aleatoria

**Métodos:**
- `_loadSongs()` - Carga canciones del álbum
- `_playAll()` - Reproduce todas las canciones
- `_shuffleAll()` - Mezcla y reproduce

---

### `features/artists/artists_screen.dart` - Pantalla de Artistas

**Propósito:** Mostrar lista de artistas y sus detalles.

**Componentes:**
- Lista de artistas con conteo de canciones
- `_ArtistTile` - Widget de artista
- `_ArtistDetailScreen` - Detalle con canciones y álbumes del artista

**_ArtistDetailScreen:**
- SliverAppBar con imagen del artista
- Botón para reproducir todo
- Lista de canciones del artista

---

### `features/playlists/playlists_screen.dart` - Gestión de Playlists

**Propósito:** CRUD de listas de reproducción.

**Funcionamiento:**
- Carga playlists al iniciar
- Muestra lista vacía con botón de crear
- Lista de playlists con botón de eliminar

**Métodos:**
- `_showCreate()` - Dialog para crear nueva playlist
- `_confirmDelete()` - Confirmación de eliminación

---

### `features/player/player_controller.dart` - Controlador del Reproductor

**Propósito:** Exponer estado del reproductor y métodos de control.

**Wrapper:** Envuelve AuraAudioHandler con ChangeNotifier

**Propiedades (getters):**
- `currentSong` - Canción actual
- `isPlaying` - Estado de reproducción
- `pos` - Stream de posición
- `queue` - Cola de reproducción
- `currentIndex` - Índice actual
- `accentColor` - Color dinámico de la carátula

**Métodos:**
- `playSong(song, queue)` - Reproducir canción
- `togglePlay()` - Play/Pause
- `next()` / `previous()` - Siguiente/Anterior
- `seek(position)` - Saltar a posición
- `addToQueue(song)` - Agregar a cola
- `playNext(song)` - Reproducir siguiente
- `setRepeat(mode)` - Modo de repetición
- `setShuffle(enabled)` - Modo aleatorio
- `setSpeed(speed)` - Velocidad

---

### `features/player/player_screen.dart` - Pantalla del Reproductor

**Propósito:** UI de pantalla completa para reproducción.

**UI Components:**
- Fondo con gradiente dinámico (color de carátula)
- Barra superior con navegación y opciones
- Carátula con animación de escala
- Información de canción (título, artista)
- Barra de progreso con seek
- Controles principales (anterior, play/pause, siguiente)
- Controles secundarios (shuffle, cola, repeat)

**Estado Local:**
- `_loop` - Modo de repetición actual
- `_shuffle` - Estado del modo aleatorio

**Métodos:**
- `_cycleRepeat()` - Cicla entre off/all/one
- `_showOptions()` - Bottom sheet con opciones
- `_showSongInfo()` - Dialog con información de la canción
- `_showQueue()` - Bottom sheet con cola de reproducción
- `_fmt()` - Formatea duración a MM:SS

**Animaciones:**
- `AnimatedScale` en carátula (escala al pausar/reproducir)
- `SlideTransition` al abrir la pantalla

---

### `features/settings/settings_controller.dart` - Controlador de Ajustes

**Propósito:** Gestionar configuración persistente de la aplicación.

**Persistencia:** SharedPreferences

**Configuraciones:**
- `sleepTimerMinutes` - Duración del temporizador
- `playbackSpeed` - Velocidad de reproducción (0.5x - 2.0x)
- `dynamicThemeEnabled` - Tema dinámico activado/desactivado

**Estado del Temporizador:**
- `_sleepTimerEnd` - Fecha/hora de finalización
- `isSleepTimerActive` - Verifica si está activo
- `sleepTimerRemaining` - Tiempo restante formateado

**Métodos:**
- `init()` - Carga configuración guardada
- `setSleepTimer(minutes)` - Configura temporizador
- `setPlaybackSpeed(speed)` - Configura velocidad
- `setDynamicTheme(enabled)` - Configura tema dinámico
- `checkSleepTimer()` - Verifica y resetea si expiró

---

### `features/settings/settings_screen.dart` - Pantalla de Ajustes

**Propósito:** UI para modificar configuración.

**Secciones:**
1. **Reproducción:**
   - Velocidad de reproducción (picker bottom sheet)
   - Temporizador de sueño (picker bottom sheet)

2. **Apariencia:**
   - Tema dinámico (switch)

3. **Acerca de:**
   - Información de versión (v1.0.0)

**Pickers:**
- Velocidad: 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x
- Temporizador: 0, 5, 15, 30, 45, 60, 90, 120 minutos

---

## Widgets Reutilizables

### `widgets/mini_player.dart` - Mini-Player Flotante

**Propósito:** Mostrar control compacto de reproducción sobre otras pantallas.

**UI Components:**
- BackdropFilter con blur para efecto vidrio
- Carátula pequeña
- Título y artista
- Progress indicator circular
- Controles de play/pause y siguiente

**Navegación:**
- Al tocar, abre PlayerScreen con SlideTransition

**Condición:** Se oculta si no hay canción reproduciéndose

---

### `widgets/song_tile.dart` - Tile de Canción

**Propósito:** Widget reutilizable para mostrar canción en listas.

**Propiedades:**
- `song` - Canción a mostrar
- `onTap` - Callback al tocar
- `showAlbumArt` - Mostrar/ocultar carátula
- `trailing` - Widget personalizado al final
- `enableActions` - Habilitar acciones deslizables

**Funcionamiento:**
- Muestra indicador de reproducción activa
- Slidable con acción para agregar a playlist (si enableActions = true)

---

### `widgets/add_to_playlist_sheet.dart` - Bottom Sheet de Playlist

**Propósito:** Permitir agregar canción a playlist existente o crear nueva.

**UI Components:**
- Lista de playlists disponibles
- Opción para crear nueva playlist
- Mensaje de lista vacía

**Métodos:**
- `show(context, song)` - Método estático para mostrar
- `_addToPlaylist()` - Agrega canción y muestra confirmación
- `_showCreateDialog()` - Dialog para crear nueva playlist

**Feedback:**
- SnackBar de confirmación al agregar
- SnackBar de confirmación al crear playlist

---

## Dependencias y sus Propósitos

| Dependencia | Propósito |
|-------------|-----------|
| `just_audio` | Motor de reproducción de audio |
| `audio_service` | Reproducción en background, notificación, controles hardware |
| `on_audio_query` | Consulta de biblioteca de medios del dispositivo |
| `provider` | Gestión de estado e inyección de dependencias |
| `sqflite` | Base de datos SQLite para playlists |
| `palette_generator` | Extracción de colores de carátulas |
| `flutter_slidable` | Acciones deslizables en listas |
| `permission_handler` | Gestión de permisos de Android |
| `shared_preferences` | Persistencia de configuración |
| `rxdart` | Operadores reactivos (combineLatest3) |

---

## Patrones de Diseño Utilizados

| Patrón | Implementación |
|--------|----------------|
| **Provider** | Gestión de estado en toda la app |
| **ChangeNotifier** | Estado reactivo en controladores |
| **Repository** | PlaylistRepository abstrae SQLite |
| **Service Layer** | AudioHandler, MediaScanner, DynamicThemeService |
| **Feature-first** | Cada feature en carpeta separada |
| **Singleton** | DynamicThemeService |
| **Dependency Injection** | Providers registrados en main.dart |
| **Wrapper/Facade** | PlayerController envuelve AuraAudioHandler |

---

## Flujo de Reproducción

```
1. Usuario toca canción en LibraryScreen
2. LibraryController.playSong() llama a PlayerController
3. PlayerController.playSong() delega a AuraAudioHandler
4. AuraAudioHandler:
   - Actualiza cola (_queue)
   - Establece índice actual (_currentIndex)
   - Carga canción en AudioPlayer (just_audio)
   - Inicia reproducción
5. AudioService actualiza notificación del sistema
6. DynamicThemeService extrae colores de carátula
7. PlayerController notifica cambios a la UI
8. MiniPlayer y PlayerScreen se actualizan
```

---

## Gestión de Estado

La aplicación usa **Provider + ChangeNotifier** para gestión de estado:

```
main.dart (MultiProvider)
├── AuraAudioHandler (Provider)
├── MediaScanner (Provider)
├── PlayerController (ChangeNotifierProvider)
├── LibraryController (ChangeNotifierProvider)
├── PlaylistRepository (ChangeNotifierProvider)
└── SettingsController (ChangeNotifierProvider)
```

Cada controlador notifica cambios con `notifyListeners()` y las pantallas escuchan con `Consumer` o `context.watch()`.
