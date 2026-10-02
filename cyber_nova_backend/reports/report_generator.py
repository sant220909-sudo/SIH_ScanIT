from rules.rule_engine import DISCLAIMER, PROTOTYPE_NOTICE


def build_report_payload(inspection: dict) -> dict:
    """Assemble a print-ready report dictionary from an inspection result."""
    extraction = inspection.get("extraction") or {}
    product_name = ((extraction.get("product_name") or {}).get("value")) or "Unknown product"
    return {
        "title": "CYBER NOVA — LEGAL METROLOGY INSPECTION REPORT",
        "inspection_id": inspection.get("inspection_id"),
        "overall_status": inspection.get("overall_status"),
        "product_name": product_name,
        "extraction": extraction,
        "checks": inspection.get("checks") or [],
        "summary": inspection.get("summary") or {},
        "disclaimer": inspection.get("disclaimer") or DISCLAIMER,
        "prototype_notice": inspection.get("prototype_notice") or PROTOTYPE_NOTICE,
    }
