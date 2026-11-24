# Decisiones de diseño

Cada decisión con lo que se descartó y por qué. Se agregan a medida que avanza el proyecto.

## Producto

### Entregar un documento es una búsqueda exacta, no RAG

- **Decisión:** catálogo en una planilla (tipo + período + archivo). El modelo sólo interpreta
  el pedido y llama a una herramienta `buscar_documento(tipo, periodo)`.
- **Descartado:** indexar los PDFs en un vector store y buscar por similitud.
- **Por qué:** la búsqueda semántica devuelve lo *parecido*. El F.931 de mayo y el de junio son
  casi idénticos: un RAG devolvería el equivocado con total confianza. En un control documental,
  un documento del mes equivocado es peor que ninguno.
- **RAG queda para:** preguntas sobre el *contenido* de documentos libres ("¿cuándo vence la
  cuota 4 del plan?"), con cita de la fuente y la regla de responder "No sé" si el dato no está.

### El catálogo se arma solo desde el nombre del archivo

- **Decisión:** convención `AAAA-MM_TIPO.ext` (y `AAAA-MM_RECIBO_<CUIL>.pdf` para recibos). Un
  workflow vigila la carpeta y cataloga cada archivo nuevo; si el nombre no se entiende, avisa.
- **Descartado:** cargar cada archivo a mano en la planilla.
- **Por qué:** con un año de historia son cientos de archivos. Para quien carga, el trabajo es
  *renombrar y soltar*.

### El modelo nunca ve el contenido de un documento que se entrega

- **Por qué:** un recibo de sueldo o un F.931 con detalle por CUIL son datos personales de
  empleados. El archivo va del Drive al chat directamente. Esto, además, permite arrancar el MVP
  con un modelo de tier gratuito: el modelo sólo ve "mandame el 931 de junio".

### Permisos por tercero, con códigos de invitación de un solo uso

- **Decisión:** cada tercero (operadora, gestora, proveedor) declara qué tipos de documento
  puede ver. Cada persona recibe un código de un solo uso que vincula su cuenta de Telegram.
- **Descartado:** una clave por proveedor.
- **Por qué:** una clave se reenvía por mail, la sigue usando alguien que ya no trabaja ahí, y no
  hay forma de saber quién la usó. Con el código, la identidad pasa a ser la cuenta de Telegram, y
  dar de baja a alguien es una celda en la planilla.

## Infraestructura

### VPS propio con n8n self-hosted

- **Descartado:** n8n Cloud; correr n8n en plataformas serverless.
- **Por qué:** control de dónde viven los datos, costo fijo bajo, y un mismo servidor sirve para
  varios clientes. Las plataformas serverless no corren un proceso de Node permanente con base
  de datos.

### Hetzner, en Helsinki, el plan de 2 GB

- **Por qué Helsinki:** la Unión Europea tiene protección "adecuada" para la Ley 25.326; mandar
  datos de empleados argentinos ahí es más fácil de justificar que a EE. UU. Y era la opción más
  barata. La latencia hasta Argentina no le importa a un bot.
- **Por qué 2 GB y no 4:** n8n + Postgres + el túnel usan ~700 MB en reposo. Con 2 GB de swap y
  los archivos binarios de n8n en disco (no en RAM), alcanza para el MVP. Agrandar el servidor
  después lleva unos minutos, sin reinstalar.

### Cloudflare Tunnel + Access, sin puertos abiertos

- **Decisión:** el servidor no abre ningún puerto para n8n. `cloudflared` sale hacia Cloudflare;
  Cloudflare pone el HTTPS y el certificado. El editor queda detrás de Access (código por mail);
  sólo `/webhook/*` queda público para que Telegram pueda entregar los mensajes.
- **Descartado:** Nginx + Let's Encrypt con los puertos 80/443 abiertos.
- **Por qué:** menos superficie de ataque y una URL estable, que Telegram necesita para su webhook.
- **Orden de configuración:** primero el candado (Access), después la puerta (el túnel). La
  primera persona que abre un n8n nuevo crea la cuenta de dueño.

### Postgres, no SQLite

- **Por qué:** backups con `pg_dump` consistentes en caliente, y es lo que recomienda n8n para
  producción.

## Backups y alertas

### Backups cifrados con age, en Cloudflare R2 (UE)

- **Decisión:** `pg_dump` + `.env` + compose, cifrado con la clave **pública** de age, subido a R2
  todos los días. R2 borra los de más de 30 días. La clave privada nunca está en el servidor.
- **Descartado:** sólo los snapshots del proveedor (no sirven si se pierde la cuenta, ni si un
  error se copia al snapshot del día siguiente); guardar los backups en la notebook (depende de
  que esté prendida).
- **Por qué el `.env` va en el backup:** sin la `N8N_ENCRYPTION_KEY`, las credenciales de una
  base restaurada son ilegibles. La prueba de restauración lo comprobó descifrando una
  credencial real.
- **La API key de R2** sólo tiene permiso sobre objetos de ese bucket.

### Un Error Workflow compartido y un bot de alertas aparte

- **Decisión:** un único workflow de alertas para todos los clientes, con su propio bot, y un
  `OnFailure=` de systemd para lo que corre fuera de n8n.
- **Por qué:** el bot del cliente es la cara del servicio; las alertas técnicas son internas. Y
  si n8n está caído, la alerta del servidor llega igual.
