# llm-d-infra

Umbrella chart that deploys the LLM inference infrastructure stack:

- **Inference gateway** – Istio-based gateway for routing LLM requests
- **Body-based routing** – Experimental routing of requests to inference pools based on request body
- **Model discovery** – Service exposing `/v1/models` (OpenAI-compatible) by aggregating model names from labeled ConfigMaps across namespaces
- **Open WebUI** – Web interface for LLM chat

**Prerequisites:** The [istio-gateway](../../istio-gateway) umbrella chart must be deployed first. This chart relies on Istio as a gateway provider and on CRDs (Gateway API, Inference Extension).

After deployment, the gateway exposes two NodePorts: one for LLM inference (OpenAI-compatible API) and one for Open WebUI.
