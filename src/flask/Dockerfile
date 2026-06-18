# syntax=docker/dockerfile:1.4
FROM --platform=linux/amd64 python:3.10-alpine AS builder

WORKDIR /src
COPY requirements.txt /src
RUN pip3 install -r requirements.txt

COPY . .

CMD ["gunicorn", "-w", "5", "-k", "gthread", "--threads", "4", "-b", "0.0.0.0:9091", "server:app"]
