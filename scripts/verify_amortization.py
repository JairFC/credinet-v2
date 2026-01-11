import requests
import sys
import json

BASE_URL = "http://localhost:8000/api/v1"
AUTH_URL = "http://localhost:8000/api/v1/auth/login"

def login():
    try:
        resp = requests.post(AUTH_URL, json={"username": "admin", "password": "Sparrow20"})
        if resp.status_code != 200:
            print(f"Login failed: {resp.status_code} {resp.text}")
            sys.exit(1)
        data = resp.json()
        print(f"Login response keys: {list(data.keys())}")
        return data["tokens"]["access_token"]
    except Exception as e:
        print(f"Login exception: {e}")
        sys.exit(1)

def create_loan(token):
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "user_id": 7,
        "associate_user_id": 2,
        "amount": 1000,
        "term_biweeks": 12,
        "profile_code": "standard",
        "notes": "API Verification"
    }
    try:
        resp = requests.post(f"{BASE_URL}/loans", json=payload, headers=headers)
        if resp.status_code not in [200, 201]:
            print(f"Create loan failed: {resp.status_code} {resp.text}")
            sys.exit(1)
        return resp.json()["id"]
    except Exception as e:
        print(f"Create loan exception: {e}")
        sys.exit(1)

def get_amortization(token, loan_id):
    headers = {"Authorization": f"Bearer {token}"}
    try:
        resp = requests.get(f"{BASE_URL}/loans/{loan_id}/amortization", headers=headers)
        if resp.status_code != 200:
            print(f"Get amortization failed: {resp.status_code} {resp.text}")
            sys.exit(1)
        return resp.json()
    except Exception as e:
        print(f"Get amortization exception: {e}")
        sys.exit(1)

def main():
    print("Starting verification...")
    try:
        token = login()
        print("Login successful")
        
        loan_id = create_loan(token)
        print(f"Loan created: {loan_id}")
        
        amortization = get_amortization(token, loan_id)
        print("Amortization fetched")
        
        schedule = amortization.get("schedule", [])
        if not schedule:
            print("No schedule found")
            sys.exit(1)
            
        first_payment = schedule[0]
        print(f"First payment keys: {list(first_payment.keys())}")
        
        if "associate_remaining_balance" in first_payment:
            print("SUCCESS: associate_remaining_balance found!")
            print(f"Value: {first_payment['associate_remaining_balance']}")
        else:
            print("FAILURE: associate_remaining_balance NOT found")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
