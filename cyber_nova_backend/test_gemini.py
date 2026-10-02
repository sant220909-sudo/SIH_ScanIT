from __future__ import annotations

import json
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from ai.gemini_service import GeminiVisionService  # noqa: E402
from rules.rule_engine import evaluate_extraction  # noqa: E402


def _sample_image_path() -> Path:
    candidates = [
        ROOT.parent / "assets" / "images" / "sample_product_label.jpg",
        ROOT / "sample_product_label.jpg",
    ]
    for path in candidates:
        if path.exists():
            return path
    raise FileNotFoundError(
        "Sample product image not found. Add: assets/images/sample_product_label.jpg"
    )


def main() -> None:
    path = _sample_image_path()
    image_bytes = path.read_bytes()
    mime = "image/jpeg" if path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
    print(f"Using sample image: {path.name}")
    extraction = GeminiVisionService().extract(image_bytes, mime)
    result = evaluate_extraction(extraction, "CN-TEST-0001")
    data = extraction.model_dump()

    def show(label: str, field: dict) -> None:
        value = field.get("value")
        extra = ""
        if "unit" in field and field.get("unit"):
            extra = f" {field.get('unit')}"
        if "currency" in field and field.get("currency"):
            extra = f" {field.get('currency')}"
        print(f"{label}: {value}{extra}")

    print("\nPRODUCT:")
    show("PRODUCT", data.get("product_name") or {})
    print("MRP:")
    show("MRP", data.get("mrp") or {})
    print("NET QUANTITY:")
    show("NET QUANTITY", data.get("net_quantity") or {})
    print("MANUFACTURER:")
    show("MANUFACTURER", data.get("manufacturer") or {})
    print("\nCOMPLIANCE:")
    print(result.overall_status)
    print(json.dumps(result.summary.model_dump(), indent=2))


if __name__ == "__main__":
    main()
