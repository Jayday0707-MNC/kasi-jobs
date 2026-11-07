import os
import smtplib
import ssl
from datetime import datetime, timezone
from email.message import EmailMessage

import httpx
from sqlalchemy import select

from .database import SessionLocal
from .models import Job, Notification, Subscription, User

EMAIL_MODE = os.getenv("EMAIL_MODE", "console")  # console or smtp
SMS_MODE = os.getenv("SMS_MODE", "console")      # console or bulksms


def send_email(to: str, subject: str, body: str) -> str:
    if EMAIL_MODE == "brevo":
        print(f"\n--- EMAIL to {to} ---\nSubject: {subject}\n\n{body}\n--- end email ---\n")
        return "console"

    sender = os.getenv("EMAIL_FROM") or os.getenv("SMTP_USER")
    msg = EmailMessage()
    msg["From"] = f"Kasi Jobs <{sender}>"
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)

    host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    port = int(os.getenv("SMTP_PORT", "587"))
    with smtplib.SMTP(host, port, timeout=20) as smtp:
        smtp.starttls(context=ssl.create_default_context())
        smtp.login(os.getenv("SMTP_USER"), os.getenv("SMTP_PASSWORD"))
        smtp.send_message(msg)
    return "smtp ok"


def send_sms(to: str, text: str) -> str:
    if SMS_MODE == "console":
        print(f"\n--- SMS to {to} ({len(text)} chars) ---\n{text}\n--- end sms ---\n")
        return "console"

    if SMS_MODE == "bulksms":
        token_id = os.getenv("BULKSMS_USERNAME")
        token_secret = os.getenv("BULKSMS_PASSWORD")
        if not token_id or not token_secret:
            raise RuntimeError("BULKSMS_USERNAME and BULKSMS_PASSWORD are not set")
        resp = httpx.post(
            "https://api.bulksms.com/v1/messages",
            auth=(token_id, token_secret),
            json={"to": to, "body": text},
            timeout=20,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"BulkSMS {resp.status_code}: {resp.text[:300]}")
        return resp.text[:500]

    raise RuntimeError(f"Unknown SMS_MODE: {SMS_MODE}")


def build_messages(job: Job) -> tuple[str, str, str]:
    closes = job.closing_date.strftime("%d %b %Y") if job.closing_date else "open"

    sms = (
        f"Kasi Jobs: {job.title}, {job.employer.business_name}, "
        f"{job.area.name}. Closes {closes}. Job #{job.id}"
    )[:160]  # one SMS = 160 characters

    subject = f"New job: {job.title} ({job.area.name})"
    body = (
        f"A new job matches your alert.\n\n"
        f"Job: {job.title}\n"
        f"Employer: {job.employer.business_name}\n"
        f"Area: {job.area.name}\n"
        f"Category: {job.category.name}\n"
        f"Pay: {job.pay or 'Not stated'}\n"
        f"Closes: {closes}\n\n"
        f"About the job:\n{job.description}\n\n"
        f"How to apply:\n{job.how_to_apply or 'Contact the employer.'}\n\n"
        f"Job #{job.id} | Kasi Jobs"
    )
    return sms, subject, body


def _deliver(db, user: User, job: Job, channel: str, send) -> None:
    already = db.scalar(
        select(Notification).where(
            Notification.user_id == user.id,
            Notification.job_id == job.id,
            Notification.channel == channel,
        )
    )
    if already:
        return  # never send the same alert twice

    note = Notification(user_id=user.id, job_id=job.id, channel=channel, status="pending")
    db.add(note)
    db.commit()
    try:
        note.provider_response = send()
        note.status = "sent"
        note.sent_at = datetime.now(timezone.utc)
    except Exception as exc:
        note.status = "failed"
        note.provider_response = str(exc)[:500]
    db.commit()


def send_job_alerts(job_id: int) -> None:
    """Runs in the background after an admin approves a job."""
    with SessionLocal() as db:
        job = db.get(Job, job_id)
        if not job or job.status != "approved":
            return

        sms_text, subject, body = build_messages(job)

        subscribed = select(Subscription.user_id).where(
            Subscription.category_id == job.category_id,
            Subscription.area_id == job.area_id,
        )
        users = db.scalars(select(User).where(User.id.in_(subscribed))).all()

        for user in users:
            if user.consent_sms and user.phone:
                _deliver(db, user, job, "sms", lambda: send_sms(user.phone, sms_text))
            if user.consent_email and user.email:
                _deliver(db, user, job, "email", lambda: send_email(user.email, subject, body))
                print(f"Alerts: email={EMAIL_MODE} sms={SMS_MODE}")
                print(f"Alerts: email={EMAIL_MODE} sms={SMS_MODE}")