# Imagen de Joomla del proyecto: la imagen oficial + el codigo propio versionado en este repositorio.
# El entrypoint oficial instala el sitio la primera vez; el sitio queda en EFS (/var/www/html).
# En cada arranque, itm-start.sh copia encima el codigo de /opt/itm-custom (lo que se versiona aqui).
ARG JOOMLA_TAG=6.2-php8.3-apache
FROM joomla:${JOOMLA_TAG}

ARG BUILD_SHA=local
ARG BUILD_REF=local
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="joomla-itm" \
      org.opencontainers.image.revision="${BUILD_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}"

# Codigo propio (se sincroniza con el sitio al arrancar) y comando de arranque
COPY custom/ /opt/itm-custom/
COPY itm-start.sh /usr/local/bin/apache2-itm-foreground

# build-info.json permite comprobar desde fuera que version esta desplegada (lo usa el smoke test)
RUN chmod +x /usr/local/bin/apache2-itm-foreground \
 && printf '{"app":"joomla-itm","version":"%s","ref":"%s","built_at":"%s"}\n' \
      "${BUILD_SHA}" "${BUILD_REF}" "${BUILD_DATE}" > /opt/itm-custom/build-info.json

# El nombre empieza por "apache2": asi el entrypoint oficial ejecuta primero su inicializacion
# (instalar Joomla si hace falta) y despues lanza este comando, que a su vez arranca Apache.
CMD ["apache2-itm-foreground"]
