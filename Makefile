SHELL=/bin/bash

all: deps
deps:
	helm dependency update charts/helm-apps
	helm dependency update tests/.helm
save_tests:
	cd tests; helm template tests .helm --namespace test-prod --set "global._includes.apps-defaults.enabled=true" --set "global.env=prod" > test_render.yaml
test:
	cd tests; diff <(helm template tests .helm --namespace test-prod --set "global._includes.apps-defaults.enabled=true" --set "global.env=prod") test_render.yaml
