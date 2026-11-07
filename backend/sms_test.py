import os
import sys
import time

import httpx
from dotenv import load_dotenv

load_dotenv()
auth = (os.getenv("BULKSMS_USERNAME"), os.getenv("BULKSMS_PASSWORD"))
to = sys.argv[1]
bodies = sys.argv[2:]

ids = []
for body in bodies:
    r = httpx.post(
        "https://api.bulksms.com/v1/messages",
        auth=auth,
        json={"to": to, "body": body},
        timeout=20,
    )
    ids.append(r.json()[0]["id"])

time.sleep(45)
for body, mid in zip(bodies, ids):
    s = httpx.get("https://api.bulksms.com/v1/messages/" + mid, auth=auth, timeout=20).json()
    s = s[0] if isinstance(s, list) else s
    print(s["status"]["id"], "<-", body)