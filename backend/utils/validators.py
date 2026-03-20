import re


def validate_aadhaar(aadhaar_number: str) -> bool:
    return bool(re.fullmatch(r"\d{12}", aadhaar_number))


def validate_license(license_number: str) -> bool:
    return bool(re.fullmatch(r"[A-Za-z0-9]{8,15}", license_number))
