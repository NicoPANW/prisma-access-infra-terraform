#!/usr/bin/env python3
import json
import os
import sys
import urllib.request
import urllib.error

# Import the token cache service to dynamically check/refresh the token before pushing
try:
    import token_cache_service
except ImportError:
    token_cache_service = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AUTH_FILE = os.path.join(BASE_DIR, "auth-token.json")
TOKEN_FILE = os.path.join(BASE_DIR, "jwt-token.json")

def main():
    # Automatically trigger a token refresh check before attempting the push
    if token_cache_service is not None:
        token_cache_service.main()

    if not os.path.exists(AUTH_FILE):
        print(f"Error: Auth file not found at {AUTH_FILE}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(TOKEN_FILE, "r") as f:
            auth_data = json.load(f)
    except Exception as e:
        print(f"Error reading token file: {e}", file=sys.stderr)
        sys.exit(1)

    jwt = auth_data.get("jwt")
    if not jwt:
        print("Error: No JWT token found in jwt-token.json", file=sys.stderr)
        sys.exit(1)

    url = "https://api.strata.paloaltonetworks.com/config/operations/v1/config-versions/candidate:push"
    payload = {
        "folders": [
            "Service Connections",
            "Remote Networks"
        ],
        "description": "Nicolas Marcoux commit via API for TF automation"
    }

    req_data = json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    req = urllib.request.Request(url, data=req_data, headers=headers, method="POST")

    print("Triggering SCM candidate config push (commit) operation...", file=sys.stderr)
    try:
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            body = response.read().decode("utf-8")
            print(f"STATUS: {status}", file=sys.stderr)
            res_json = json.loads(body)
            print(json.dumps(res_json, indent=2))
    except urllib.error.HTTPError as e:
        try:
            err_body = e.read().decode("utf-8")
            err_json = json.loads(err_body)
            print(f"Push Failed! HTTP Error {e.code}:", file=sys.stderr)
            print(json.dumps(err_json, indent=2))
        except Exception:
            print(f"Push Failed! HTTP Error {e.code}: {e.read().decode('utf-8')}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Connection Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()