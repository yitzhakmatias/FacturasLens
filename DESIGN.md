# FacturaLens — sistema visual

## Dirección

Interfaz financiera clara y confiable inspirada en Paychain: fondo gris muy
claro, superficies blancas, índigo como acción principal, violeta como acento
y tarjetas amplias con esquinas suaves. La identidad y los recursos gráficos
son propios de FacturaLens.

## Tokens

- Fondo: `#F6F7FB`; superficie: `#FFFFFF`; borde: `#E6E7EF`.
- Texto: `#171A2B`; secundario: `#73778A`.
- Primario: `#5557E8`; suave: `#EBEBFF`; acento: `#8B5CF6`.
- Éxito: `#16A085`; advertencia: `#F59E0B`; error: `#E05252`.
- Radios: 14 px para controles y 22–24 px para superficies.
- Espaciado base: 4 px; intervalos de 12, 16, 20, 24 y 28 px.

## Componentes y responsive

- Botones índigo de 52 px, sin gradiente ni elevación marcada.
- Navegación móvil inferior blanca y panel lateral flotante desde 860 px.
- Tarjetas blancas con borde sutil; color sólido solo para datos destacados.
- Formularios blancos con borde gris e indicador índigo al enfocar.
- Menos de 860 px: navegación inferior; desde 860 px: panel de 250 px.

## Alcance

Este sistema gobierna solamente `lib/presentation`. No modifica entidades,
puertos, repositorios, persistencia, OCR ni casos de uso.
