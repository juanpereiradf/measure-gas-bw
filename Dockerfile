# Usar una imagen oficial de Python ligera
FROM python:3.11-slim

# Evitar que Python genere archivos .pyc y permitir logs en tiempo real
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Establecer el directorio de trabajo
WORKDIR /app

# Instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto del código
COPY . .

# Cloud Run pasa el puerto en la variable de entorno $PORT (default 8080)
# FastAPI con uvicorn necesita escuchar en 0.0.0.0
CMD uvicorn main:app --host 0.0.0.0 --port 8080
