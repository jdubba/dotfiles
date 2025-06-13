.PHONY: install test lint clean

# Default target
all: lint test

# Install dotfiles
install:
	./install.sh

# Run tests
test:
	./test.sh

# Run linting
lint:
	./lint.sh

# Clean up test artifacts
clean:
	rm -rf tests/lib/bats-*

# Help message
help:
	@echo "Available targets:"
	@echo "  make install  - Install dotfiles"
	@echo "  make test     - Run tests"
	@echo "  make lint     - Run linting"
	@echo "  make clean    - Clean up test artifacts"
	@echo "  make all      - Run lint and test (default)"
	@echo "  make help     - Show this help message"
