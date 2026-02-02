"""Model registry service: FastAPI /v1/models + background thread reading ConfigMaps."""
import os
import threading
import time
from contextlib import asynccontextmanager
from typing import Dict

from fastapi import FastAPI
from kubernetes import client, config

models: Dict[str, int] = {}  # model_id -> created (Unix timestamp)
models_lock = threading.Lock()

LABEL_KEY = os.environ.get("CONFIGMAP_LABEL_KEY", "inference.networking.k8s.io/bbr-managed")
LABEL_VALUE = os.environ.get("CONFIGMAP_LABEL_VALUE", "true")
MODELS_DATA_KEY = os.environ.get("MODELS_DATA_KEY", "baseModel")
POLL_INTERVAL_SEC = int(os.environ.get("POLL_INTERVAL_SEC", "30"))


def extract_model_from_configmap(cm: client.V1ConfigMap) -> tuple[str, int] | None:
    """Extract model ID and creation time from ConfigMap. Returns (model_id, created_epoch) or None."""
    if not cm.data or MODELS_DATA_KEY not in cm.data:
        return None
    val = cm.data[MODELS_DATA_KEY]
    if not val or not val.strip():
        return None
    model_id = val.strip()
    if cm.metadata.creation_timestamp:
        created = int(cm.metadata.creation_timestamp.timestamp())
    else:
        created = int(time.time())
    return (model_id, created)


def refresh_models():
    """List ConfigMaps with label across all namespaces and aggregate model names."""
    global models
    try:
        config.load_incluster_config()
    except config.ConfigException:
        try:
            config.load_kube_config()
        except config.ConfigException:
            return
    v1 = client.CoreV1Api()
    new_models: Dict[str, int] = {}
    try:
        cms = v1.list_config_map_for_all_namespaces()
        for cm in cms.items:
            if not cm.metadata.labels:
                continue
            if cm.metadata.labels.get(LABEL_KEY) == LABEL_VALUE:
                extracted = extract_model_from_configmap(cm)
                if extracted:
                    model_id, created = extracted
                    # Keep earliest creation date if model appears in multiple ConfigMaps
                    if model_id not in new_models or created < new_models[model_id]:
                        new_models[model_id] = created
    except client.exceptions.ApiException:
        pass
    with models_lock:
        models = new_models


def poll_loop():
    """Background thread: periodically refresh models from ConfigMaps."""
    while True:
        refresh_models()
        time.sleep(POLL_INTERVAL_SEC)


@asynccontextmanager
async def lifespan(app: FastAPI):
    refresh_models()
    t = threading.Thread(target=poll_loop, daemon=True)
    t.start()
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/v1/models")
def list_models():
    """OpenAI-compatible /v1/models response."""
    with models_lock:
        model_items = sorted(models.items())
    data = [
        {"id": m, "object": "model", "created": created, "owned_by": "model-registry"}
        for m, created in model_items
    ]
    return {"object": "list", "data": data}


@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
