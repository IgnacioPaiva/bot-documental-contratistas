#!/usr/bin/env bash
# Backup diario de producción → Cloudflare R2 (bucket <tu-bucket>, UE).
# Empaqueta: pg_dump de la base de n8n + .env + docker-compose.yml.
# Cifra con age usando SÓLO la clave pública: la privada vive en la Mac del administrador y en
# la app Contraseñas, nunca en el servidor. R2 borra lo que está bajo n8n/ a los 30 días.
# Lo ejecuta el timer de systemd n8n-backup.timer. Vive en /opt/n8n/backup/.
set -euo pipefail

cd /opt/n8n
set -a
source /opt/n8n/.env          # POSTGRES_USER, POSTGRES_DB
source /opt/n8n/backup.env    # R2_*, AGE_RECIPIENT
set +a

FECHA=$(date -u +%Y-%m-%dT%H%MZ)
ARCHIVO="n8n_${FECHA}.tar.age"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "[$FECHA] pg_dump..."
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$TMP/n8n.dump"

# Un dump vacío o roto no se sube: pg_restore --list falla si el archivo no es válido.
test -s "$TMP/n8n.dump"
docker compose exec -T postgres pg_restore --list < "$TMP/n8n.dump" > /dev/null

cp /opt/n8n/.env "$TMP/env"
cp /opt/n8n/docker-compose.yml "$TMP/docker-compose.yml"
tar -C "$TMP" -cf - n8n.dump env docker-compose.yml | age -r "$AGE_RECIPIENT" -o "$TMP/$ARCHIVO"

echo "Subiendo $ARCHIVO ($(du -h "$TMP/$ARCHIVO" | cut -f1))..."
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_R2_ENDPOINT="$R2_ENDPOINT"
export RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true   # la key no tiene permisos sobre el bucket, sólo sobre objetos
rclone copyto "$TMP/$ARCHIVO" "r2:${R2_BUCKET}/n8n/${ARCHIVO}"

echo "OK: n8n/${ARCHIVO}"
