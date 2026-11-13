# Kasi Jobs

**Local jobs and seasonal work alerts for Piet Retief (eMkhondo), Mpumalanga.**

Many people in the community miss work opportunities because they hear about them too late, or never hear about them at all. Kasi Jobs lets local employers post jobs, and lets job seekers subscribe by skill and area so they are alerted when a matching job appears.

## Features

**Job seekers**
- Browse approved jobs, filtered by area and category
- Register and sign in with one-time PIN (OTP) verification
- Subscribe to alerts by skill and area
- SMS and email consent options

**Employers**
- Upload company documents to be verified by an admin (no automatic verification)
- Post jobs and see only their own jobs, with job status (approved or pending) and their own verification status

**Admin**
- Review employer documents and verify or reject employers
- Approve jobs before they appear publicly

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (web, with Android build) |
| Backend | Python, FastAPI |
| Database | PostgreSQL (Neon) |
| Auth | JWT, bcrypt password hashing |
| Hosting | Vercel (web app), Render (API) |
| SMS | BulkSMS |

## Project structure

```
kasi-jobs/
├── backend/    FastAPI API, models, auth, jobs, subscriptions
└── frontend/   Flutter app (web and Android)
```

## Running locally

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

Create a `backend/.env` file with your own values (never commit this file):

```
DATABASE_URL=your_postgresql_connection_string
SECRET_KEY=a_long_random_string
OTP_REQUIRED=false
# SMS / email provider credentials go here when real delivery is enabled
```

Start the API:

```bash
uvicorn app.main:app --reload
```

The interactive API docs are at `http://127.0.0.1:8000/docs`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

To build the Android app: `flutter build apk`.

## Roadmap

- [x] Registration, login and OTP verification
- [x] Role-based access (job seeker, employer, admin)
- [x] Employer document verification and admin approval
- [x] Live deployment (Vercel, Render, Neon)
- [x] App icon and branding
- [ ] Real SMS delivery through BulkSMS
- [ ] Real email alerts
- [ ] Match alerts sent automatically when a job is approved
- [ ] Onboard the first verified company
- [ ] Google Play Store release
- [ ] Apple App Store release

## Status

Under active development as a community project for Piet Retief and surrounding areas.

## Author

Nkosinathi Collen Msimango