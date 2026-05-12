---
name: configuration
description: 'Adding a new config file, adding a field, or wiring a config consumer. Enforces schema validation at startup (no permissive defaults), env-var indirection for secrets, layered config (defaults / per-env / operator-override), hot-reload explicit per field.'
paths: ["config/**"]
user-invocable: false
---

Apply under `config/` or when wiring a config consumer.

1. **Schema validation at startup — fail loud, fail fast.** Every config deserialized into a typed struct, then validated. Missing required keys / malformed values / out-of-range numbers → process-abort. Forbidden: `unwrap_or(Default::default())` on required fields, `Option<T>` for production-mandatory fields, permissive defaults that mask misconfiguration, lazy first-use loading.
2. **Env-var indirection for secrets — never inline.** API keys, signing secrets, private keys via `secret_env: "FOO_SECRET"`; loader reads at startup. Missing/empty → `ConfigError::MissingEnvVar` / `EmptyEnvVar` startup abort.
3. **Layered config: defaults → per-env → operator-override.** `config/defaults/`, `config/<env>/`, `config/<env>/operator-override.yaml` (gitignored). Deepest wins. Cross-env references rejected.
4. **Hot-reload explicit per field, never default-on.** Default: restart-only. Whitelist exceptions are declared per field; uses an atomic snapshot (`ArcSwap` or equivalent) so consumers see a consistent view. Failed validation on reload → keep previous version + alert.
5. **Torn-read prevention.** Multi-field config consumed via a single atomic snapshot, not field-by-field.
6. **Config-drift detection.** Loader emits a sha256 fingerprint per file (log + metric). Unexpected reload (mtime change without operator action) → alert. Multi-machine deploys verify the same hash everywhere.
7. **Schema versioning.** Every file declares `schema_version: <N>`. Unrecognized → `UnsupportedSchemaVersion`. Migrations in versioned scripts (`config/migrations/v2_to_v3.py`), never inline `if schema_version < N` in the loader.
8. **Per-instance runtime data lives in config files**, never hardcoded. `match` on identifier strings inside source is forbidden — drive the mapping from config.

If a new field is mandatory in prod, default rejection is the right answer.
