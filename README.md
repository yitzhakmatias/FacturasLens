# FacturaLens

Aplicación Flutter para capturar, revisar y analizar facturas localmente. Usa
OCR, lectura de QR y una base de datos SQLite; ninguna factura se envía a un
servicio remoto.

## Requisitos del trabajo final

| Directiva | Evidencia en FacturaLens |
| --- | --- |
| Persistencia local y 3 tablas relacionadas | SQFlite con `suppliers`, `categories`, `invoices`, `invoice_items` e `invoice_images`. Las facturas se relacionan con proveedor/categoría y sus productos e imágenes. |
| Arquitectura | Arquitectura limpia práctica: `domain` (entidades y puertos), `application` (servicios y ViewModels), `infrastructure` (SQLite/OCR) y `presentation` (pantallas/widgets). Provider implementa MVVM. |
| CRUD, reportes y estadísticas | CRUD de facturas, proveedores y categorías; panel con métricas y pantalla de análisis con gráficos. |
| UI solicitada | Tema propio, rutas con nombre, `ListView`, `GridView`, transición `Hero`, animación de métricas y cabecera inicial con curvas. |

## Ejecución

```bash
flutter pub get
flutter run
```

En iOS, acepta los permisos de cámara y galería. En Android, acepta el
permiso de cámara para escanear documentos y QR.

## Verificación

```bash
flutter analyze
flutter test
flutter build windows
```

## Guion sugerido para el video

1. Preséntate en cámara y menciona los autores.
2. Muestra el escaneo o carga de una factura, el OCR, el QR y la revisión.
3. Demuestra crear, editar y eliminar una factura, proveedor o categoría.
4. Muestra el panel de estadísticas, reportes y el almacenamiento local.
5. Explica brevemente las capas `domain`, `application`, `infrastructure` y
   `presentation` junto con las tablas SQLite.
6. Mantén visible la cámara del expositor durante toda la demostración y envía
   el enlace del video a `jtancara@ucb.edu.bo`, indicando claramente autor(es).
