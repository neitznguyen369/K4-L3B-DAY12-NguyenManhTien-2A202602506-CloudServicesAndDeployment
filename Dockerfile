# ── Stage 1: builder — cài dependency vào virtualenv riêng ──────────
FROM python:3.11-slim AS builder

WORKDIR /build

ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements trước, cài xong mới copy source → tận dụng layer cache
COPY requirements.txt .
RUN pip install -r requirements.txt

# ── Stage 2: runtime — chỉ mang theo venv + source ──────────────────
FROM python:3.11-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# User thường, không có shell đăng nhập
RUN groupadd --system app && useradd --system --gid app --no-create-home app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app ./app
COPY --chown=app:app utils ./utils

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import os, urllib.request; urllib.request.urlopen('http://localhost:%s/health' % os.environ.get('PORT', '8000'), timeout=3)"

# Shell form để $PORT được thay thế lúc chạy; exec để uvicorn nhận SIGTERM trực tiếp
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
