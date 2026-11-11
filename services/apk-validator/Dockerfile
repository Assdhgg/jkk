FROM eclipse-temurin:21-jre AS java
FROM python:3.13-slim
COPY --from=java /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="/opt/java/openjdk/bin:${PATH}"
RUN apt-get update && apt-get install -y --no-install-recommends apksigner aapt && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --create-home validator
COPY validator.py .
ENV APKSIGNER=/usr/bin/apksigner AAPT=/usr/bin/aapt
USER validator
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "240", "--limit-request-line", "4096", "validator:application"]
