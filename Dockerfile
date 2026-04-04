FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw
RUN MAVEN_CONFIG='' ./mvnw dependency:go-offline -B

COPY src src
RUN MAVEN_CONFIG='' ./mvnw clean package -DskipTests

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --create-home app \
    && mkdir -p /app/logs \
    && chown -R app:app /app

COPY --from=build /app/target/*.jar /app/app.jar

ENV PORT=8080
ENV JAVA_OPTS=""

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 CMD sh -c "curl --fail http://127.0.0.1:${PORT}/mazebank/actuator/health || exit 1"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -XX:MaxRAMPercentage=75.0 -jar /app/app.jar"]
