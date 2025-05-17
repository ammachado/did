# Prepare variables
TMP = $(CURDIR)/tmp
VERSION = $(shell grep ^Version did.spec | sed 's/.* //')
PACKAGE = did-$(VERSION)
FILES = LICENSE README.rst \
		Makefile did.spec setup.py \
		examples did bin tests
ifndef USERNAME
    USERNAME = echo $$USER
endif


# Define special targets
all: docs packages
.PHONY: docs hooks

# Temporary directory, include .fmf to prevent exploring tests there
tmp:
	mkdir -p $(TMP)/.fmf

# Run the test suite, optionally with coverage
test: tmp
	DID_DIR=$(TMP) pytest -n auto tests
smoke: tmp
	DID_DIR=$(TMP) pytest -n auto tests/test_cli.py
coverage: tmp
	DID_DIR=$(TMP) pytest --cov-report html:cov_html --cov-report annotate:cov_annotate --cov=did -n auto tests

# Build documentation, prepare man page
docs: man
	cd docs && make html
man: source
	cp docs/header.txt $(TMP)/man.rst
	tail -n+7 README.rst | sed '/^Status/,$$d' >> $(TMP)/man.rst
	rst2man $(TMP)/man.rst | gzip > $(TMP)/$(PACKAGE)/did.1.gz


# RPM packaging
source:
	mkdir -p $(TMP)/SOURCES
	mkdir -p $(TMP)/$(PACKAGE)
	cp -a $(FILES) $(TMP)/$(PACKAGE)
	rm -rf $(TMP)/$(PACKAGE)/examples/mr.bob
tarball: source man
	cd $(TMP) && tar cfj SOURCES/$(PACKAGE).tar.bz2 $(PACKAGE)
	@echo ./tmp/SOURCES/$(PACKAGE).tar.bz2
version:
	@echo "$(VERSION)"
rpm: tarball
	rpmbuild --define '_topdir $(TMP)' -bb did.spec
srpm: tarball
	rpmbuild --define '_topdir $(TMP)' -bs did.spec
packages: rpm srpm


# Python packaging
wheel:
	python setup.py bdist_wheel
upload:
	twine upload dist/*.whl


# Git hooks, vim tags and cleanup
hooks:
	ln -snf ../../hooks/pre-commit .git/hooks
	ln -snf ../../hooks/commit-msg .git/hooks
tags:
	find did -name '*.py' | xargs ctags --python-kinds=-i
clean:
	rm -rf $(TMP) build dist
	find . -type f -name "*.py[co]" -delete
	find . -type f -name "*,cover" -delete
	find . -type d -name "__pycache__" -delete
	rm -rf docs/_build
	rm -f .coverage tags
	rm -rf .cache .pytest_cache
	rm -rf cov_annotate
	rm -rf cov_html


# Docker
run_docker: build_docker
	@echo
	@echo "Please note: this is a first cut at doing a container version as a result; known issues:"
	@echo "* GSSAPI auth may not be working correctly"
	@echo "* container runs as privileged to access the conf file"
	@echo "* output directory may not be quite right"
	@echo
	@echo "This does not actually run the docker image as it makes more sense to run it directly. Use:"
	@echo "docker run --privileged --rm -it -v $(HOME)/.did:/did.conf $(USERNAME)/did"
	@echo "If you want to add it to your .bashrc use this:"
	@echo "alias did=\"docker run --privileged --rm -it -v $(HOME)/.did:/did.conf $(USERNAME)/did\""
build_docker: examples/dockerfile
	docker build -t $(USERNAME)/did --file="examples/dockerfile" .
