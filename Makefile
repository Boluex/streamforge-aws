ENV ?= dev
.PHONY: validate fmt init plan
validate:
	bash scripts/validate.sh
fmt:
	terraform fmt -recursive
init:
	terraform -chdir=environments/$(ENV) init
plan:
	terraform -chdir=environments/$(ENV) plan
