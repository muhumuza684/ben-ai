# Ben AI backend

This service is the secure boundary between the Flutter app and the AI provider. It keeps `GROQ_API_KEY` off the APK, exposes `/v1/chat`, stores assistant messages when Supabase is configured, and exposes reminder endpoints for the hosted version of scheduled simulated calls.

## Local setup

Copy `.env.example` to `.env`, set `GROQ_API_KEY`, then run:

```bash
npm install
npm run build
npm start
```

The health check is `GET /health`. Configure the Flutter app with:

```bash
flutter run --dart-define=BEN_API_BASE_URL=http://10.0.2.2:8787
```

Use the host machine’s LAN address instead of `10.0.2.2` on a physical phone.

## Supabase

Create a Supabase project, run `schema.sql` in the SQL editor, and set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only on the server. Never put the service-role key in Flutter or GitHub source. Add row-level security policies before exposing user data in a public release.

## Render

Create a Web Service from this repository with root directory `backend`, build command `npm install && npm run build`, and start command `npm start`. Add `PORT`, `GROQ_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `ALLOWED_ORIGINS` as Render environment variables.

The local Flutter database and simulated timers remain as an offline fallback. The hosted path should become the source of truth for authenticated users, persistent schedules, cloud memory, and future voice-profile processing.
