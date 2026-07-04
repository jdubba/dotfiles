.PHONY: all help link status doctor install install-hooks uninstall test lint clean

# Where a convenience symlink to the tool is placed.
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
REPO   := $(shell pwd)

# Default: lint + test
all: lint test

help:
	@echo "dotfiles - layered symlink manager"
	@echo ""
	@echo "Targets:"
	@echo "  make install        Symlink bin/dotfiles into $(BINDIR) and install git hook"
	@echo "  make install-hooks  Install the git post-merge hook (auto-link on pull)"
	@echo "  make link           Run 'dotfiles link' for this machine"
	@echo "  make status         Show what 'dotfiles link' would do (read-only)"
	@echo "  make doctor         Detect/repair hazards and broken links"
	@echo "  make uninstall      Remove the $(BINDIR)/dotfiles symlink"
	@echo "  make test           Run the BATS test suite"
	@echo "  make lint           Run shellcheck"
	@echo "  make clean          Remove test artifacts"
	@echo ""
	@echo "Typical first run:"
	@echo "  make install && dotfiles status && dotfiles link"

# Put the tool on PATH (a symlink, so it tracks the repo) and install the hook.
install: install-hooks
	@mkdir -p "$(BINDIR)"
	ln -sf "$(REPO)/bin/dotfiles" "$(BINDIR)/dotfiles"
	@echo "Linked $(BINDIR)/dotfiles -> $(REPO)/bin/dotfiles"
	@echo "Ensure $(BINDIR) is on your PATH, then run: dotfiles status"

install-hooks:
	"$(REPO)/bin/dotfiles" hook install

link:
	"$(REPO)/bin/dotfiles" link

status:
	"$(REPO)/bin/dotfiles" status

doctor:
	"$(REPO)/bin/dotfiles" doctor

uninstall:
	rm -f "$(BINDIR)/dotfiles"
	@echo "Removed $(BINDIR)/dotfiles (managed symlinks in \$$HOME are left in place)."
	@echo "To remove a hook: dotfiles hook uninstall"

test:
	./test.sh

lint:
	./lint.sh

clean:
	rm -rf tests/lib/bats-*
