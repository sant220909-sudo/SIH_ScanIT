from __future__ import annotations

import json
import logging
import os
import re
from typing import Any

from google import genai
from google.genai import types
from pydantic import ValidationError

from models.schemas import ExtractionResult

_logger = logging.getLogger("gemini_service")

SYSTEM_PROMPT = """You are the visual extraction component of Cyber Nova, an AI-assisted Legal Metrology packaged-commodity inspection system for India.

CORE INSTRUCTION: You are analyzing multiple images of the SAME packaged commodity. These images may show different sides or portions of the same package. Combine information across all images. Do not duplicate information. If a declaration is visible in any image, use it. Do not guess information that is not visible.

Treat this first and foremost as a PRECISE OCR task. You must read every piece of visible text on the product packaging, including small print, corners, bottom edges, and side panels. Do NOT restrict yourself to large or prominent text.

Your responsibility is to inspect the supplied product label images and extract information that is visibly present on the packaging.

You are NOT the final legal compliance authority.

DO NOT guess.

If information is truly not visible AT ALL, return null.

HOWEVER — if information is partially visible, slightly blurred, or in a small font but still readable by a human, you MUST extract it with an appropriately reduced confidence (0.4-0.7). DO NOT return null just because text is small or slightly unclear.

Preserve the visible text as accurately as possible, including exact wording, capitalisation, and numbers.

PRIORITY EXTRACTION LIST (scan the ENTIRE label for these fields):

1. Common / generic product name
2. Manufacturer — Mfg. by, Manufactured by, Manufacturer
3. Packer — Packed by, Mkt. by, Marketed by, Packer
4. Importer — Imported by, Importer
5. Complete postal address of any of the above parties (including street, city, district, pin code)
6. Country of origin — Made in, Country of Origin, Origin
7. Net quantity — NET WT, Net Qty, Net Weight, Net Volume, followed by number + unit
   UNITS TO RECOGNISE: g, gm, gram, grams, kg, kilogram, ml, milliliter, L, ltr, litre, liter, nos, no, pieces, pcs, piece, count, unit
8. Unit (as above)
9. MRP / Maximum Retail Price — HIGHEST PRIORITY
   SPECIFIC MRP PATTERNS: Look carefully for ANY of the following:
     • Text labels: "MRP", "M.R.P.", "MRP:", "M.R.P:", "Maximum Retail Price", "Max Retail Price", "Max. Ret. Price"
     • Currency symbols: ₹ (Indian Rupee sign), Rs, Rs., INR, Re, Re.
     • Tax notes: "Incl. of all taxes", "Inclusive of all taxes", "incl taxes", "(incl. of all taxes)"
     • Suffix: /- (rupee suffix), .00, .50, .95, .99, .25 and other 2-decimal endings
   EXAMPLES:
     "MRP ₹350.00/- (Incl. of all taxes)"  → value=350.00, currency=INR
     "Maximum Retail Price: Rs. 99.50"      → value=99.50, currency=INR
     "₹25/-"                                → value=25.0, currency=INR
   If you see ANY number adjacent to a rupee symbol or MRP label, extract it.
10. MRP currency — almost always INR for Indian products; if unsure, default to "INR"
11. Manufacturing / packing / import date where visible
    DATE PATTERNS: MFD, Mfg, Mfg., Pkd, Pkd., Packed, Dt, followed by MM/YY, MM/YYYY, MMM YYYY (e.g. MAR 2026), or Month Year
12. Best before / use by / expiry date where visible
13. Consumer care name / contact — "Consumer Care", "Customer Care", "For complaints contact:", toll-free numbers, addresses
14. Email address (if visible)
15. Phone / mobile / landline / toll-free numbers
16. Unit sale price where visible (e.g. "Price per 100g: ₹X")
17. Batch / lot number — Batch No., Lot No., B. No., followed by alphanumeric code
18. Language of declarations: detect whether English (Latin script a-z/A-Z) and/or Hindi (Devanagari script Unicode U+0900-U+097F) are visibly present in the declarations across the images
19. Other important declarations (FSSAI logo/number, veg/non-veg mark, barcode text, etc.)

For EVERY field return an object with:
- value: the extracted normalised value (string or number as appropriate)
- exact_visible_text: the exact raw text as printed on the package, character-for-character where possible
- confidence: a number between 0 and 1 (0.0 = pure guess, 1.0 = perfectly clear print)
- evidence_description: short sentence describing where on the package you found it and which photo it came from (e.g. "Photo 2, lower right area near barcode")
- source_image_index: 1-based index of the photo from the supplied image list in which this declaration was most clearly visible. If it appeared in multiple photos, prefer the clearest one. If uncertain or from combined evidence across photos, set to null.

IMPORTANT CONFIDENCE RULES (do NOT skip extraction just because text is imperfect):
- Confidence 0.9–1.0: perfectly clear, large, perfectly-printed black text on white background
- Confidence 0.7–0.9: normal clear label print with minor imperfections
- Confidence 0.4–0.7: small font, slightly blurry, partial occlusion, uneven lighting, slight angle → STILL EXTRACT THE VALUE
- Confidence 0.1–0.3: only a fragment visible, very uncertain
- Confidence 0.0 or null: genuinely nothing visible at all

Return structured JSON only. Use this exact shape:

{
  "product_name": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "manufacturer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "packer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "importer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "address": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "country_of_origin": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "net_quantity": {"value": 0, "unit": "g", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "mrp": {"value": 0, "currency": "INR", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "packing_date": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "best_before": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "consumer_care": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "email": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "phone": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "unit_sale_price": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "batch_number": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "language_of_declarations": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "...", "source_image_index": null},
  "other_declarations": [],
  "overall_confidence": 0.0
}

Never invent missing information. If you cannot read a field but can see a fragment, return the fragment with low confidence instead of null.

Do NOT decide whether the product is compliant. That is the rule engine's job.
"""


class GeminiServiceError(Exception):
    def __init__(self, message: str, code: str = "gemini_error"):
        super().__init__(message)
        self.code = code


def _sanitize_error_text(text: str) -> str:
    return re.sub(r"(?i)(api[_-]?key|token)[=:\s]+[^\s,;]+", r"\1=[redacted]", text)


def _parse_json_payload(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise GeminiServiceError(
            "Invalid Gemini response. The model did not return valid JSON.",
            code="invalid_gemini_response",
        ) from exc


_FALLBACK_MODELS: list[str] = [
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.0-flash",
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
]


class GeminiVisionService:
    def __init__(self) -> None:
        api_key = (os.getenv("GEMINI_API_KEY") or "").strip()
        if not api_key:
            raise GeminiServiceError(
                "Gemini API key is not configured on the server.",
                code="invalid_api_key",
            )
        self._model = os.getenv("GEMINI_MODEL", "gemini-3.6-flash").strip() or "gemini-3.6-flash"
        self._client = genai.Client(api_key=api_key)

    @staticmethod
    def _build_config() -> types.GenerateContentConfig:
        return types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            response_mime_type="application/json",
            temperature=0.3,
            top_p=0.95,
            automatic_function_calling=types.AutomaticFunctionCallingConfig(
                disable=True,
                maximum_remote_calls=10,
            ),
        )

    def _models_to_try(self) -> list[str]:
        models = [self._model]
        for name in _FALLBACK_MODELS:
            if name not in models:
                models.append(name)
        return models

    def extract(self, image_bytes: bytes, mime_type: str) -> ExtractionResult:
        return self.extract_multi([(image_bytes, mime_type)])

    def extract_multi(self, images: list[tuple[bytes, str]]) -> ExtractionResult:
        """Extract structured label information from multiple product photos.

        Each tuple is (image_bytes, mime_type). Images are treated as Photo 1,
        Photo 2, ... in the order provided (1-based source_image_index).
        """
        if not images:
            raise GeminiServiceError(
                "No images provided for analysis.",
                code="gemini_error",
            )

        num_images = len(images)
        photo_labels = ", ".join(
            f"Photo {i+1}" for i in range(num_images)
        )

        parts: list[types.Part] = []
        for idx, (img_bytes, mime) in enumerate(images):
            parts.append(
                types.Part.from_bytes(data=img_bytes, mime_type=mime),
            )

        user_text = (
            f"You have been given {num_images} product photos of the SAME "
            f"package ({photo_labels}). These images may show different sides "
            f"or portions of the same packaged commodity. Combine information "
            f"across all images. For every detected field, set "
            f"source_image_index to the 1-based index of the photo in which "
            f"the declaration was most clearly visible. SCAN EVERY PART OF "
            f"EVERY IMAGE. Highest priority: MRP, net quantity, dates, "
            f"manufacturer/packer/importer details, consumer care. Read "
            f"small fonts carefully."
        )
        parts.append(types.Part.from_text(text=user_text))

        user_contents = [
            types.Content(role="user", parts=parts),
        ]
        config = self._build_config()

        last_exc: Exception | None = None
        for model in self._models_to_try():
            try:
                _logger.info("[gemini] Trying model=%s", model)
                response = self._client.models.generate_content(
                    model=model,
                    contents=user_contents,
                    config=config,
                )
                _logger.info("[gemini] Model=%s succeeded", model)
                self._model = model
                break
            except Exception as exc:  # noqa: BLE001
                message = _sanitize_error_text(str(exc))
                lowered = message.lower()
                last_exc = exc

                if "api key" in lowered or "invalid_api_key" in lowered or "401" in lowered or "403" in lowered:
                    raise GeminiServiceError(
                        "Gemini rejected the server credentials. Check GEMINI_API_KEY.",
                        code="invalid_api_key",
                    ) from exc
                if "429" in lowered or "resource exhausted" in lowered or "rate" in lowered:
                    raise GeminiServiceError(
                        "Gemini rate limit reached. Please try again shortly.",
                        code="rate_limit",
                    ) from exc

                is_retryable_model_error = (
                    ("503" in lowered)
                    or ("unavailable" in lowered)
                    or ("high demand" in lowered)
                    or ("try again later" in lowered)
                    or ("404" in lowered and ("model" in lowered or "no longer available" in lowered))
                )
                if is_retryable_model_error:
                    _logger.warning(
                        "[gemini] Model=%s unavailable (%s), trying next fallback.",
                        model,
                        message.splitlines()[0][:200],
                    )
                    continue

                raise GeminiServiceError(
                    f"Unable to analyze the image. Underlying: {type(exc).__name__}: {message}",
                    code="gemini_error",
                ) from exc
        else:
            assert last_exc is not None
            raise GeminiServiceError(
                "All Gemini models are currently unavailable due to high demand "
                "(503 UNAVAILABLE). Wait 1-2 minutes and try again, or set a "
                "different GEMINI_MODEL in .env.",
                code="all_models_unavailable",
            ) from last_exc

        raw_text = ""
        top_text = getattr(response, "text", None)
        if top_text:
            raw_text = str(top_text)
        if not raw_text.strip():
            candidates = getattr(response, "candidates", None) or []
            parts_text: list[str] = []
            for cand in candidates:
                content = getattr(cand, "content", None)
                if content is None:
                    finish = getattr(cand, "finish_reason", None)
                    feedback = getattr(cand, "safety_ratings", None) or getattr(
                        cand, "citation_metadata", None
                    )
                    _logger.warning(
                        "[gemini] Candidate missing content. finish_reason=%s metadata=%s",
                        finish,
                        feedback,
                    )
                    continue
                for part in getattr(content, "parts", []) or []:
                    t = getattr(part, "text", None)
                    if t:
                        parts_text.append(str(t))
            if parts_text:
                raw_text = "\n".join(parts_text)

        pf = getattr(response, "prompt_feedback", None)
        if pf and not raw_text.strip():
            blocked = getattr(pf, "block_reason", None) or getattr(pf, "safety_ratings", None)
            raise GeminiServiceError(
                f"Gemini blocked the request. prompt_feedback={blocked}",
                code="content_blocked",
            )

        if not raw_text.strip():
            raise GeminiServiceError(
                "Invalid Gemini response. No extraction text was returned. "
                "The model may have returned no candidates or been safety-filtered.",
                code="invalid_gemini_response",
            )

        _logger.debug("[gemini] Raw response text (first 500 chars): %s", raw_text[:500])

        payload = _parse_json_payload(raw_text)
        try:
            return ExtractionResult.model_validate(payload, strict=False)
        except ValidationError as exc:
            _logger.error(
                "[gemini] Pydantic ValidationError on extraction payload:\n"
                "RAW_JSON=%s\n"
                "ERRORS=%s",
                json.dumps(payload)[:1500],
                exc.errors(),
            )
            raise GeminiServiceError(
                "Invalid Gemini response. Structured extraction could not be parsed.",
                code="invalid_gemini_response",
            ) from exc
