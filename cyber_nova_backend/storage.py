from __future__ import annotations

import json
import sqlite3
import threading
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

_DB_LOCK = threading.Lock()
_DEFAULT_DB_PATH = Path(__file__).resolve().parent / "inspections.db"


class InspectionStorage:
    def __init__(self, db_path: Path | None = None):
        self.db_path = db_path or _DEFAULT_DB_PATH
        self._conn: Optional[sqlite3.Connection] = None
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(
            str(self.db_path),
            check_same_thread=False,
            detect_types=sqlite3.PARSE_DECLTYPES,
        )
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    @property
    def conn(self) -> sqlite3.Connection:
        if self._conn is None:
            self._conn = self._connect()
        return self._conn

    def _ensure_schema(self) -> None:
        with _DB_LOCK, self.conn:
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS inspections (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    report_id TEXT NOT NULL UNIQUE,
                    product_name TEXT NOT NULL DEFAULT '',
                    overall_status TEXT NOT NULL DEFAULT 'MANUAL REVIEW',
                    inspection_date INTEGER NOT NULL,
                    summary_json TEXT NOT NULL DEFAULT '{}',
                    full_json TEXT NOT NULL DEFAULT '{}',
                    image_bytes_blob BLOB,
                    image_count INTEGER NOT NULL DEFAULT 1,
                    saved_at INTEGER NOT NULL
                )
                """
            )
            self.conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_inspections_date "
                "ON inspections(inspection_date DESC)"
            )

    def next_inspection_id(self, year: Optional[int] = None) -> str:
        target_year = year or datetime.now().year
        prefix = f"CN-{target_year}-"
        with _DB_LOCK:
            cur = self.conn.execute(
                "SELECT report_id FROM inspections WHERE report_id LIKE ? "
                "ORDER BY id DESC LIMIT 1",
                (prefix + "%",),
            )
            row = cur.fetchone()
            seq = 1
            if row is not None:
                rid = row["report_id"] or ""
                tail = rid[len(prefix):]
                if tail.isdigit():
                    try:
                        seq = int(tail) + 1
                    except ValueError:
                        seq = 1
                else:
                    seq = 1
            # Safety: count as fallback
            cur2 = self.conn.execute(
                "SELECT COUNT(*) AS cnt FROM inspections WHERE report_id LIKE ?",
                (prefix + "%",),
            )
            cnt_row = cur2.fetchone()
            cnt = (cnt_row["cnt"] or 0) + 1
            seq = max(seq, cnt)
            return f"{prefix}{seq:04d}"

    def save_inspection(self, payload: Dict[str, Any]) -> str:
        report_id = str(payload.get("report_id") or self.next_inspection_id())
        product_name = str(payload.get("product_name") or payload.get("productName") or "")
        overall_status = str(
            payload.get("overall_status")
            or payload.get("overallStatus")
            or "MANUAL REVIEW"
        )
        inspection_date_ms: int
        raw_date = payload.get("inspection_date") or payload.get("inspectionDate")
        if isinstance(raw_date, (int, float)):
            inspection_date_ms = int(raw_date)
        elif isinstance(raw_date, str) and raw_date:
            try:
                inspection_date_ms = int(datetime.fromisoformat(raw_date).timestamp() * 1000)
            except ValueError:
                inspection_date_ms = int(datetime.now().timestamp() * 1000)
        else:
            inspection_date_ms = int(datetime.now().timestamp() * 1000)

        summary = payload.get("summary") or payload.get("summary_json") or {}
        full = payload.get("full") or payload.get("full_json") or {}
        if isinstance(summary, (dict, list)):
            summary_str = json.dumps(summary, ensure_ascii=False)
        else:
            summary_str = str(summary)
        if isinstance(full, (dict, list)):
            full_str = json.dumps(full, ensure_ascii=False)
        else:
            full_str = str(full)

        image_bytes = payload.get("image_bytes") or payload.get("image_bytes_blob") or None
        if isinstance(image_bytes, str):
            import base64
            try:
                image_bytes = base64.b64decode(image_bytes)
            except Exception:
                image_bytes = None
        image_count = int(payload.get("image_count") or 1)
        saved_at = int(datetime.now().timestamp() * 1000)

        with _DB_LOCK, self.conn:
            self.conn.execute(
                """
                INSERT INTO inspections (
                    report_id, product_name, overall_status, inspection_date,
                    summary_json, full_json, image_bytes_blob, image_count, saved_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(report_id) DO UPDATE SET
                    product_name=excluded.product_name,
                    overall_status=excluded.overall_status,
                    inspection_date=excluded.inspection_date,
                    summary_json=excluded.summary_json,
                    full_json=excluded.full_json,
                    image_bytes_blob=excluded.image_bytes_blob,
                    image_count=excluded.image_count,
                    saved_at=excluded.saved_at
                """,
                (
                    report_id,
                    product_name,
                    overall_status,
                    inspection_date_ms,
                    summary_str,
                    full_str,
                    image_bytes,
                    image_count,
                    saved_at,
                ),
            )
        return report_id

    def list_inspections(self, limit: int = 50) -> List[Dict[str, Any]]:
        with _DB_LOCK:
            cur = self.conn.execute(
                """
                SELECT report_id, product_name, overall_status, inspection_date, image_count
                FROM inspections
                ORDER BY inspection_date DESC
                LIMIT ?
                """,
                (int(limit),),
            )
            rows = cur.fetchall()
        result: List[Dict[str, Any]] = []
        for r in rows:
            dt = datetime.fromtimestamp((r["inspection_date"] or 0) / 1000.0)
            result.append(
                {
                    "report_id": r["report_id"],
                    "product_name": r["product_name"],
                    "overall_status": r["overall_status"],
                    "inspection_date": dt.isoformat(),
                    "inspection_date_ms": r["inspection_date"],
                    "image_count": r["image_count"],
                }
            )
        return result

    def get_inspection(self, report_id: str) -> Optional[Dict[str, Any]]:
        with _DB_LOCK:
            cur = self.conn.execute(
                """
                SELECT report_id, product_name, overall_status, inspection_date,
                       summary_json, full_json, image_bytes_blob, image_count, saved_at
                FROM inspections WHERE report_id = ? LIMIT 1
                """,
                (report_id,),
            )
            row = cur.fetchone()
        if row is None:
            return None
        dt = datetime.fromtimestamp((row["inspection_date"] or 0) / 1000.0)
        saved_at_dt = datetime.fromtimestamp((row["saved_at"] or 0) / 1000.0)
        summary_obj: Any = {}
        try:
            summary_obj = json.loads(row["summary_json"] or "{}")
        except Exception:
            summary_obj = row["summary_json"]
        full_obj: Any = {}
        try:
            full_obj = json.loads(row["full_json"] or "{}")
        except Exception:
            full_obj = row["full_json"]
        import base64
        image_b64: Optional[str] = None
        if row["image_bytes_blob"]:
            try:
                image_b64 = base64.b64encode(bytes(row["image_bytes_blob"])).decode("ascii")
            except Exception:
                image_b64 = None
        return {
            "report_id": row["report_id"],
            "product_name": row["product_name"],
            "overall_status": row["overall_status"],
            "inspection_date": dt.isoformat(),
            "inspection_date_ms": row["inspection_date"],
            "summary": summary_obj,
            "full": full_obj,
            "image_bytes_base64": image_b64,
            "image_count": row["image_count"],
            "saved_at": saved_at_dt.isoformat(),
        }


_storage_singleton: Optional[InspectionStorage] = None


def get_storage() -> InspectionStorage:
    global _storage_singleton
    if _storage_singleton is None:
        _storage_singleton = InspectionStorage()
    return _storage_singleton
