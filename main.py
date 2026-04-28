from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    env_name = os.environ.get("ENV", "local")
    return {"message": "Hello from Cloud Run!", "environment": env_name}
