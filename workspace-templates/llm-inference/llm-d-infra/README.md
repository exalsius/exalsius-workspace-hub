# llm-d-infra

Umbrella chart that deploys the llm-d inference infrastructure stack: the inference gateway (with Istio as gateway provider) and body-based routing (experimental feature) for routing LLM requests to the desired inference pool.

**Prerequisites:** The [istio-gateway](../istio-gateway) umbrella chart must be deployed first, as this chart relies on Istio as a gateway provider as well as included CRDs (Gateway API, Inference Extension).
