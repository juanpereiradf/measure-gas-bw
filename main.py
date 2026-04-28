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
    
    # Calculamos el tamaño exacto generado
    payload_str = json.dumps(data)
    size_in_bytes = len(payload_str.encode('utf-8'))
    size_in_kb = round(size_in_bytes / 1024.0, 2)
    
    return {
        "length": f"{size_in_kb} KB",
        "multiplier": multiplier,
        "data": data
    }