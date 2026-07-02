#!/usr/bin/env python3
"""
SCM Token Cache Service
Atomic local token cacher to prevent SCM API authentication rate limits.
"""

import base64
import json
import os
import sys
import urllib.request
import urllib.parse
import time
from datetime import datetime, timedelta, timezone

# Dynamically resolve paths relative to the script's actual directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "auth-token.json")
TOKEN_PATH = os.path.join(BASE_DIR, "jwt-token.json")
LOCK_PATH = TOKEN_PATH + ".lock"

def acquire_lock(lock_path, timeout=15):
    """
    Acquires an exclusive atomic file lock to prevent concurrent SCM OAuth grant requests.
    """
    start_time = time.time()
    while True:
        try:
            # 'x' mode open is atomic at the OS level; fails if file already exists
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd)
            return True
        except FileExistsError:
            if time.time() - start_time > timeout:
                return False
            time.sleep(0.1)

def release_lock(lock_path):
    try:
        os.remove(lock_path)
    except FileNotFoundError:
        pass

def load_config(path):
    with open(path, 'r') as f:
        return json.load(f)

def save_token_atomic(path, config, jwt, expires_at, lifetime):
    config_dir = os.path.dirname(path)
    # Write to a temporary file first, then perform an atomic rename
    tmp_path = os.path.join(config_dir, ".jwt-token.json.tmp")
    
    payload = {
        "client_id": config.get("client_id"),
        "client_secret": config.get("client_secret"),
        "host": config.get("host", "api.strata.paloaltonetworks.com"),
        "protocol": config.get("protocol", "https"),
        "scope": config.get("scope"),
        "jwt": jwt,
        "jwt_expires_at": expires_at,
        "jwt_lifetime": lifetime
    }
    
    with open(tmp_path, 'w') as f:
        json.dump(payload, f, indent=2)
    os.chmod(tmp_path, 0o600)  # Restrict permissions
    os.rename(tmp_path, path)

def needs_refresh(token_data, buffer_seconds=300):
    jwt = token_data.get("jwt")
    expires_at_str = token_data.get("jwt_expires_at")
    if not jwt or not expires_at_str:
        return True
    try:
        if expires_at_str.endswith("Z"):
            expires_at_str = expires_at_str[:-1] + "+00:00"
        expires_at = datetime.fromisoformat(expires_at_str)
        return datetime.now(timezone.utc) >= (expires_at - timedelta(seconds=buffer_seconds))
    except Exception:
        return True

def fetch_token(config):
    auth_url = "https://auth.apps.paloaltonetworks.com/oauth2/access_token"
    data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "scope": config["scope"]
    }).encode("utf-8")
    
    # Preemptively construct Basic Authentication header to avoid challenge-response limitations
    auth_str = f"{config['client_id']}:{config['client_secret']}"
    auth_b64 = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")

    req = urllib.request.Request(auth_url, data=data, headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {auth_b64}"
    })
    
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        return res_data["access_token"], res_data.get("expires_in", 900)

def main():
    if not acquire_lock(LOCK_PATH):
        print("Error: Timeout waiting for SCM auth-token lock to release", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(CONFIG_PATH):
        print(f"Error: Config file not found at {CONFIG_PATH}", file=sys.stderr)
        release_lock(LOCK_PATH)
        sys.exit(1)
        
    config = load_config(CONFIG_PATH)
    
    # Load the dedicated token file if it exists to verify expiration state
    token_data = {}
    if os.path.exists(TOKEN_PATH):
        try:
            token_data = load_config(TOKEN_PATH)
        except Exception:
            pass

    # Check token validity and execute refresh inside the lock boundary
    if needs_refresh(token_data):
        print("Token is expired or missing. Fetching a fresh JWT from SCM OAuth...", file=sys.stderr)
        try:
            token, expires_in = fetch_token(config)
            expire_time = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
            expires_at_str = expire_time.strftime("%Y-%m-%dT%H:%M:%SZ")
            save_token_atomic(TOKEN_PATH, config, token, expires_at_str, expires_in)
            token_data = load_config(TOKEN_PATH)
            print(f"Token refreshed successfully. Expires at {expires_at_str}", file=sys.stderr)
        except Exception as e:
            print(f"Error refreshing SCM token: {e}", file=sys.stderr)
            release_lock(LOCK_PATH)
            sys.exit(1)
    else:
        print(f"Token is still valid. Expires at: {token_data.get('jwt_expires_at')}", file=sys.stderr)

    # Release lock cleanly before returning execution back to Terraform
    release_lock(LOCK_PATH)

    # Terraform's external data source strictly requires all JSON map values to be strings.
    # We cast all values to strings before outputting to stdout.
    tf_output = {str(k): str(v) for k, v in token_data.items() if v is not None}
    tf_output["auth_file"] = TOKEN_PATH
    sys.stdout.write(json.dumps(tf_output))

if __name__ == "__main__":
    main()