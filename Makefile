# Synthetic RAG teaching corpus - common tasks.
# Every target is a thin wrapper around `uv run`; see TROUBLESHOOTING.md for
# installing `make` on Windows or running the commands directly.

GENERATOR := uv run scripts/corpus_data_generator.py
WORKERS   ?= 6
# Reasoning effort for hybrid runs: none | low | medium | high.
# Empty = use OPENAI_REASONING_EFFORT from .env. Lower effort = faster, cheaper runs.
EFFORT    ?=
LLM_OPTS   = --workers $(WORKERS) $(if $(EFFORT),--effort $(EFFORT),)
# Vector store selection for ingest/validate targets: all | hr | products
STORE     ?= all

.DEFAULT_GOAL := help
.PHONY: help setup generate generate-fast generate-template generate-hr generate-products refresh verify clean clean-cache \
        ingest ingest-reset validate-stores validate-stores-offline clean-stores

help: ## Show available targets
	@uv run python -c "import re; [print(f'  {m[0]:<25} {m[1]}') for m in re.findall(r'^([a-z-]+):.*?## (.*)$$', open('Makefile').read(), re.M)]"

setup: ## Create the .venv and install dependencies (uv sync)
	uv sync

generate: ## Generate the full corpus (hybrid if OPENAI_API_KEY is set); e.g. make generate EFFORT=low
	$(GENERATOR) generate $(LLM_OPTS)

generate-fast: ## Fastest hybrid run: low reasoning effort, 10 parallel requests
	$(GENERATOR) generate --mode hybrid --effort low --workers 10

generate-template: ## Generate the full corpus offline, without the LLM
	$(GENERATOR) generate --mode template

generate-hr: ## Generate HR policies only (hybrid)
	$(GENERATOR) generate --mode hybrid --only hr $(LLM_OPTS)

generate-products: ## Generate product manuals only (hybrid)
	$(GENERATOR) generate --mode hybrid --only products $(LLM_OPTS)

refresh: ## Regenerate all LLM prose, ignoring the cache; e.g. make refresh EFFORT=medium
	$(GENERATOR) generate --mode hybrid --refresh $(LLM_OPTS)

verify: ## Verify the corpus on disk (page counts, no images, golden Q&A evidence)
	$(GENERATOR) verify

clean: ## Delete generated PDFs and golden Q&A (keeps the LLM cache)
	uv run python -c "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ('data/corpus', 'data/golden_qa')]"

clean-cache: ## Delete the LLM cache (next hybrid run calls the API again)
	uv run python -c "import shutil; shutil.rmtree('data/cache', ignore_errors=True)"

ingest: ## Embed corpus PDFs into the Chroma stores (unchanged docs skipped); e.g. make ingest STORE=hr
	uv run scripts/ingest_vector_stores.py --store $(STORE)

ingest-reset: ## Empty and rebuild the Chroma store(s) from scratch
	uv run scripts/ingest_vector_stores.py --store $(STORE) --reset

validate-stores: ## Summarise the vector stores, cross-check the manifest and run sample queries
	uv run scripts/validate_vector_stores.py --store $(STORE)

validate-stores-offline: ## Same as validate-stores without sample queries (no API calls)
	uv run scripts/validate_vector_stores.py --store $(STORE) --skip-queries

clean-stores: ## Delete both Chroma databases (data/vectorstores)
	uv run python -c "import shutil; shutil.rmtree('data/vectorstores', ignore_errors=True)"
