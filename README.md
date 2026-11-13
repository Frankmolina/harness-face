# Harness Face

Una cara mínima para DeepSeek Harness: una máscara flotante siempre visible y
**Alt+V** global para traer Harness al frente.

## Estado

- Máscara always-on-top, sin icono en el Dock; se encoge al pasar el ratón.
- Clic izquierdo: abre/enfoca **DeepSeek Harness**.
- Clic derecho: menú para abrir Harness o salir.
- **Alt+V** global: trae Harness y empieza a dictar en español con Speech nativo.
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
