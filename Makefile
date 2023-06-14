# === Linter's commands ===
black:
	poetry run black . $(args)

lint:
	poetry run flake8 $(args)
	poetry run xenon .

isort:
	poetry run isort . $(args)

mypy:
	poetry run mypy . $(args)

fmt: black isort lint


# === Terraform commands ===
plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

tfmt:
	terraform fmt -recursive

tvld:
	terraform validate


# === Back-end commands ===
requirements:
	poetry export --without-hashes --only main -f requirements.txt -o requirements.txt

run:
	poetry run gunicorn src.apps.main:app -c gunicorn.conf.py
