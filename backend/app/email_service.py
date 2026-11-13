"""
email_service.py - send email through Brevo's HTTPS API (no SMTP).

Why not SMTP/Gmail: Render's free plan blocks outgoing SMTP ports, so Gmail/Brevo SMTP
fails there. The HTTPS API works. Uses only the Python standard library (no new packages).

Env vars (backend/.env locally, Render -> Environment live):
  BREVO_API_KEY     a Brevo API key (starts with xkeysib-; NOT the SMTP key)
  MAIL_FROM_EMAIL   a sender address you verified in Brevo
  MAIL_FROM_NAME    optional, defaults to "Kasi Jobs"
If BREVO_API_KEY or MAIL_FROM_EMAIL is missing, the email is only printed in the log (safe for local testing).
"""
import json
import os
import urllib.error
import urllib.request

BREVO_API_KEY = os.getenv("BREVO_API_KEY", "")
MAIL_FROM_EMAIL = os.getenv("MAIL_FROM_EMAIL", "")
MAIL_FROM_NAME = os.getenv("MAIL_FROM_NAME", "Kasi Jobs")


def send_email(to_email: str, subject: str, html: str, text: str | None = None) -> bool:
    """Returns True if the email was handed to Brevo (or printed in console mode)."""
    if not BREVO_API_KEY or not MAIL_FROM_EMAIL:
        print(f"[EMAIL not configured, printing instead] to={to_email} subject={subject}\n{text or html}\n")
        return True

    payload = {
        "sender": {"name": MAIL_FROM_NAME, "email": MAIL_FROM_EMAIL},
        "to": [{"email": to_email}],
        "subject": subject,
        "htmlContent": html,
    }
    if text:
        payload["textContent"] = text

    req = urllib.request.Request(
        "https://api.brevo.com/v3/smtp/email",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "api-key": BREVO_API_KEY,
            "content-type": "application/json",
            "accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return 200 <= resp.status < 300
    except urllib.error.HTTPError as e:
        print(f"[EMAIL] Brevo rejected the request: {e.code} {e.read().decode(errors='ignore')}")
        return False
    except Exception as e:  # network problems, timeouts
        print(f"[EMAIL] send failed: {e}")
        return False


def code_email(code: str, purpose: str) -> tuple[str, str, str]:
    """Returns (subject, html, text) for a 6-digit code email."""
    if purpose == "reset":
        subject = "Reset your Kasi Jobs password"
        intro = "Use this code to reset your Kasi Jobs password."
    else:
        subject = "Verify your Kasi Jobs email"
        intro = "Use this code to verify your email address on Kasi Jobs."
    text = f"{intro}\n\nYour code: {code}\n\nIt expires in 10 minutes. If you did not ask for this, ignore this email."
    html = (
        f"<div style='font-family:Arial,sans-serif;max-width:420px'>"
        f"<h2 style='color:#E5006E'>Kasi Jobs</h2><p>{intro}</p>"
        f"<p style='font-size:32px;letter-spacing:6px;font-weight:bold'>{code}</p>"
        f"<p style='color:#666'>It expires in 10 minutes. If you did not ask for this, ignore this email.</p></div>"
    )
    return subject, html, text