from __future__ import annotations

import json
import re
from pathlib import Path

from models.schemas import (
    ComplianceCheckResult,
    ComplianceSummary,
    ExtractionResult,
    InspectionResponse,
)
from rules.validators import (
    get_confidence,
    get_evidence,
    get_exact_text,
    get_extracted_text,
    manufacturer_party,
    mrp_present,
    net_quantity_present,
)

CONFIDENCE_REVIEW_THRESHOLD = 0.75
RULE_MASTER_PATH = Path(__file__).with_name("rule_master.json")

PROTOTYPE_NOTICE = (
    "MVP prototype checks only. These are not a complete Legal Metrology "
    "rule database and must be verified against authoritative current sources."
)

DISCLAIMER = (
    "AI-assisted preliminary compliance assessment. Final determination "
    "requires authorized inspection and applicable legal procedures."
)


def load_rule_master() -> dict:
    with RULE_MASTER_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _status_for_presence(
    present: bool,
    confidence: float,
    mandatory: bool,
) -> str:
    if not present:
        return "FAIL" if mandatory else "REVIEW"
    if confidence < CONFIDENCE_REVIEW_THRESHOLD:
        return "REVIEW"
    return "PASS"


def _reason(status: str, field_label: str, present: bool, confidence: float, photo_count: int = 1) -> str:
    photos = "any of the provided photos" if photo_count > 1 else "the label"
    if status == "FAIL":
        return f"{field_label} was not detected on the product in {photos}."
    if status == "REVIEW":
        if not present:
            return (
                f"{field_label} was not clearly visible in {photos} "
                f"and needs human verification."
            )
        return (
            f"{field_label} was detected with low/uncertain confidence "
            f"({confidence:.2f}) and needs human verification."
        )
    return f"{field_label} detected with sufficient confidence ({confidence:.2f})."


_ENGLISH_RE = re.compile(r"[a-zA-Z]{3,}")
_DEVANAGARI_RE = re.compile(r"[\u0900-\u097F]+")
_MISLEADING_QTY_RE = re.compile(
    r"\b(minimum|not\s+less\s+than|average|about|approximately)\b",
    re.IGNORECASE,
)
_PROMO_SIZE_RE = re.compile(
    r"\b(jumbo|family\s*size|king\s*size)\b",
    re.IGNORECASE,
)
_NON_STANDARD_UNIT_RE = re.compile(
    r"\b(ounce|oz|pound|lb|lbs|quart|tola|tole|sèr|ser)\b",
    re.IGNORECASE,
)
_NUMBER_QTY_RE = re.compile(
    r"\b(dozen|pack|case|piece|pcs|pc|count|nos)\b",
    re.IGNORECASE,
)
_STANDARD_WM_UNIT_RE = re.compile(
    r"\b(g|kg|gm|gram|grams|mg|l|ml|litre|liter|litres|metre|meter|m|cm|mm)\b",
    re.IGNORECASE,
)


def _detect_languages(extraction: ExtractionResult) -> tuple[bool, bool, float, str]:
    buf = []

    def append(field):
        exact = get_exact_text(field)
        if exact:
            buf.append(exact)
        value = get_extracted_text(field)
        if value:
            buf.append(value)
        ev = get_evidence(field)
        if ev:
            buf.append(ev)

    for key in [
        "product_name",
        "manufacturer",
        "packer",
        "importer",
        "address",
        "country_of_origin",
        "packing_date",
        "best_before",
        "consumer_care",
        "batch_number",
        "unit_sale_price",
    ]:
        append(getattr(extraction, key, None))
    for item in extraction.other_declarations or []:
        buf.append(str(item))

    haystack = " ".join(buf)
    eng = bool(_ENGLISH_RE.search(haystack))
    hindi = bool(_DEVANAGARI_RE.search(haystack))

    conf = 0.0
    if eng:
        conf += 0.5
    if hindi:
        conf += 0.5

    if eng and hindi:
        label = "English + Hindi (Devanagari)"
    elif eng:
        label = "English"
    elif hindi:
        label = "Hindi (Devanagari)"
    else:
        label = "Not detected"
    return eng, hindi, conf, label


def _get_source_index(field) -> int | None:
    data = field
    if hasattr(field, "model_dump"):
        data = field.model_dump()
    if isinstance(data, dict):
        idx = data.get("source_image_index")
        if isinstance(idx, int):
            return idx
    return None


def evaluate_extraction(extraction: ExtractionResult, inspection_id: str) -> InspectionResponse:
    rules = load_rule_master()
    party_value, party_conf, party_text, party_evidence = manufacturer_party(extraction)
    party_source_idx: int | None = None
    for candidate in [extraction.manufacturer, extraction.packer, extraction.importer]:
        if get_extracted_text(candidate) is not None:
            idx = _get_source_index(candidate)
            if idx is not None:
                party_source_idx = idx
                break

    eng, hindi, lang_conf, lang_label = _detect_languages(extraction)
    lang_field = extraction.language_of_declarations
    if hasattr(lang_field, "value"):
        if not lang_field.value or not str(lang_field.value).strip():
            lang_field.value = lang_label
        if (lang_field.confidence or 0.0) < lang_conf:
            lang_field.confidence = lang_conf
        lang_field.exact_visible_text = lang_label
        lang_field.evidence_description = (
            f"Declared-language heuristic: English={eng}, Hindi(Devanagari)={hindi} "
            f"based on visible text of all declarations."
        )

    field_map = {
        "product_name": extraction.product_name,
        "manufacturer_party": {
            "value": party_value,
            "confidence": party_conf,
            "exact_visible_text": party_text,
            "evidence_description": party_evidence,
            "source_image_index": party_source_idx,
        },
        "net_quantity": extraction.net_quantity,
        "mrp": extraction.mrp,
        "consumer_care": extraction.consumer_care,
        "country_of_origin": extraction.country_of_origin,
        "packing_date": extraction.packing_date,
        "unit_sale_price": extraction.unit_sale_price,
        "batch_number": extraction.batch_number,
    }

    checks: list[ComplianceCheckResult] = []
    for rule_id, rule in rules.items():
        field_key = rule["field"]
        validation_type = rule.get("validation_type", "presence")
        mandatory = bool(rule.get("mandatory", False))
        severity = rule.get("severity", "MEDIUM")
        explanation = rule.get("explanation")
        rule_ref = rule["rule_reference"]
        requirement = rule["requirement"]
        req_label = requirement.split(" should")[0].split(",")[0].strip()

        if validation_type == "language_presence":
            any_detected = eng or hindi
            status = "PASS" if any_detected else "REVIEW"
            if status == "PASS":
                reason = (
                    "At least one of English or Hindi (Devanagari script) "
                    "detected with sufficient confidence."
                )
            else:
                reason = (
                    "Neither English nor Hindi (Devanagari script) could be "
                    "reliably detected from the visible text. Please verify the "
                    "language of declarations manually. NOTE: OCR uncertainty "
                    "alone is NOT a finding of non-compliance."
                )
            checks.append(
                ComplianceCheckResult(
                    rule_id=rule_id,
                    rule_reference=rule_ref,
                    field=field_key,
                    requirement=requirement,
                    status=status,  # type: ignore[arg-type]
                    reason=reason,
                    confidence=lang_conf,
                    severity=severity,
                    mandatory=mandatory,
                    explanation=explanation,
                    exact_visible_text=lang_label,
                    evidence_description=lang_label,
                )
            )
            continue

        if validation_type == "quantity_expression_prohibited":
            exact_qty = (get_exact_text(extraction.net_quantity) or "").lower()
            evidence_qty = (get_evidence(extraction.net_quantity) or "").lower()
            other_buf = " ".join(
                str(x).lower() for x in (extraction.other_declarations or [])
            )

            prohibited_in_qty = bool(
                _MISLEADING_QTY_RE.search(exact_qty)
                or _MISLEADING_QTY_RE.search(evidence_qty)
            )
            prohibited_elsewhere = (
                not prohibited_in_qty and bool(_MISLEADING_QTY_RE.search(other_buf))
            )

            promo_in_qty = bool(
                _PROMO_SIZE_RE.search(exact_qty)
                or _PROMO_SIZE_RE.search(evidence_qty)
            )
            promo_elsewhere = (
                not promo_in_qty and bool(_PROMO_SIZE_RE.search(other_buf))
            )

            qty_numeric_missing = not net_quantity_present(extraction.net_quantity)

            status: str
            reason: str
            conf: float
            match_word: str = ""
            exact_match_in_qty = False

            if prohibited_in_qty:
                status = "FAIL"
                m = _MISLEADING_QTY_RE.search(exact_qty or evidence_qty)
                match_word = m.group(0) if m else "qualifier"
                reason = (
                    f'Potentially misleading quantity qualifier "{match_word}" was '
                    f"detected inside or adjacent to the net quantity declaration text. Per Rule "
                    f"12(6) the net quantity itself should not use words such as "
                    f'"minimum", "not less than", "average", "about" or '
                    f'"approximately". Please verify context with the inspector.'
                )
                conf = 0.8
                exact_match_in_qty = True
            elif promo_in_qty and qty_numeric_missing:
                status = "REVIEW"
                m = _PROMO_SIZE_RE.search(exact_qty or evidence_qty)
                match_word = m.group(0) if m else "promo size"
                reason = (
                    f'Promotional size expression "{match_word}" appears in or near '
                    f"the quantity declaration area AND a distinct numeric/standard-unit "
                    f"net quantity declaration was not clearly detected. Per Rule 12(6), "
                    f"marketing qualifiers must not replace the statutory quantity "
                    f"declaration. Inspector review is required."
                )
                conf = 0.7
                exact_match_in_qty = True
            elif promo_in_qty:
                status = "REVIEW"
                m = _PROMO_SIZE_RE.search(exact_qty or evidence_qty)
                match_word = m.group(0) if m else "promo size"
                reason = (
                    f'Promotional qualifier "{match_word}" was detected near the net '
                    f"quantity declaration. A numeric quantity declaration IS present, "
                    f"so this is informational and not an automatic Rule 12(6) "
                    f"violation. Verify that the marketing phrase does not distort "
                    f"the declared quantity."
                )
                conf = 0.55
                exact_match_in_qty = True
            elif prohibited_elsewhere:
                status = "REVIEW"
                m = _MISLEADING_QTY_RE.search(other_buf)
                match_word = m.group(0) if m else "qualifier"
                reason = (
                    f'A potentially misleading quantity qualifier "{match_word}" was '
                    f"detected elsewhere on the package (outside the net quantity "
                    f'declaration, e.g. "about 10 servings"). This does NOT '
                    f"automatically indicate a Rule 12(6) violation. Human review "
                    f"of context is required."
                )
                conf = 0.45
            elif promo_elsewhere:
                status = "REVIEW"
                m = _PROMO_SIZE_RE.search(other_buf)
                match_word = m.group(0) if m else "promo size"
                reason = (
                    f'Promotional size expression "{match_word}" was detected on the '
                    f"package outside the quantity declaration (e.g. branding area). "
                    f"This is informational only and NOT a Rule 12(6) violation by "
                    f"itself. Confirm that the phrase does not compete with or "
                    f"contradict the actual quantity declaration."
                )
                conf = 0.35
            else:
                status = "PASS"
                reason = (
                    "No prohibited qualifying words were detected in the net "
                    "quantity declaration. Promotional qualifiers (if any) were "
                    "not found adjacent to the statutory quantity field."
                )
                conf = 0.85

            checks.append(
                ComplianceCheckResult(
                    rule_id=rule_id,
                    rule_reference=rule_ref,
                    field=field_key,
                    requirement=requirement,
                    status=status,  # type: ignore[arg-type]
                    reason=reason,
                    confidence=conf,
                    severity=severity,
                    mandatory=mandatory,
                    explanation=explanation,
                    exact_visible_text=(
                        exact_qty if exact_match_in_qty and exact_qty else None
                    ),
                    evidence_description=reason,
                )
            )
            continue

        if validation_type == "non_standard_unit":
            exact_qty = (get_exact_text(extraction.net_quantity) or "").lower()
            value_qty = (get_extracted_text(extraction.net_quantity) or "").lower()
            evidence_qty = (get_evidence(extraction.net_quantity) or "").lower()
            qty_dict = extraction.net_quantity
            if hasattr(qty_dict, "model_dump"):
                qty_dict = qty_dict.model_dump()
            unit_qty = ""
            if isinstance(qty_dict, dict):
                unit_qty = str(qty_dict.get("unit") or "").lower()
            other_buf = " ".join(
                str(x).lower() for x in (extraction.other_declarations or [])
            )

            qty_combined = f"{exact_qty} {value_qty} {evidence_qty} {unit_qty}"

            has_non_standard_in_qty = bool(_NON_STANDARD_UNIT_RE.search(qty_combined))
            has_non_standard_elsewhere = (
                not has_non_standard_in_qty and bool(_NON_STANDARD_UNIT_RE.search(other_buf))
            )
            has_number_qty_in_decl = bool(_NUMBER_QTY_RE.search(qty_combined))
            has_standard_wm = bool(_STANDARD_WM_UNIT_RE.search(qty_combined))

            exact_out = exact_qty or None
            if has_non_standard_in_qty:
                status = "REVIEW"  # type: ignore[assignment]
                m = _NON_STANDARD_UNIT_RE.search(qty_combined)
                mw = m.group(0) if m else "non-standard unit"
                reason = (
                    f'A non-standard or tradition-based unit ("{mw}") was detected '
                    f"within or adjacent to the declared net quantity. Per Rule 13, "
                    f"the declaration shall use the standard units of weight, measure, "
                    f"or number prescribed by the Rules. Inspector to verify whether "
                    f"the unit is permissible for this commodity class and whether a "
                    f"standard-unit equivalent is also present."
                )
                conf = 0.75
            elif has_number_qty_in_decl and not has_standard_wm:
                status = "REVIEW"  # type: ignore[assignment]
                m = _NUMBER_QTY_RE.search(qty_combined)
                mw = m.group(0) if m else "number-based declaration"
                reason = (
                    f'The quantity declaration appears to be number-based ("{mw}") '
                    f"without a standard weight/measure unit. Per Rule 13, declaration "
                    f"by number is permissible only for the commodities to which the "
                    f"relevant schedule applies. Inspector to confirm commodity "
                    f"class-eligibility and whether a weight/measure declaration was "
                    f"also expected."
                )
                conf = 0.6
            elif has_non_standard_elsewhere:
                status = "PASS"  # type: ignore[assignment]
                m = _NON_STANDARD_UNIT_RE.search(other_buf)
                mw = m.group(0) if m else "unit mention"
                reason = (
                    f'A potentially non-standard unit ("{mw}") was mentioned '
                    f"elsewhere on the package but NOT within the net quantity "
                    f"declaration itself. Rule 13 governs the declared quantity; "
                    f"informational mentions elsewhere are not a violation by "
                    f"themselves."
                )
                conf = 0.8
                exact_out = None
            elif not net_quantity_present(extraction.net_quantity):
                status = "PASS"  # type: ignore[assignment]
                reason = (
                    "Net quantity was not clearly detected; non-standard-unit "
                    "check is skipped for this rule pass. Presence/adequacy of the "
                    "quantity declaration is addressed by the separate LM-003 check."
                )
                conf = 0.5
                exact_out = None
            else:
                status = "PASS"  # type: ignore[assignment]
                reason = (
                    "The declared net quantity appears to use a standard unit "
                    "(weight, measure, or number) consistent with Rule 13. "
                    "Inspector to confirm commodity-class appropriateness at final "
                    "verification."
                )
                conf = 0.85
                exact_out = None

            checks.append(
                ComplianceCheckResult(
                    rule_id=rule_id,
                    rule_reference=rule_ref,
                    field=field_key,
                    requirement=requirement,
                    status=status,  # type: ignore[arg-type]
                    reason=reason,
                    confidence=conf,
                    severity=severity,
                    mandatory=mandatory,
                    explanation=explanation,
                    exact_visible_text=exact_out,
                    evidence_description=reason,
                )
            )
            continue

        field = field_map.get(field_key)
        if field is None:
            continue

        confidence = get_confidence(field)
        exact = get_exact_text(field)
        evidence = get_evidence(field)
        source_idx = _get_source_index(field)

        present: bool
        if field_key == "net_quantity":
            present = net_quantity_present(field)
        elif field_key == "mrp":
            present = mrp_present(field)
        else:
            present = get_extracted_text(field) is not None

        status = _status_for_presence(present, confidence, mandatory)
        reason = _reason(status, req_label, present, confidence)

        checks.append(
            ComplianceCheckResult(
                rule_id=rule_id,
                rule_reference=rule_ref,
                field=field_key,
                requirement=requirement,
                status=status,  # type: ignore[arg-type]
                reason=reason,
                confidence=confidence,
                severity=severity,
                mandatory=mandatory,
                explanation=explanation,
                exact_visible_text=exact,
                evidence_description=evidence,
                source_image_index=source_idx,
            )
        )

    passed = sum(1 for c in checks if c.status == "PASS")
    failed = sum(1 for c in checks if c.status == "FAIL")
    review = sum(1 for c in checks if c.status == "REVIEW")

    if any(c.status == "FAIL" and c.mandatory for c in checks):
        overall = "NON_COMPLIANT"
    elif review > 0 or failed > 0:
        overall = "MANUAL_REVIEW"
    else:
        overall = "COMPLIANT"

    return InspectionResponse(
        inspection_id=inspection_id,
        extraction=extraction.model_dump(),
        checks=checks,
        summary=ComplianceSummary(passed=passed, failed=failed, review=review),
        overall_status=overall,  # type: ignore[arg-type]
        disclaimer=DISCLAIMER,
        prototype_notice=PROTOTYPE_NOTICE,
    )
