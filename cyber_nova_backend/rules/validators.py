from __future__ import annotations

from typing import Any, Optional

from models.schemas import ExtractedValue, ExtractionResult, MrpValue, QuantityValue


def _as_dict(obj: Any) -> dict:
    if obj is None:
        return {}
    if hasattr(obj, "model_dump"):
        return obj.model_dump()
    if isinstance(obj, dict):
        return obj
    return {}


def get_extracted_text(field: Any) -> Optional[str]:
    data = _as_dict(field)
    value = data.get("value")
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def get_confidence(field: Any) -> float:
    data = _as_dict(field)
    try:
        return float(data.get("confidence") or 0.0)
    except (TypeError, ValueError):
        return 0.0


def get_exact_text(field: Any) -> Optional[str]:
    data = _as_dict(field)
    text = data.get("exact_visible_text")
    if text is None:
        return None
    cleaned = str(text).strip()
    return cleaned or None


def get_evidence(field: Any) -> Optional[str]:
    data = _as_dict(field)
    text = data.get("evidence_description")
    if text is None:
        return None
    cleaned = str(text).strip()
    return cleaned or None


def manufacturer_party(extraction: ExtractionResult) -> tuple[Optional[str], float, Optional[str], Optional[str]]:
    candidates = [
        extraction.manufacturer,
        extraction.packer,
        extraction.importer,
    ]
    best: Optional[ExtractedValue] = None
    for item in candidates:
        if get_extracted_text(item) and (best is None or get_confidence(item) > get_confidence(best)):
            best = item
    if best is None:
        return None, 0.0, None, None
    return get_extracted_text(best), get_confidence(best), get_exact_text(best), get_evidence(best)


def net_quantity_present(field: QuantityValue | dict) -> bool:
    data = _as_dict(field)
    value = data.get("value")
    unit = data.get("unit")
    visible = get_exact_text(field)
    if value is not None and str(value).strip() != "":
        return True
    if unit and str(unit).strip():
        return True
    return bool(visible)


def mrp_present(field: MrpValue | dict) -> bool:
    data = _as_dict(field)
    value = data.get("value")
    visible = get_exact_text(field)
    if value is not None and str(value).strip() != "":
        return True
    return bool(visible)
