# Mejoras Pendientes - Music App

## 🔴 Prioridad Alta

### 1. Manejo de errores y estados edge
- [ ] No hay manejo cuando no hay permisos de audio
- [ ] La cola puede quedar vacía sin feedback visual claro
- [ ] `_loadCurrent()` silence fallbacks si no hay internet o archivo corrupto

### 2. Persistencia de estado
- [ ] El `SettingsController` nunca llama a `init()` en main.dart
- [ ] La cola no se guarda entre sesiones (pierdes reproducción al cerrar app)
- [ ] No hay caché de álbum/artist para reducir queries

### 3. Control de reproducción
- [ ] No hay soporte para letras (Lyrics)
- [ ] No hay equalizer/ajuste de audio
- [ ] El sleep timer está incompleto (solo configura, no actúa)

---

## 🟡 Prioridad Media

### 4. UX/UI
- [ ] No hay animaciones de transición entre pantallas
- [ ] El mini-player no tiene controles de swipe
- [ ] Falta soporte para gestos (swipe para skip, long-press para cola)
- [ ] Dark mode únicamente — no hay tema claro

### 5. Búsqueda limitada
- [ ] La búsqueda solo funciona en library, no en albums/artistas/playlists

### 6. Playlists básico
- [ ] No hay reorder de canciones
- [ ] No se puede editar nombre de playlist
- [ ] No hay exportación/importación de playlists

---

## 🟢 Prioridad Baja

### 7. Features adicionales
- [ ] Soporte para podcasts
- [ ] Sleep timer con fade out
- [ ] History/recently played
- [ ] Shuffle inteligente (no aleatorio puro)
- [ ] Mostrar artwork en notifications

### 8. Performance
- [ ] `QueryArtworkWidget` hace queries repetitivos
- [ ] No hay lazy loading en listas grandes

---

## Notas adicionales

> Espacio reservado para mejoras adicionales que se identifiquen durante el desarrollo.
