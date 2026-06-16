# syntax=docker/dockerfile:1.4
FROM --platform=linux/amd64 python:3.10-alpine AS builder

WORKDIR /src
COPY requirements.txt /src
RUN pip3 install -r requirements.txt

COPY . .

CMD ["python3", "server.py"]
