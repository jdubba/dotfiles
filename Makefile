.PHONY: install setup test test-dotfiles test-install lint clean uninstall legacy-install all help

# Default target
all: lint test

# Install dotfiles utility
install:
	# Create necessary directories
	mkdir -p $(HOME)/.local/bin
	mkdir -p $(HOME)/.local/share/dotfiles/lib
	mkdir -p $(HOME)/.local/share/dotfiles/commands
	mkdir -p $(HOME)/.config/dotfiles
	
	# Copy main executable and make it executable
	cp bin/dotfiles $(HOME)/.local/bin/
	chmod +x $(HOME)/.local/bin/dotfiles
	
	# Copy library files
	cp -r src/lib/* $(HOME)/.local/share/dotfiles/lib/
	cp -r src/commands/* $(HOME)/.local/share/dotfiles/commands/
	chmod +x $(HOME)/.local/share/dotfiles/lib/*.sh
	chmod +x $(HOME)/.local/share/dotfiles/commands/*.sh
	
	# Create default config file if it doesn't exist
	@if [ ! -f $(HOME)/.config/dotfiles/config.toml ]; then \
		echo "# Dotfiles configuration" > $(HOME)/.config/dotfiles/config.toml; \
		echo "" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "# Path to the dotfiles repository" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "repository_path = \"$(shell pwd)\"" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "# Default stow directory within the repository" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "stow_directory = \"config\"" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "# Target directory (defaults to \$$HOME)" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "# target_directory = \"$(HOME)\"" >> $(HOME)/.config/dotfiles/config.toml; \
		echo "Config file created at $(HOME)/.config/dotfiles/config.toml"; \
	fi
	
	@echo "Dotfiles utility installed. Run 'dotfiles help' to get started."

# Run dotfiles install command (setup dotfiles)
setup: install
	$(HOME)/.local/bin/dotfiles install

# Legacy install command (for backward compatibility)
legacy-install:
	./install.sh

# Uninstall the dotfiles utility
uninstall:
	rm -f $(HOME)/.local/bin/dotfiles
	rm -rf $(HOME)/.local/share/dotfiles
	@echo "Dotfiles utility uninstalled. Config file at $(HOME)/.config/dotfiles/config.toml remains."
	@echo "To completely remove, run: rm -rf $(HOME)/.config/dotfiles"

# Run tests
test:
	@echo "Running tests for both the legacy install script and the new dotfiles utility..."
	./test.sh

# Run specific test files
test-dotfiles:
	@echo "Running tests for the dotfiles utility only..."
	./tests/lib/bats-core/bin/bats tests/dotfiles.bats

test-install:
	@echo "Running tests for the legacy install script only..."
	./tests/lib/bats-core/bin/bats tests/install.bats

# Run linting
lint:
	./lint.sh

# Clean up test artifacts and temporary files
clean:
	rm -rf tests/lib/bats-*

# Help message
help:
	@echo "Available targets:"
	@echo "  make install      - Install dotfiles utility"
	@echo "  make setup        - Install utility and run dotfiles install"
	@echo "  make legacy-install - Run old install.sh script directly"
	@echo "  make uninstall    - Remove dotfiles utility"
	@echo "  make test         - Run all tests"
	@echo "  make test-dotfiles - Run tests for the dotfiles utility only"
	@echo "  make test-install - Run tests for the legacy install script only"
	@echo "  make lint         - Run linting"
	@echo "  make clean        - Clean up test artifacts"
	@echo "  make all          - Run lint and test (default)"
	@echo "  make help         - Show this help message"