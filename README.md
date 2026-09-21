# FacturaLens

**Autor:** Yitzhak Matias  
**Proyecto:** Trabajo final de Flutter con persistencia local

FacturaLens es una aplicación Flutter para capturar, revisar, organizar y
analizar facturas de compra. Utiliza OCR para extraer datos desde una imagen,
lectura de códigos QR y una base de datos SQLite local. La información se
mantiene en el dispositivo y no requiere un servidor remoto.

## Problema que resuelve

Las facturas y tickets impresos se pueden perder o deteriorar. Además, el
registro manual de gastos en una hoja de cálculo dificulta consultar el
historial de compras, agrupar gastos por categoría y calcular totales. Con
FacturaLens, el usuario digitaliza el comprobante, revisa los datos extraídos y
consulta sus gastos desde la misma aplicación.

## Funcionalidades

- Captura de facturas mediante cámara, galería o imagen de ejemplo.
- Reconocimiento de texto con Google ML Kit y lectura de códigos QR.
- Revisión manual de proveedor, NIT, fecha, productos, importes y categoría.
- CRUD completo para facturas, proveedores y categorías.
- Búsqueda, filtros por estado y categoría, y ordenamiento de facturas.
- Reportes de gasto mensual, ticket promedio, impuestos, facturas pendientes,
  tendencia semestral y distribución por proveedor o categoría.
- Eliminación de imágenes temporales si una captura se descarta antes de ser
  guardada.

## Arquitectura

El proyecto aplica una arquitectura limpia práctica con Provider y el patrón
MVVM. Cada capa tiene una responsabilidad definida:

```text
lib/
├── domain/          Entidades y contratos independientes de plugins
├── application/     ViewModels y lógica de aplicación
├── infrastructure/  SQLite, OCR, cámara, galería y archivos locales
└── presentation/    Pantallas, widgets, tema, rutas y navegación
```

- **Domain:** define entidades como `Invoice`, `Supplier` e `InvoiceCategory`.
  También contiene los puertos `InvoiceRepository`, `CatalogRepository` y
  `DocumentCapturePort`.
- **Application:** incluye `InvoicesViewModel`, `CaptureViewModel` y
  `ReceiptParser`. Los ViewModels coordinan el estado que usa la interfaz.
- **Infrastructure:** implementa los puertos del dominio con
  `SqliteInvoiceRepository`, `AppDatabase` y
  `MlKitDocumentCaptureAdapter`.
- **Presentation:** contiene las pantallas del dashboard, captura, facturas,
  catálogos y análisis; además de widgets reutilizables y el tema visual.

`main.dart` registra las dependencias con `MultiProvider`. De esta forma, las
pantallas no realizan consultas SQLite ni llaman directamente a plugins de
cámara u OCR.

## Persistencia local

La base de datos `facturalens.db` usa SQFlite y contiene cinco tablas:

| Tabla | Propósito | Relación |
| --- | --- | --- |
| `suppliers` | Comercios, NIT, dirección y teléfono. | Un proveedor puede tener varias facturas. |
| `categories` | Clasificaciones de gasto y color. | Una categoría puede agrupar varias facturas. |
| `invoices` | Número, fecha, importes, estado y proveedor. | Tabla central. |
| `invoice_items` | Productos, cantidades y precios. | Varias filas pertenecen a una factura. |
| `invoice_images` | Rutas de imágenes y texto OCR. | Varias imágenes pertenecen a una factura. |

Las relaciones se protegen con claves foráneas. Los ítems y las imágenes se
eliminan en cascada cuando se elimina una factura. El repositorio usa
transacciones para guardar una factura junto con sus detalles e imágenes.

## Interfaz Flutter

FacturaLens incorpora los componentes solicitados para la interfaz:

- `AppTheme` centraliza colores, tipografía y estilos de controles.
- `AppRoutes` implementa rutas con nombre para captura y detalle de factura.
- `ListView` muestra facturas, formularios y catálogos.
- `GridView` presenta las métricas principales en el dashboard.
- `Hero` anima la transición visual desde una factura a su detalle.
- `AnimatedSwitcher` anima la actualización de métricas.
- La pantalla inicial incluye una cabecera personalizada con curvas y diseño
  adaptable para móvil y escritorio.

## Cumplimiento del trabajo final

| Directiva | Implementación |
| --- | --- |
| Persistencia local con tres tablas relacionadas | SQFlite con cinco tablas relacionadas. |
| Arquitectura limpia, GetX o Riverpod | Arquitectura por capas con Provider y MVVM. |
| CRUD, reportes y estadísticas | CRUD de facturas, proveedores y categorías; dashboard y pantalla de análisis. |
| Componentes Flutter solicitados | Theme, rutas, ListView, GridView, Hero, animaciones y pantalla inicial personalizada. |

## Ejecución

```bash
flutter pub get
flutter run
```

En iOS se deben aceptar los permisos de cámara y galería. En Android se debe
aceptar el permiso de cámara para escanear documentos y códigos QR.

## Verificación

```bash
flutter analyze
flutter test
flutter build windows
```

## Documentación

- `docs/FacturaLens_Trabajo2.pptx`: presentación técnica inicial.
- `docs/Informe_Trabajo_Final_FacturaLens.docx`: informe técnico del proyecto.
- `docs/Guion_Exposicion_Individual_FacturaLens.docx`: guion de exposición.
- `docs/Guion_Exposicion_Individual_FacturaLens.pptx`: presentación para la
  exposición individual.
