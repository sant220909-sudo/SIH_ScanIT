# Cyber Nova — SIH 2026 MVP

AI-assisted Legal Metrology packaged-commodity label inspection.

Gemini extracts visible label text. The Python rule engine applies prototype compliance checks. A human verifies the result. Cyber Nova does not replace an authorized inspector.

## 1. Backend (FastAPI)

```powershell
cd "C:\Users\soham\OneDrive\Desktop\Food Scanner\cyber_nova_backend"
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Put your Gemini key only in:

`cyber_nova_backend/.env`

```
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
```

Copy the value from `.env.example` and paste your real key after `GEMINI_API_KEY=`.

Never put the key in Flutter, assets, or git.

Health check: http://localhost:8000/api/health

Scan endpoint: `POST http://localhost:8000/api/inspection/scan` (multipart field `image`)

## 2. Flutter app

```powershell
cd "C:\Users\soham\OneDrive\Desktop\Food Scanner"
set PATH=C:\flutter\bin;%PATH%
flutter pub get
flutter run -d chrome
```

Optional backend URL override:

```powershell
flutter run -d chrome --dart-define=BACKEND_URL=http://localhost:8000
```

Android emulator default: `http://10.0.2.2:8000`

Physical phone: pass your PC LAN IP, for example:

```powershell
flutter run --dart-define=BACKEND_URL=http://192.168.1.10:8000
```

## 3. Sample image test

1. Start the backend.
2. Start Flutter.
3. Tap **Use Sample Product**.
4. The app sends `assets/images/sample_product_label.jpg` through the same FastAPI → Gemini → rule engine pipeline.

Backend-only test:

```powershell
cd cyber_nova_backend
venv\Scripts\activate
python test_gemini.py
```
