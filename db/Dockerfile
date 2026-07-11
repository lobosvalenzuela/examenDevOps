# Imagen base MySQL 8 oficial
FROM mysql:8

# Solo definimos el nombre de la base de datos para que se cree al arrancar
ENV MYSQL_DATABASE=bd_examen

# Copiar el script de inicialización dentro de la imagen
# Se ejecuta automáticamente la primera vez que se levante el contenedor
COPY init.sql /docker-entrypoint-initdb.d/

# Exponer el puerto de MySQL
EXPOSE 3306
