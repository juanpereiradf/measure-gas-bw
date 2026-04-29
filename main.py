from fastapi import FastAPI
import os
import logging
import json

# Configurar logging básico para ver algo en Cloud Run Logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.get("/")
def read_root():
    logger.info("Petición recibida en /")
    env_name = os.environ.get("ENV", "local")
    return {"message": "Hello from Cloud Run!", "environment": env_name}

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/test-bandwidth")
def test_bandwidth(multiplier: int = 1):
    """
    Genera un payload dinámico proporcional al 'multiplier' recibido.
    Ideal para probar el límite de carga (ancho de banda) de Google Apps Script.
    """
    logger.info(f"Petición en /test-bandwidth con multiplier={multiplier}")
    
    # Objeto base con relleno para ocupar espacio
    base_item = {
        "item_id": "test-item-12345",
        "description": "Este texto es relleno genérico para aumentar el tamaño del JSON generado y probar el ancho de banda. " * 10,
        "attributes": {
            "is_valid": True,
            "category": "bandwidth-testing",
            "tags": ["test", "dummy", "payload", "gas", "fastapi"]
        },
        "padding_data": list(range(50)) # Relleno adicional de números
    }
    
    # Generamos la lista proporcional. Ajusta x10 para que 1 multiplier = ~15 KB
    data = [base_item for _ in range(multiplier * 10)]
    
    # Calculamos el tamaño exacto del cuerpo de la respuesta (string JSON)
    payload_str = json.dumps({
        "multiplier": multiplier,
        "data": data
    })
    
    # El tamaño en bytes depende de la codificación (UTF-8 es el estándar)
    exact_size_bytes = len(payload_str.encode('utf-8'))
    exact_size_kb = exact_size_bytes / 1024.0
    
    # Nota sobre las complicaciones al estimar el tamaño:
    # 1. Encoding: UTF-8 usa de 1 a 4 bytes por caracter.
    # 2. Compresión: Gzip/Brotli pueden reducir el tamaño en red significativamente.
    # 3. Overhead HTTP: Headers añaden unos cientos de bytes extra.
    # 4. Parsing: En Apps Script, el objeto JSON en memoria ocupará más que el string bruto.
    
    return {
        "metadata": {
            "multiplier": multiplier,
            "exact_size_bytes": exact_size_bytes,
            "exact_size_kb": round(exact_size_kb, 4),
            "encoding": "utf-8",
            "note": "Este tamaño corresponde únicamente al body (JSON). El tráfico total de red incluirá headers HTTP."
        },
        "data": data
    }