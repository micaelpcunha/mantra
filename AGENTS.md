# Project Instructions

- Use European Portuguese in user-facing responses unless the user asks for another language.
- Prefer doing the work end-to-end instead of stopping at analysis, whenever it is safe and feasible.
- Update `PROJECT_NOTES.md` before finishing any task that materially changes app behavior, backend/schema scripts, security, build/release flow, branding, or developer tooling.
- Add notes as a concise session entry using the style `## Sessao YYYY-MM-DD Tema`.
- Summaries in `PROJECT_NOTES.md` should capture what changed, why it mattered, and any relevant validation.
- When changing Supabase behavior or schema, keep the canonical SQL change in the repository and avoid leaving live-only database tweaks undocumented.
- When changing Android behavior and the user wants device validation, rebuild the debug APK and install it with `adb` when a device is available; if that was not done, say so clearly.
- Prefer admin-friendly automated flows over manual operational steps when there is a secure backend path to support them.
- Skip note updates for trivial chat, pure exploration with no landed change, or when the user explicitly says not to update the notes.
