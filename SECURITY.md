# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Handling secrets

This project reads `OPENAI_API_KEY` from a local `.env` file.

- **Never commit `.env`.** It is listed in `.gitignore`. Check before every commit with `git status`.
- If a key has ever been committed, pushed, pasted into a chat, or shared in a screen recording, **rotate it
  immediately** in the OpenAI dashboard. Deleting the file in a later commit does not remove it from history.
- To check whether `.env` was ever committed, run `git log --all --oneline -- .env`. The command should print nothing.
- When teaching, use a project-scoped key with a monthly spending limit, and revoke it after the session.
- The generator sends only synthetic, fictional content to the API. Do not add real personal data, real
  employee records or confidential company documents to the catalog.

## Generated content

- All brands, companies, products, people and contact details in the corpus are fictional. Phone numbers are
  placeholders, and every web address uses the reserved `.example` domain.
- Statutory references in the HR policies are illustrative teaching material, not legal advice.
- The LLM cache (`data/cache/llm/`) stores prompts and responses in plain text. It contains no secrets, but
  treat it like any generated artefact and do not publish it without review.

## Reporting a vulnerability

Please report security issues privately by email to **jd.ramkumar@gmail.com** with the subject line
`[SECURITY] aiml-day6`. Include steps to reproduce and the affected version. You can expect an acknowledgement
within 5 working days. Please do not open a public issue for security reports.
