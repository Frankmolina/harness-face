# Harness Face

Una cara mínima para DeepSeek Harness: una máscara flotante siempre visible y
**Alt+V** global para traer Harness al frente.

## Estado

- Máscara always-on-top, sin icono en el Dock; se encoge al pasar el ratón.
- Clic izquierdo: abre/enfoca **DeepSeek Harness**.
- Clic derecho: menú para abrir Harness o salir.
- **Alt+V** global: trae Harness y empieza a dictar en español con Whisper local.
- **Alt+R lee en voz alta**: usa la selección actual de Harness (o el portapapeles si no hay selección) y la lee con la voz del sistema, sin nube. Otra pulsación la calla.
- **Wake word «Veniron»**: escucha local continua; al oírla abre Harness y empieza a dictar. Alt+V sigue como respaldo.
- La posición de la máscara se recuerda entre arranques.
- Al iniciar sesión se arranca por defecto; el menú contextual permite desactivarlo.
- **Conversación continua**: tras dictar, corta por silencio, envía con Enter, espera 8 s y vuelve a escuchar; se desactiva en el menú de la máscara.
- **Pausar escucha**: corta el micrófono sin cerrar la app; la máscara muestra una insignia de pausa y se reanuda desde el mismo menú.
- El dictado acaba en el portapapeles y se pega en el chat de Harness con Cmd+V; no envía.
- macOS pedirá permiso de micrófono/reconocimiento de voz la primera vez, y Accesibilidad para pegar. Sin Accesibilidad el texto queda en el portapapeles.
- No habla con Harness por API: solo activa la app existente.

## Compilar

```sh
./build.sh
open "build/Harness Face.app"
```

macOS 13 o superior. Si existe el certificado local `VENIRON Dev`, el script
firma con él; si no, usa firma ad hoc.

## Límites de esta primera versión

- No dibuja el chat ni habla con el WebSocket de Harness.
- No tiene voz ni dictado.
- Solo macOS.

## Licencia

MIT.
