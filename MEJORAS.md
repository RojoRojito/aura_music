# Mejoras Pendientes - Music App

## 🔴 Prioridad Alta

### 1. Ecualizador Profesional
- [ ] Ecualizador de 12 bandas (31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz)
- [ ] Bass Boost ajustable (0-100%)
- [ ] Virtualizer para sonido 3D espacial
- [ ] Presets predefinidos (Plano, Rock, Pop, Jazz, Clásica, Hip-Hop, Electrónica, Latino)
- [ ] Guardar configuraciones personalizadas por usuario
- [ ] Activar/desactivar EQ desde el reproductor
- [ ] API de IA para recomendaciones de configuración de EQ basadas en hábitos de escucha

### 2. Recomendador Inteligente con IA
- [ ] Sistema de tracking de historial de reproducción (play_count, duración, skips)
- [ ] Algoritmo local de scoring (play_count, completion_rate, recency, variety)
- [ ] Modo shuffle inteligente (recomendaciones basadas en preferencias, no aleatorio puro)
- [ ] Filtro para excluir audios no musicales (WhatsApp, Telegram, voice notes, podcasts)
- [ ] API externa de IA para sugerir canciones y configuraciones de EQ
- [ ] Estadísticas de canciones más escuchadas y tiempo de reproducción
- [ ] Evitar repetir artista/álbum en corto período

### 3. Manejo de errores y estados edge ✅
- [x] No hay manejo cuando no hay permisos de audio
- [x] La cola puede quedar vacía sin feedback visual claro
- [x] `_loadCurrent()` silence fallbacks si no hay internet o archivo corrupto

### 4. Persistencia de estado ✅
- [x] El `SettingsController` nunca llama a `init()` en main.dart
- [x] La cola no se guarda entre sesiones (pierdes reproducción al cerrar app)
- [x] No hay caché de álbum/artist para reducir queries

### 5. Control de reproducción ✅
- [ ] No hay soporte para letras (Lyrics)
- [x] El sleep timer está incompleto (solo configura, no actúa)

---

## 🟡 Prioridad Media

### 6. UX/UI
- [ ] No hay animaciones de transición entre pantallas
- [ ] El mini-player no tiene controles de swipe
- [ ] Falta soporte para gestos (swipe para skip, long-press para cola)
- [ ] Dark mode únicamente — no hay tema claro

### 7. Búsqueda limitada
- [ ] La búsqueda solo funciona en library, no en albums/artistas/playlists

### 8. Playlists básico
- [ ] No hay reorder de canciones
- [ ] No se puede editar nombre de playlist
- [ ] No hay exportación/importación de playlists

---

## 🟢 Prioridad Baja

### 9. Features adicionales
- [ ] Sleep timer con fade out
- [ ] Mostrar artwork en notifications

### 10. Performance
- [ ] `QueryArtworkWidget` hace queries repetitivos
- [ ] No hay lazy loading en listas grandes

---

## Notas adicionales

> Espacio reservado para mejoras adicionales que se identifiquen durante el desarrollo.