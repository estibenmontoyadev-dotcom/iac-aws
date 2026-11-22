#!/bin/bash
# Se ejecuta DESPUES de la inicializacion del entrypoint oficial de Joomla.
# Copia el codigo versionado de la imagen (/opt/itm-custom) sobre el sitio persistente
# y arranca Apache. Asi cada despliegue actualiza el codigo propio sin tocar datos ni configuracion.
set -euo pipefail

SRC=/opt/itm-custom
WEBROOT="${JOOMLA_WEBROOT:-/var/www/html}"

if [ -f "${WEBROOT}/configuration.php" ]; then
  echo "[itm] Sincronizando codigo propio desde ${SRC} hacia ${WEBROOT}"
  cp -rT --no-preserve=ownership "${SRC}" "${WEBROOT}"
  (cd "${SRC}" && find . -type f -print0) | while IFS= read -r -d '' file; do
    chown www-data:www-data "${WEBROOT}/${file}"
    chmod 0644 "${WEBROOT}/${file}"
  done
  echo "[itm] Version desplegada: $(cat "${WEBROOT}/build-info.json")"
else
  echo "[itm] Joomla aun no esta instalado: se omite la sincronizacion"
fi

exec apache2-foreground-roto "$@"
