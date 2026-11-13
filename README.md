# Harness Face

Una cara mínima para DeepSeek Harness: una máscara flotante siempre visible y
**Alt+V** global para traer Harness al frente.

## Estado

- Máscara always-on-top, sin icono en el Dock; se encoge al pasar el ratón.
- Clic izquierdo: abre/enfoca **DeepSeek Harness**.
- Clic derecho: menú para abrir Harness o salir.
- **Alt+V** global: lo mismo, desde cualquier app.
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
