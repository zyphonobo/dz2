# Образ приложения probe в два этапа. Вариант 03: базовый образ python:3.12-slim.

# ── Этап 1: сборка. Компилятор и заголовки нужны только здесь ──
FROM python:3.12-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libc6-dev libpq-dev default-libmysqlclient-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*
# зависимости собираются в виртуальное окружение — его можно перенести одним каталогом
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Этап 2: запуск. Чистый базовый образ + только библиотеки баз ──
FROM python:3.12-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 libmariadb3 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /venv /venv
ENV PATH=/venv/bin:$PATH

WORKDIR /app
COPY app.py .

ARG VERSION=5.0
RUN echo "$VERSION" > /app/VERSION

ENV PYTHONDONTWRITEBYTECODE=1
STOPSIGNAL SIGINT
CMD ["python", "app.py"]
