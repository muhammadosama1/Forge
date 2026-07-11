INSTALL_DIR ?= /usr/local/bin
BINARY_NAME = forge
BUILD_CONFIGURATION = release

.PHONY: build install uninstall

build:
	swift build -c $(BUILD_CONFIGURATION)

install: build
	install -d "$(INSTALL_DIR)"
	install -m 755 ".build/$(BUILD_CONFIGURATION)/$(BINARY_NAME)" "$(INSTALL_DIR)/$(BINARY_NAME)"
	@echo "Installed $(BINARY_NAME) to $(INSTALL_DIR)/$(BINARY_NAME)"

uninstall:
	rm -f "$(INSTALL_DIR)/$(BINARY_NAME)"
	@echo "Removed $(INSTALL_DIR)/$(BINARY_NAME)"
