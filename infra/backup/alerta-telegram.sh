#!/usr/bin/env bash
# Avisa por el bot de alertas que falló una unidad de systemd del servidor (ej. el backup).
# Lo dispara alerta@<unidad>.service vía OnFailure=. No depende de n8n: si n8n está
# caído, la alerta llega igual. Lee el token de /opt/n8n/alertas.env (chmod 600).
set -euo pipefail
UNIDAD="${1:-desconocida}"
source /opt/n8n/alertas.env   # TELEGRAM_ALERTAS_TOKEN, TELEGRAM_ALERTAS_CHAT_ID

LOG=$(journalctl -u "$UNIDAD" -n 15 --no-pager -o cat 2>/dev/null || echo "(sin log)")
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

TEXTO="🚨 <b>Falla en el servidor $(hostname)</b>

<b>Unidad:</b> $(echo "$UNIDAD" | esc)
<b>Cuándo:</b> $(TZ=America/Argentina/Buenos_Aires date '+%d/%m/%Y %H:%M:%S')

<pre>$(echo "$LOG" | tail -c 3000 | esc)</pre>"

curl -fsS -o /dev/null "https://api.telegram.org/bot${TELEGRAM_ALERTAS_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_ALERTAS_CHAT_ID}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "text=${TEXTO}"
