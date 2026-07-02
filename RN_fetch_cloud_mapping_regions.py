#!/usr/bin/env python3
import json
import os
import sys
import urllib.request
import urllib.error

# Import the token cache service to enable auto-refresh capability
try:
    import token_cache_service
except ImportError:
    token_cache_service = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AUTH_FILE = os.path.join(BASE_DIR, "auth-token.json")
TOKEN_FILE = os.path.join(BASE_DIR, "jwt-token.json")
MAPPINGS_FILE = os.path.join(BASE_DIR, "RN-region-mappings.json")

def test_api_endpoint(url, headers):
    """
    Performs the explicit HTTP transaction test and validates the SCM API response.
    Returns a tuple of (is_successful, decoded_json_or_error_message).
    """
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            if status == 200:
                body = response.read().decode("utf-8")
                data = json.loads(body)
                return True, data
            else:
                return False, f"Unexpected HTTP status code: {status}"
    except urllib.error.HTTPError as e:
        try:
            err_body = e.read().decode("utf-8")
            err_json = json.loads(err_body)
            err_msg = err_json.get("_errors", [{}])[0].get("message", err_body)
        except Exception:
            err_msg = str(e)
        return False, f"HTTP Error {e.code}: {err_msg}"
    except Exception as e:
        return False, f"Network Connection Failed: {e}"

def main():
    # Automatically trigger a token refresh check before attempting API requests
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

    url = "https://api.strata.paloaltonetworks.com/sse/config/v1/locations"
    print(f"\n==================================================", file=sys.stderr)
    print(f"Testing API endpoint: {url}", file=sys.stderr)
    print(f"==================================================", file=sys.stderr)
    
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Accept": "application/json"
    }

    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read().decode("utf-8")
            print(f"STATUS: {response.getcode()}", file=sys.stderr)
            data = json.loads(body)
            
            # Unpack wrapped envelopes
            locations = data.get("data", data) if isinstance(data, dict) else data
            
            if isinstance(locations, list) and len(locations) > 0:
                print(f"SUCCESS! Retrieved {len(locations)} locations.", file=sys.stderr)
                
                print("\n--- ALL RAW LOCATIONS DATA ---", file=sys.stderr)
                print(json.dumps(locations, indent=2))
                
                # Write the raw, unmodified locations array directly to the mapping file atomically
                try:
                    temp_mappings_file = f"{MAPPINGS_FILE}.tmp"
                    with open(temp_mappings_file, "w") as mf:
                        json.dump(locations, mf, indent=2)
                    os.replace(temp_mappings_file, MAPPINGS_FILE)
                    print(f"Successfully wrote mappings to {MAPPINGS_FILE}", file=sys.stderr)
                except Exception as e:
                    print(f"Error writing mappings file: {e}", file=sys.stderr)
                    sys.exit(1)
                return
            else:
                print(f"Warning: Unexpected response format: {body[:250]}", file=sys.stderr)
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}", file=sys.stderr)
    except Exception as e:
        print(f"Connection Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()