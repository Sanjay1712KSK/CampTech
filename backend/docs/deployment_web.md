# Web Deployment Guide

This project is ready to deploy as:

- `FastAPI` backend on Render
- `Flutter Web` frontend on Netlify or Vercel

## Backend

The repo now includes [render.yaml](/s:/flutter/guidewire_gig_ins/render.yaml), so Render can create:

- a web service for the FastAPI backend
- a managed PostgreSQL database

### Render setup

1. Open Render
2. Create a new Blueprint
3. Select this GitHub repository
4. Render will detect `render.yaml`
5. Fill the secret environment variables when prompted

### Required secret values

- `API_PUBLIC_BASE_URL`
- `SMTP_USER`
- `SMTP_PASS`
- `SENDER_EMAIL`
- `OPENWEATHER_API_KEY`
- `ORS_API_KEY`

Optional:

- `NBFLITE_BASE_URL`
- `NBFLITE_API_KEY`

### Backend start command

Render uses:

```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

### Health check

Backend health endpoint:

```text
/health
```

### Database

The backend now supports PostgreSQL connection strings from Render and normalizes them for SQLAlchemy with `psycopg`.

If `DATABASE_URL` is not set, the backend falls back to local SQLite for development.

## Frontend

Build Flutter Web with the deployed backend URL:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-BACKEND.onrender.com
```

Publish directory:

```text
build/web
```

## Recommended deployment order

1. Deploy backend on Render first
2. Copy the public backend URL
3. Build/deploy Flutter web with `API_BASE_URL` pointing to that backend
4. Test:
   - `/health`
   - signup/login
   - gig connect
   - risk
   - premium
   - claim

## Important notes

- SQLite is fine locally, but production should use PostgreSQL
- Web clients need a public HTTPS backend URL
- Browser builds do not use biometric authentication; the app now falls back safely
- Mobile deep-link handling remains intact and is bypassed safely on web
