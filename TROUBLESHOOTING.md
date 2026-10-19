# Troubleshooting

## Setup

**`uv: command not found`**
Install uv from <https://docs.astral.sh/uv/getting-started/installation/>.
- Windows PowerShell: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
- macOS or Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`

Open a new terminal afterwards.

**`ModuleNotFoundError: No module named 'data_generation'`**
The helper package is installed into `.venv` by `uv sync`. Run `uv sync` once, and always start the script with
`uv run scripts/corpus_data_generator.py ...`, not `python scripts/...`, so that the project environment is used.

**Wrong Python version**
The project needs Python 3.12 or later (pinned in `.python-version`). If you don't have it, run
`uv python install 3.12`, then `uv sync`.

## `make` on Windows

`make` is not installed on Windows by default. You can:
- Install it with `winget install GnuWin32.Make` or `choco install make`, then reopen the terminal.
- Use Git Bash, which some Git installs include `make` with.
- Run the commands directly, without `make`:

| Make target | Direct command |
|---|---|
| `make setup` | `uv sync` |
| `make generate` | `uv run scripts/corpus_data_generator.py generate` |
| `make generate-template` | `uv run scripts/corpus_data_generator.py generate --mode template` |
| `make generate-hr` | `uv run scripts/corpus_data_generator.py generate --mode hybrid --only hr` |
| `make verify` | `uv run scripts/corpus_data_generator.py verify` |

## OpenAI and hybrid mode

**`ERROR: hybrid mode needs OPENAI_API_KEY`**
Add `OPENAI_API_KEY=...` to `.env` in the project root, or run with `--mode template`.

**`AuthenticationError` (401)**
The key is invalid or revoked. Create a new key and update `.env`. Check that there are no quotes or trailing
spaces around the value.

**`NotFoundError` or "model does not exist" (404)**
Your account does not have access to the model in `OPENAI_MODEL`. Change it in `.env` to a model available to
you.

**`BadRequestError` mentioning `reasoning` or `effort`**
The chosen model does not support that reasoning effort. Try `--effort low` or `--effort medium`, or change
`OPENAI_REASONING_EFFORT` in `.env`.

**A hybrid run is slow**
Reasoning effort is the main factor. In our measurements, `high` takes about 27 s per request (about 18 min for
the full corpus), and `low` takes about 3.4 s (about 3 min). Use `make generate-fast`, or
`make generate EFFORT=low WORKERS=10`, or set `OPENAI_REASONING_EFFORT=low` in `.env`. See the speed table in
the README.

**Changed `--effort` but nothing was regenerated**
That is by design. The cache ignores the effort level, so cached sections are reused. Add `--refresh`
(`make refresh EFFORT=low`) to request them again at the new effort.

**Rate limits (429)**
Requests are retried automatically with backoff. To reduce pressure, lower concurrency with `--workers 2`
(`make generate WORKERS=2`), or generate one category at a time (`--only hr`, then `--only products`).
Completed sections are cached, so an interrupted run resumes where it stopped.

**Some sections show "rejected" in the summary**
That is the guard working. The LLM added a number or mentioned another model, so the template text was kept.
The reasons are listed under `enrichment.rejections` in `data/corpus/generation_report.json`. A few rejections
are normal. To retry them, run `generate --refresh`. Note that this re-requests every section.

**`errors` is above zero after a hybrid run**
Those sections hit an API error after all retries and fell back to the template text. Run `generate` again;
cached sections are not requested a second time.

## Output and verification

**`PermissionError` when generating on Windows**
A PDF from the previous run is open in a viewer or in VS Code. Close it, then run `generate` again; the
generator deletes and rebuilds `data/corpus`.

**`page counts within range` fails**
Rich LLM prose made a document longer than its range, even at the tightest layout. Options:
- Use `--effort low`, which usually produces shorter text.
- Lower `max_words` for the category in `PROFILES` in `src/data_generation/llm/enricher.py`, then run
  `generate --refresh`.
- Remove some of the `enrich=True` flags in the builders for that document type.

**`golden Q&A evidence found on cited pages` fails**
Evidence strings must appear verbatim in the PDF text. This happens after editing the catalog wording without
updating the matching `qa` evidence (HR policies) or spec row labels (manuals). The failure message shows the
question ID and the missing evidence.

**`manifest matches files on disk` fails**
Files were added to or removed from `data/corpus` by hand. Run `generate` again to rebuild a clean corpus.

**Start completely fresh**
Run `make clean`, plus `make clean-cache` to also discard the LLM prose. Then run `generate` again.

## Vector stores (ingestion and validation)

**`Store not found` in the validation script**
Run `uv run scripts/ingest_vector_stores.py` (`make ingest`) first. The databases live in `data/vectorstores/`.

**I changed the chunk size, but nothing seems different**
Re-run ingestion. Changed chunks are detected automatically, and the affected documents are re-embedded and
replaced. `validate_vector_stores.py` shows the `chunk_size` recorded on the collection. Use `--reset` for a
completely clean rebuild.

**I changed the metadata logic in `src/data_ingestion`, but the old metadata is still there**
Change detection compares chunk text, not metadata. Run with `--reset` (`make ingest-reset`) to rebuild the
store with the new metadata.

**`PermissionError` or "database is locked" on Windows**
Another process has the Chroma database open: a notebook, a second script, or a file viewer. Close it and
re-run. To start from scratch, run `make clean-stores` while nothing else is using the folder.

**Metadata type errors from Chroma**
Chroma accepts only scalar values (str, int, float, bool). New metadata must go through
`metadata.sanitize_for_chroma`, which drops `None` and joins lists.

**Embedding rate limits (429) or timeouts**
Lower `INGEST_BATCH_SIZE` (fewer documents embedded in parallel) or `EMBEDDING_BATCH_SIZE` (smaller requests)
in `.env`. Requests are retried automatically, and finished documents are not re-embedded on the next run.

**Validation without API calls**
Use `--skip-queries` (`make validate-stores-offline`). Only the sample queries need the embeddings API.

## Text extraction differences

The golden Q&A is verified with `pypdf`. Other loaders (PyMuPDF, pdfplumber, Unstructured) may order table
cells or join wrapped lines differently. This is a useful classroom discussion point, not a corpus bug. Normalise
whitespace before comparing text.
