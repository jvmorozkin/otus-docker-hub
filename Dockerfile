# Этап 1: Сборка
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /workspace/app

COPY gradle gradle
COPY gradlew settings.gradle build.gradle ./
COPY src ./src

# Собираем проект
RUN ./gradlew build -x test

# Копируем ТОЛЬКО исполняемый JAR (не -plain.jar)
RUN mkdir -p /build && \
    cp build/libs/otus-docker-hub-0.0.3.jar /build/app.jar && \
    echo "✅ Скопирован исполняемый JAR: otus-docker-hub-0.0.3.jar → app.jar"

# Этап 2: Запуск
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Копируем JAR
COPY --from=builder /build/app.jar app.jar

EXPOSE 8000
ENTRYPOINT ["java", "-jar", "app.jar"]