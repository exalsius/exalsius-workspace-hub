# Local chart-iteration harness for workspace templates.
#
# Drives a single chart through the full operator path against the local-dev-env
# kind clusters, so you can iterate on the chart + its exalsius/ CRs. Assumes
# local-dev-env `make up` + `make setup-kcm-regional-child` have run.
#
# Quick start:
#   make dev-up                       # deploy CPU jupyter-notebook
#   <edit chart> && make dev-redeploy # fast inner loop
#   make dev-down
#
# Override any variable, e.g.:
#   make dev-up CHART=jupyter-notebook CD=default-child-adopted-2 IMAGE_TAG=latest-nvidia
#
# GPU (kind has no real GPUs — fake one first):
#   make dev-fake-gpu VENDOR=nvidia
#   make dev-up GPU=1 VENDOR=nvidia
#   make dev-unfake-gpu

CHART       ?= jupyter-notebook
MGMT        ?= kind-exalsius
REG_CTX     ?= kind-regional-adopted
CHILD_CTX   ?= kind-child-adopted-1
CD          ?= default-child-adopted-1
NS          ?= kcm-system
WSD_NAME    ?= dev
GPU         ?= 0
VENDOR      ?= nvidia
IMAGE_REPO  ?=
IMAGE_TAG   ?=
REGISTRY_HOST ?= localhost:5050

export CHART MGMT REG_CTX CHILD_CTX CD NS WSD_NAME GPU VENDOR IMAGE_REPO IMAGE_TAG REGISTRY_HOST

DEV := ./scripts/dev/workspace-dev.sh

.PHONY: dev-up dev-redeploy dev-down dev-fake-gpu dev-unfake-gpu help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

dev-up: ## Package+push the chart and deploy ST/WSC/WSD through the operator
	$(DEV) up

dev-redeploy: ## Re-push the chart and recreate the WSD (fast inner loop)
	$(DEV) redeploy

dev-down: ## Remove WSD, WorkspaceClass, ServiceTemplate and HelmRepository
	$(DEV) down

dev-fake-gpu: ## Label+patch a child node so the GPU gate passes (VENDOR=nvidia|amd)
	$(DEV) fake-gpu

dev-unfake-gpu: ## Remove the faked GPU label/capacity from the child node
	$(DEV) unfake-gpu
