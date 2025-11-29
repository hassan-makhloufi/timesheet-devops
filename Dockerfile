# FROM maven:3.8.6-eclipse-temurin-17 as build
# WORKDIR /app
# COPY . .
# RUN mvn clean package -DskipTests

# FROM eclipse-temurin:17-jre
# WORKDIR /app
# COPY --from=build /app/target/*.jar app.jar
# CMD ["java", "-jar", "app.jar"]

# Image de base
FROM openjdk:17-jdk-slim

# Créer un utilisateur non-root
RUN useradd -r -u 1001 appuser

# Répertoire de travail
WORKDIR /app

# Copier le jar de l'application
COPY target/timesheet-devops-1.0.jar app.jar

# Passer à l'utilisateur non-root
USER appuser

# Exposer le port de l'appli (8082 chez toi)
EXPOSE 8082

# Commande de démarrage
ENTRYPOINT ["java", "-jar", "app.jar"]
