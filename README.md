# Posbarber 💈

Posbarber es un sistema de Punto de Venta (POS) premium, diseñado específicamente para barberías y estéticas modernas. Desarrollado en Flutter, ofrece un diseño sofisticado ("Luxury"), velocidad impecable y funcionamiento multiplataforma (Web PWA, Windows, Linux, Android, iOS).

## Características Principales 🌟
- **Punto de Venta (POS) Rápido:** Gestión de carrito, cálculo automático de propinas/subtotales y cobro ágil.
- **Gestión de Personal con Roles:**
  - `Dueño / Admin:` Acceso a todo el sistema, inventario, reportes globales e incorporación de personal.
  - `Barbero Jefe:` Acceso a cobros y reportes consolidados (ideal para supervisores de turno).
  - `Barbero / Empleado:` Acceso restringido únicamente a la caja para realizar ventas.
- **Inventario Dinámico:** Base de datos SQLite local pre-configurada con servicios predeterminados editables desde la interfaz (ej. *Barba, Color global, Corte clásico*).
- **Seguridad y Accesos:** 
  - Primer ingreso con forzado de cambio de clave.
  - Autenticación kilométrica de un solo toque mediante **Face ID / Huella Dactilar**.
  - Envío automatizado de credenciales temporales vía correo electrónico.
- **Soporte Offline & PWA:** Totalmente operable sin internet en equipos de escritorio y fácilmente instalable ("Add to Home Screen") desde navegadores móviles.

---

## Capturas de Pantalla 📸

*(Aquí puedes arrastrar y soltar las capturas de cada una de tus vistas para mostrar el diseño final)*

### 1. Pantalla de Login (Previa / Biometría)
> `[Reemplazar con captura de login_page]`

### 2. Tablero Principal de Ventas (Punto de Venta)
> `[Reemplazar con captura de pos_page]`

### 3. Gestión de Inventario y Precios
> `[Reemplazar con captura de inventario]`

### 4. Administración de Staff y Roles
> `[Reemplazar con captura de staff]`

---

## 🚀 Guía Rápida de Despliegue (Docker PWA)

El proyecto viene preparado con un ecosistema `docker-compose` listo para engancharse a un Nginx Proxy Manager (NPM).

### Requisitos
- Servidor con Docker y Docker Compose instalados.
- Un servidor NPM (Nginx Proxy Manager) corriendo en una red externa llamada `npm_network` (o modifica el archivo compose si tu red tiene otro nombre).

### Instrucciones de Despliegue
1. Clona el repositorio en tu servidor:
   ```bash
   git clone https://github.com/usuario/posbarber.git
   cd posbarber
   ```
2. Inicia el contenedor (esto compilará Flutter Web automáticamente en un entorno Multi-stage de Docker):
   ```bash
   docker-compose up -d --build
   ```
3. El contenedor "posbarber_web" se ejecutará internamente en el puerto `80`. Configura tu Nginx Proxy Manager para apuntar tus dominios (ej. `pos.mibarberia.com`) al puerto interno de este contenedor.

### ¿Qué hace internamente?
- **Paso 1:** Un contenedor temporal compila la aplicación usando el motor súper optimizado `canvaskit` de Flutter Web.
- **Paso 2:** Pasa todo el código `.js`, `.css` y `.html` minimizado a un pequeño servidor web `Nginx Alpine`.
- El archivo interno `nginx.conf` se encarga de forzar el enrutamiento SPA (para que al recargar la página web no tire error `404`) y activa la compresión nativa `Gzip` de los Assets para cargas inmediatas.

---

## 🗄️ Información de la Base de Datos Local
El sistema utiliza **SQFlite** con FFI para compatibilidad multiplataforma. La información queda almacenada de forma persistente y local en el dispositivo/navegador.

**Servicios por defecte en DB (al iniciar 1ra vez):**
- Barba
- Color Mechitas
- Color Global

*(Si necesitas borrar los datos obsoletos, entra con el usuario Dueño, presiona "Reportes", y usa el botón de "Peligro: Resetear Base de Datos").*
