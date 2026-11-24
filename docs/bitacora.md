# Bitácora

Qué se rompió, cómo se diagnosticó y qué regla quedó. Una entrada por problema real.

## Fase 0 — El bot no respondía: Markdown de Telegram

**Síntoma:** el Telegram Trigger recibía el mensaje (la ejecución aparecía en n8n), pero el
nodo de respuesta fallaba con:

```
Bad Request: can't parse entities: Can't find end of the entity starting at byte offset 89
```

**Diagnóstico:** el error venía de Telegram, no de n8n. "Entities" son los formatos (negrita,
cursiva). En el byte 89 del texto estaba el guion bajo de `user_id`.

**Causa:** el nodo Telegram de n8n manda el texto con `parse_mode` Markdown. El `_` abrió una
cursiva que nunca se cerraba. Lo mismo pasaría con cualquier nombre de archivo del catálogo,
que se llaman `2026-06_F931_DDJJ.pdf`.

**Arreglo:** `parse_mode: HTML` en todos los nodos que envían texto. En HTML el `_` no
significa nada; sólo hay que escapar `<`, `>` y `&` en los datos variables.

**Regla:** todo envío a Telegram en HTML, nunca Markdown.

**Lo que dejó de bueno:** el error se volvió la prueba del sistema de alertas. Para probar el
Error Workflow se volvió a poner Markdown a propósito, y la alerta llegó en segundos.

## Fase 0 — El backup funcionaba al segundo intento

**Síntoma:** el primer backup a R2 terminó con `OK`, pero el log mostraba:

```
ERROR : Failed to copy: NotImplemented: Not Implemented (501)
ERROR : Attempt 2/3 succeeded
```

**Diagnóstico:** el error era del lado de R2 (501 = "no implementado"), y el reintento
funcionaba. La versión de rclone instalada era la 1.60, de 2022.

**Causa:** el rclone del repositorio de Ubuntu es viejo y hace una operación que R2 hoy no
implementa. Funcionaba sólo por los reintentos.

**Arreglo:** rclone 1.76 desde el paquete oficial de rclone.org. El backup sale limpio en el
primer intento.

**Regla:** un "funciona" que depende de los reintentos es una falla esperando su día. Y un
paquete instalado por fuera del gestor del sistema no recibe actualizaciones automáticas:
anotarlo para revisarlo.

## Fase 0 — Prueba de restauración

No fue un problema, pero es la entrada que más importa: **un backup que nunca se restauró no
está probado.**

1. Se bajó el último backup del panel de R2 a una computadora aparte.
2. Se descifró con la clave privada de age (que nunca estuvo en el servidor).
3. Se restauró el dump en un Postgres 17 temporal: estaban los workflows, las credenciales y
   el usuario dueño.
4. Se levantó un n8n temporal de la misma versión contra esa base, con la
   `N8N_ENCRYPTION_KEY` que trae el paquete, y **pudo descifrar una credencial real**.
5. Se borró todo: el contenedor y los archivos descifrados.

El paso 4 es el que la mayoría se saltea: un backup de n8n sin su clave de cifrado restaura
una base cuyas credenciales nadie puede leer.

## Fase 0 — El sitio "no existía" para una sola computadora

**Síntoma:** recién creado el subdominio, el navegador daba `DNS_PROBE_FINISHED_NXDOMAIN`,
mientras que desde otros resolvedores el sitio respondía bien.

**Causa:** antes de crear el registro se consultó el subdominio para confirmar que estuviera
libre. El router de la red guardó la respuesta "no existe" (caché negativo, hasta ~30 minutos).
Limpiar el caché de la computadora no alcanza: el que recordaba era el router.

**Arreglo:** esperar, reiniciar el router, o usar DNS seguro (DoH) en el navegador.

**Regla:** no consultar un nombre antes de crearlo desde la misma red en la que se va a probar.
