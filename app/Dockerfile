# ── Stage 1: Build ─────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-jammy

# Download OpenTelemetry Java Agent
ARG OTEL_AGENT_VERSION=2.12.0
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar /otel-agent.jar
RUN chmod 644 /otel-agent.jar

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

# Default OTel environment variables (overridden by K8s env)
ENV JAVA_TOOL_OPTIONS="-javaagent:/otel-agent.jar"
ENV OTEL_SERVICE_NAME="demo-api"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector.observability:4318"
ENV OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_METRICS_EXPORTER="none"
ENV OTEL_LOGS_EXPORTER="none"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
