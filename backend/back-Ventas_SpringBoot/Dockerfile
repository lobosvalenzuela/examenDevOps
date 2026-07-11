# Etapa de construcción (Build) - Usando Alpine para ahorrar ~1 GB de disco
FROM maven:3.8.5-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Copiamos los archivos de configuración y código fuente
COPY pom.xml .
COPY src ./src

# Empaquetamos la aplicación saltando las pruebas para mayor velocidad
RUN mvn clean package -DskipTests

# Etapa de ejecución (Run) - Imagen ligera para producción
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copiamos el JAR generado desde la etapa de construcción
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
