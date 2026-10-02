from __future__ import annotations

import io
import logging
import os
import sys
import traceback
from datetime import datetime
from typing import Any, Dict, List

from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image, UnidentifiedImageError

from ai.gemini_service import GeminiServiceError, GeminiVisionService
from reports.report_generator import build_report_payload
from rules.rule_engine import evaluate_extraction
from storage import get_storage

# ===== DEBUG LOGGING =====
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("cyber_nova")
logger.setLevel(logging.DEBUG)

load_dotenv(Path(__file__).resolve().parent / ".env")

logger.info("=" * 60)
logger.info("Cyber Nova Backend starting up")
_key = os.getenv("GEMINI_API_KEY") or ""
logger.info("GEMINI_API_KEY loaded: %s (len=%d)" % ("YES" if _key else "NO", len(_key)))
logger.info("GEMINI_MODEL: %s" % (os.getenv("GEMINI_MODEL") or "(default)"))
logger.info("=" * 60)

app = FastAPI(title="Cyber Nova Backend", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_gemini: GeminiVisionService | None = None


def _next_inspection_id() -> str:
    return get_storage().next_inspection_id()


def _get_gemini() -> GeminiVisionService:
    global _gemini
    if _gemini is None:
        _gemini = GeminiVisionService()
    return _gemini


def _validate_image(image_bytes: bytes) -> str:
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Missing image.")
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            img.verify()
            fmt = (img.format or "").upper()
    except UnidentifiedImageError as exc:
        raise HTTPException(status_code=400, detail="Invalid image.") from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid image.") from exc

    mime = {
        "JPEG": "image/jpeg",
        "JPG": "image/jpeg",
        "PNG": "image/png",
        "WEBP": "image/webp",
        "GIF": "image/gif",
    }.get(fmt)
    if not mime:
        raise HTTPException(status_code=400, detail="Invalid image.")
    return mime


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok", "service": "Cyber Nova Backend"}


@app.post("/api/inspection/scan")
async def scan_label(request: Request, images: List[UploadFile] = File(...)):
    logger.info("[scan] INCOMING  num_images=%d" % len(images))
    if not images:
        logger.warning("[scan] REJECT: no images provided")
        raise HTTPException(status_code=400, detail="Please add at least one product image.")

    processed: list[tuple[bytes, str]] = []
    for idx, image in enumerate(images):
        logger.info("[scan] Image %d: file=%s  type=%s" % (idx + 1, image.filename, image.content_type))
        if not image.filename and not image.content_type:
            logger.warning("[scan] REJECT image %d: no filename / no content_type" % (idx + 1))
            raise HTTPException(status_code=400, detail="Missing image.")
        image_bytes = await image.read()
        if not image_bytes:
            logger.warning("[scan] REJECT image %d: empty file bytes" % (idx + 1))
            raise HTTPException(status_code=400, detail="Missing image.")
        logger.info("[scan] Image %d size: %d bytes" % (idx + 1, len(image_bytes)))
        mime_type = _validate_image(image_bytes)
        logger.info("[scan] Image %d validated mime type: %s" % (idx + 1, mime_type))
        processed.append((image_bytes, mime_type))

    try:
        logger.info("[scan] STEP 1/3 - Calling GeminiVisionService.extract_multi() ...")
        extraction = _get_gemini().extract_multi(processed)
        logger.info("[scan] STEP 1/3 OK - extraction returned")

        insp_id = _next_inspection_id()
        logger.info("[scan] STEP 2/3 - Running rule engine (id=%s) ..." % insp_id)
        result = evaluate_extraction(extraction, insp_id)
        logger.info("[scan] STEP 2/3 OK - overall_status=%s" % result.overall_status)

        payload = result.model_dump()
        logger.info("[scan] STEP 3/3 - Building report payload ...")
        payload["report"] = build_report_payload(payload)
        logger.info("[scan] STEP 3/3 OK - DONE, returning response")
        return payload

    except GeminiServiceError as exc:
        if exc.code == "invalid_api_key":
            status = 401
        elif exc.code == "rate_limit":
            status = 429
        elif exc.code == "model_not_found":
            status = 500
        elif exc.code == "all_models_unavailable":
            status = 503
        elif exc.code == "content_blocked":
            status = 451
        else:
            status = 502
        tb = traceback.format_exc()
        logger.error("[scan] GeminiServiceError code=%s:\n%s\n%s" % (exc.code, exc, tb))
        raise HTTPException(
            status_code=status,
            detail="%s  [code=%s]" % (exc, exc.code),
        ) from exc

    except HTTPException:
        raise

    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc()
        logger.error("[scan] UNEXPECTED EXCEPTION %s: %s\n%s" % (type(exc).__name__, exc, tb))
        return JSONResponse(
            status_code=502,
            content={
                "detail": (
                    "Backend error: [%s] %s\n\n"
                    "Please check the black backend console window for the full Python traceback."
                ) % (type(exc).__name__, exc),
                "debug_error_type": type(exc).__name__,
            },
        )


@app.post("/api/inspection/save")
async def save_inspection_endpoint(request: Request):
    try:
        payload: Dict[str, Any] = await request.json()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid JSON body.") from exc
    try:
        report_id = get_storage().save_inspection(payload)
        logger.info("[inspection/save] stored report_id=%s" % report_id)
        return {"status": "ok", "report_id": report_id}
    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc()
        logger.error("[inspection/save] ERROR: %s\n%s" % (exc, tb))
        raise HTTPException(status_code=500, detail="Storage error: %s" % exc) from exc


@app.get("/api/inspection/list")
def list_inspections_endpoint(limit: int = 50):
    try:
        rows = get_storage().list_inspections(limit=limit)
        return {"count": len(rows), "items": rows}
    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc()
        logger.error("[inspection/list] ERROR: %s\n%s" % (exc, tb))
        raise HTTPException(status_code=500, detail="Storage error.") from exc


@app.get("/api/inspection/{report_id}")
def get_inspection_endpoint(report_id: str):
    try:
        row = get_storage().get_inspection(report_id)
    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc()
        logger.error("[inspection/get] ERROR: %s\n%s" % (exc, tb))
        raise HTTPException(status_code=500, detail="Storage error.") from exc
    if row is None:
        raise HTTPException(status_code=404, detail="Inspection not found.")
    return row


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        reload=True,
    )
