# Clima INIFAP Zacatecas

Aplicación para consultar información del clima registrada por las estaciones del INIFAP Zacatecas. Permite ver datos actuales, información de días anteriores, reportes, un mapa, hasta tres estaciones favoritas y alertas de clima extremo. También guarda la última información disponible para mostrarla cuando no hay internet.

> **Manual completo:** [docs/Manual_tecnico_INIFAP.pdf](docs/Manual_tecnico_INIFAP.pdf)
>
> **Fuente editable del manual:** [docs/Manual_tecnico_INIFAP.html](docs/Manual_tecnico_INIFAP.html)

## Estado y alcance

- Está hecha con Flutter y Dart. La versión principal es la de Android.
- API institucional: `https://zacatecas.inifap.gob.mx/apiApp2.php`.
- El servidor puede responder con el error `403` y bloquear la consulta. Cuando eso ocurre, la aplicación intenta leer una copia de respaldo guardada en GitHub.
- Android revisa cada cierto tiempo las estaciones favoritas y muestra alertas locales cuando encuentra temperaturas, lluvia o viento fuera de los límites configurados.
- La copia de respaldo está en la rama `notifications`. Si la rama cambia, también debe cambiarse `_kMirrorUrl`.

## Arranque rápido

Requisitos recomendados:

- Flutter compatible con Dart `^3.6.1`.
- Android SDK y un emulador o dispositivo con depuración USB.
- Node.js para ejecutar el scraper localmente.

```bash
flutter doctor
flutter pub get
flutter run
```

Para generar un APK:

```bash
flutter build apk --release
```

Salida esperada: `build/app/outputs/flutter-apk/app-release.apk`.

Antes de entregar cambios:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

La prueba incluida en `test/widget_test.dart` todavía es la plantilla del contador y no corresponde a la interfaz actual; debe reemplazarse antes de considerar verde la suite.

## Cómo funciona en una mirada

```text
API INIFAP ──► OfflineDataService.sharedClient ──► pantallas Flutter
     │                    │
     │ 403                ├──► caché local / SharedPreferences
     ▼                    │
GitHub Actions ─► data/latest.json ─► espejo raw de GitHub
     │
Puppeteer cada 15 min
```

La aplicación pregunta primero al servidor del INIFAP. Si el servidor responde `403` o no hay conexión, `_WafFallbackClient` busca la misma información dentro de `data/latest.json`, que es la copia guardada en GitHub. Las pantallas también conservan en el teléfono los últimos datos que sí funcionaron.

## Mapa del repositorio

| Ruta | Responsabilidad |
|---|---|
| `lib/main.dart` | Abre la aplicación, prepara las notificaciones y comienza la actualización de datos. |
| `lib/WeatherProxyPage.dart` | Pantalla principal, selección de estación y consulta `r=5`. |
| `lib/services/station_service.dart` | Obtiene la lista de estaciones y guarda la última lista que funcionó. |
| `lib/data/Stations.dart` | Lista de estaciones incluida dentro de la aplicación: ID y nombre. |
| `lib/data/lat_and_long_cords.dart` | Coordenadas utilizadas por el mapa. |
| `lib/bin/generate_offline.dart` | Decide entre servidor y respaldo, y guarda información para usarla sin internet. |
| `lib/cards_under_daily_extras.dart` | Lluvia, humedad, radiación y viento (`r=6..9`). |
| `lib/station_history.dart` | Histórico mensual (`r=10`). |
| `lib/report.dart` | Reportes generales (`r=1`, `r=3`, `r=4`). |
| `lib/widgets/maps.dart` | Mapa OSM y marcadores por coordenadas. |
| `lib/widgets/favorite_stations.dart` | Favoritos y claves de `SharedPreferences`. |
| `lib/notifications/rain_check_worker.dart` | Umbrales y alertas periódicas. |
| `scripts/scrape.js` | Obtiene el espejo con Puppeteer; contiene su propia lista de IDs. |
| `.github/workflows/scrape-inifap.yml` | Ejecuta el scraper cada 15 minutos y publica el JSON. |
| `data/latest.json` | Última instantánea publicada; no se edita a mano. |
| `android/app/src/main/AndroidManifest.xml` | Permisos Android y metadatos de notificaciones. |

## Qué información pide la aplicación al servidor

El valor `r` funciona como una opción de menú. Le dice al servidor qué información necesita la aplicación:

| `r` | Uso | Parámetros adicionales |
|---:|---|---|
| `all` | Catálogo o lectura global según respuesta del servidor | ninguno |
| `1` | Reporte de tiempo real | ninguno |
| `3` | Resumen en tiempo real | ninguno |
| `4` | Avance mensual | ninguno |
| `5` | Tiempo real de una estación | `day`, `month`, `year`, `id_est_given` |
| `6` | Precipitación diaria | mismos parámetros |
| `7` | Humedad diaria | mismos parámetros |
| `8` | Radiación diaria | mismos parámetros |
| `9` | Viento diario | mismos parámetros |
| `10` | Histórico mensual | `month`, `year`, `id_est_given` |

Ejemplo:

```text
https://zacatecas.inifap.gob.mx/apiApp2.php?r=5&day=29&month=09&year=2026&id_est_given=18851
```

No invente nombres para los datos. Primero guarde una respuesta real del servidor y revise cómo la leen las funciones actuales.

## Cómo agregar una estación

Una estación debe usar **el mismo ID numérico en todos los archivos y consultas**. El ID es el número que identifica a la estación. Si se repite o se escribe diferente, la aplicación puede mostrar el nombre de una estación con los datos de otra.

### 1. Confirmar la estación en el servidor

Confirme con el responsable de INIFAP:

- ID oficial.
- Nombre que se mostrará.
- Latitud y longitud decimales.
- Respuesta válida para `r=5`, `r=6`, `r=7`, `r=8`, `r=9` y `r=10`.

### 2. Agregarla a la lista incluida en la aplicación

En `lib/data/Stations.dart`:

```dart
const List<Station> kStations = [
  // ...
  Station(12345, 'Municipio, Nombre de la estación'),
];
```

Aunque el servidor pueda enviar la estación mediante `r=all`, esta lista sigue siendo necesaria para que aparezca cuando no hay internet o el servidor falla.

### 3. Agregar las coordenadas

En `lib/data/lat_and_long_cords.dart`:

```dart
const Map<int, LatLng> kStationCoords = {
  // ...
  12345: LatLng(22.770000, -102.570000),
};
```

Sin coordenadas la estación puede aparecer en el selector, pero `maps.dart` omite su marcador.

### 4. Incluirla en la copia de respaldo de GitHub

En `scripts/scrape.js`, agregue el ID a `STATION_IDS`:

```js
const STATION_IDS = [
  // ...
  12345,
];
```

Esto permite guardar los datos actuales, diarios y mensuales de la nueva estación. La copia se utiliza cuando el servidor responde con el error 403.

### 5. Actualizar y comprobar la copia de respaldo

Puede ejecutar localmente:

```bash
cd scripts
npm install
node scrape.js
```

También puede abrir la sección Actions de GitHub y ejecutar manualmente **Scrape INIFAP (bypass WAF)**. Después, en `data/latest.json` deben existir estas partes:

```text
realtime.12345
daily.12345.r6
daily.12345.r7
daily.12345.r8
daily.12345.r9
history.12345
```

No edite `data/latest.json` manualmente: la siguiente ejecución automática reemplazará esos cambios.

### 6. Borrar la lista vieja y probar

El teléfono puede conservar una lista anterior de estaciones. Borre los datos de la aplicación o reinstálela y compruebe:

- Selector principal y consulta actual.
- Tarjetas de lluvia, humedad, radiación y viento.
- Histórico del mes.
- Marcador del mapa.
- Alta y baja de favoritos.
- Uso sin internet después de consultar con internet.
- Alertas si la estación es favorita.
- Entrada correspondiente en `data/latest.json`.

### Lista final antes de guardar o subir el cambio

- [ ] ID confirmado con INIFAP y sin repetir.
- [ ] `Stations.dart` actualizado.
- [ ] `lat_and_long_cords.dart` actualizado.
- [ ] `scripts/scrape.js` actualizado.
- [ ] Respuestas `r=5..10` verificadas.
- [ ] Copia de GitHub creada sin errores.
- [ ] Mapa, favoritos, histórico y funcionamiento sin internet probados.
- [ ] `dart format`, `flutter analyze` y `flutter test` ejecutados.

## Hallazgo conocido: Chaparrosa

Actualmente `Stations.dart` asigna `18837` tanto a **Villa de Cos, Chaparrosa** como a **Villa de Cos, Sierra Vieja**. En cambio, `lat_and_long_cords.dart` usa `18783` para Chaparrosa y `18837` para Sierra Vieja. El programa que crea la copia de GitHub contiene `18837` una sola vez.

No se corrigió automáticamente porque el ID debe confirmarse con INIFAP. Si se confirma que Chaparrosa usa `18783`, cambie ese número en `Stations.dart`, agréguelo a `STATION_IDS`, vuelva a crear la copia de GitHub y borre los datos guardados de la aplicación.

## Cómo funciona sin internet

Nombres internos de los datos pequeños que se guardan en el teléfono:

| Clave | Contenido |
|---|---|
| `stations_cache_r_all` | Catálogo dinámico. |
| `last_station_id` | Última estación seleccionada. |
| `cache_<id>_<fecha>` | Respuesta `r=5` del día. |
| `favorite_station_ids` | IDs favoritos; la UI limita a tres. |
| `notif_enabled` | Estado de notificaciones asociado a favoritos. |
| `offline_data_json` | Copia completa para funcionar sin internet en web. |

En teléfono o computadora, la información se guarda en un archivo llamado `offline_data.json`, dentro de la carpeta privada de la aplicación. Contiene reportes, históricos, información diaria y datos actuales.

Orden que sigue la aplicación:

1. Mostrar los últimos datos guardados, si existen.
2. Preguntar al servidor mediante `OfflineDataService.sharedClient`.
3. Si aparece el error `403`, intentar la copia de GitHub.
4. Si todo falla, conservar y mostrar la última información disponible.

## Cómo se actualiza la copia de GitHub

El archivo `.github/workflows/scrape-inifap.yml` pide a GitHub que ejecute una tarea aproximadamente cada 15 minutos. La tarea abre un navegador automático, consulta la información, vuelve a crear `data/latest.json` y guarda el cambio si el contenido es diferente.

Puntos que deben revisarse:

- Requiere permiso `contents: write` habilitado para GitHub Actions.
- Una rama protegida puede impedir que la tarea automática guarde el archivo.
- `_kMirrorUrl` apunta a `JoelSANQ/inifap/notifications/data/latest.json`; repositorio, propietario, rama y ruta deben permanecer alineados.
- `r=all` puede venir vacío; el programa continúa y la aplicación usa `kStations`.
- La copia sólo contiene el mes y el día de su actualización más reciente.

## Alertas

Android intenta revisar las estaciones favoritas aproximadamente cada 15 minutos. También espera al menos 15 minutos antes de repetir el mismo tipo de alerta para una misma estación:

| Condición | Umbral |
|---|---:|
| Helada | temperatura `< 0 °C` |
| Calor extremo | temperatura `> 38 °C` |
| Viento fuerte | velocidad `> 23 km/h` |
| Lluvia | precipitación `>= 1.0 mm` |

Android puede retrasar la revisión para ahorrar batería. Cuando no hay internet, los datos guardados de `r=5` no incluyen viento, por lo que la alerta de viento no puede calcularse. Algunos comentarios del código dicen cinco minutos, pero la operación real usa 15 minutos.

## Versión web y servicios auxiliares

- En web, las pantallas pasan las consultas por `http://localhost:8080/<URL-INIFAP>`. Esto necesita un programa auxiliar en la computadora, pero dicho programa no está incluido en el repositorio.
- `functions/index.js` sólo expone `helloTest`; no implementa la obtención meteorológica.

## Diagnóstico rápido

| Síntoma | Revisar |
|---|---|
| Estación no aparece | respuesta `r=all`, `stations_cache_r_all` y `Stations.dart`. |
| Aparece pero no está en mapa | ID y coordenadas en `kStationCoords`. |
| Funciona con internet, pero falla con `403` | `STATION_IDS`, tarea de GitHub, rama de `_kMirrorUrl` y contenido del archivo. |
| Dos nombres comparten datos | IDs duplicados. |
| Histórico vacío | `r=10`, mes/año solicitados y cobertura del espejo. |
| Web intenta `localhost:8080` | falta el proxy web esperado por `_buildProxyUrl`. |
| No llegan alertas | permisos, favoritos, WorkManager, ahorro de batería y umbrales. |
| GitHub no publica el archivo | permisos de Actions, protección de rama o error al consultar el servidor. |

## Reglas de mantenimiento

- Haga todas las consultas nuevas mediante `OfflineDataService.sharedClient`; ese servicio sabe cambiar a la copia de GitHub cuando el servidor bloquea la aplicación.
- No cambie los nombres de los datos guardados sin preparar una forma de convertir la información anterior.
- No use un ID inventado o sólo basado en el nombre visible.
- Actualice este README y el manual cuando cambien las consultas, los límites de alertas, los datos guardados, la rama o el proceso para agregar estaciones.

## Responsable de transferencia

- Proyecto académico: aplicación móvil para monitoreo agroclimático del INIFAP Zacatecas.
- Estudiante: Joel Del Jesus Sanchez Quintal.
- Asesor interno: Adrián Martín Aguilar Vargas.
- Organizaciones: Fundación DEDICA e INIFAP.
- Periodo: Modelo de Formación Dual, 2026.
