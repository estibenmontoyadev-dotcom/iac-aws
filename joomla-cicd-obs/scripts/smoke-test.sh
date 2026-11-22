#!/usr/bin/env bash
# Prueba de humo despues de un despliegue.
# Uso: smoke-test.sh <url-base> <sha-esperado>
# Pasa cuando (1) la portada responde 2xx/3xx y (2) /build-info.json informa el SHA esperado.
set -uo pipefail

BASE_URL="${1:?Falta la URL base, por ejemplo http://mi-alb.us-east-1.elb.amazonaws.com}"
EXPECTED_SHA="${2:?Falta el SHA esperado}"
ATTEMPTS="${SMOKE_ATTEMPTS:-30}"
WAIT="${SMOKE_WAIT_SECONDS:-10}"

for i in $(seq 1 "${ATTEMPTS}"); do
  HOME_CODE=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 15 "${BASE_URL}/" || echo 000)
  VERSION=$(curl -sL --max-time 15 "${BASE_URL}/build-info.json" 2>/dev/null | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
  echo "Intento ${i}/${ATTEMPTS}: portada HTTP ${HOME_CODE}, version desplegada '${VERSION:-?}' (esperada '${EXPECTED_SHA}')"
  if [[ "${HOME_CODE}" =~ ^[23] ]] && [ "${VERSION}" = "${EXPECTED_SHA}" ]; then
    echo "Smoke test OK"
    exit 0
  fi
  sleep "${WAIT}"
done

echo "Smoke test FALLIDO" >&2
exit 1
