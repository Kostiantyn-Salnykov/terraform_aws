FROM python:3.11-slim

RUN apt-get -y update
RUN apt-get -y install curl
RUN apt-get -y install make

ENV PYTHONPATH=/backend
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY . /backend

WORKDIR /backend

RUN pip install -U pip setuptools

RUN pip install poetry

RUN make requirements

RUN pip install --no-cache-dir --upgrade -r /backend/requirements.txt

CMD ["make", "run"]
