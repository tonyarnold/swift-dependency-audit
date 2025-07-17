# SwiftDependencyAudit Makefile
# Inspired by SwiftLint's build system

# Variables
PRODUCT_NAME = swift-dependency-audit
EXECUTABLE_NAME = swift-dependency-audit
VERSION_FILE = VERSION
SWIFT_BUILD_FLAGS = -c release -Xswiftc -Osize
MACOS_BUILD_DIR = .build/apple/Products/Release
LINUX_X86_64_BUILD_DIR = .build/x86_64-unknown-linux-gnu/release
LINUX_AARCH64_BUILD_DIR = .build/aarch64-unknown-linux-gnu/release

# Platform detection
UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
    PLATFORM = macos
else
    PLATFORM = linux
endif

# Version handling
VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "1.0.0")

# Default target
.PHONY: all
all: build

# Clean all build artifacts
.PHONY: clean
clean:
	rm -rf .build
	rm -rf *.artifactbundle.zip
	rm -rf *.checksum
	rm -f Package.swift.bak

# Build for current platform
.PHONY: build
build:
ifeq ($(PLATFORM), macos)
	swift build $(SWIFT_BUILD_FLAGS)
else
	swift build $(SWIFT_BUILD_FLAGS)
endif

# Build universal macOS binary
.PHONY: build_macos
build_macos:
	@echo "Building universal macOS binary..."
	swift build $(SWIFT_BUILD_FLAGS) --arch arm64 --arch x86_64
	strip -rSTx $(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME)
	@echo "✅ macOS universal binary built at $(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME)"

# Build Linux binaries using Docker
.PHONY: build_linux
build_linux: build_linux_x86_64 build_linux_aarch64

.PHONY: build_linux_x86_64
build_linux_x86_64:
	@echo "Building Linux x86_64 binary..."
	mkdir -p $(LINUX_X86_64_BUILD_DIR)
	docker run --rm \
		--platform linux/amd64 \
		-v $(PWD):/workspace \
		-w /workspace \
		-e HOME=/tmp \
		swift:6.1 \
		bash -c " \
			swift build $(SWIFT_BUILD_FLAGS) --triple x86_64-unknown-linux-gnu && \
			strip .build/x86_64-unknown-linux-gnu/release/$(EXECUTABLE_NAME) && \
			chown -R $$(stat -c '%u:%g' /workspace) /workspace/.build/ \
		"
	@echo "✅ Linux x86_64 binary built at $(LINUX_X86_64_BUILD_DIR)/$(EXECUTABLE_NAME)"

.PHONY: build_linux_aarch64
build_linux_aarch64:
	@echo "Building Linux ARM64 binary using cross-compilation..."
	mkdir -p $(LINUX_AARCH64_BUILD_DIR)
	docker run --rm \
		--platform linux/amd64 \
		-v $(PWD):/workspace \
		-w /workspace \
		-e HOME=/tmp \
		swift:6.1 \
		bash -c " \
			echo 'Installing cross-compilation tools...' && \
			apt-get update && apt-get install -y gcc-aarch64-linux-gnu && \
			echo 'Cross-compiling for ARM64...' && \
			swift build $(SWIFT_BUILD_FLAGS) --triple aarch64-unknown-linux-gnu -Xcc -target -Xcc aarch64-unknown-linux-gnu && \
			aarch64-linux-gnu-strip .build/aarch64-unknown-linux-gnu/release/$(EXECUTABLE_NAME) && \
			chown -R $$(stat -c '%u:%g' /workspace) /workspace/.build/ \
		"
	@echo "✅ Linux ARM64 binary built at $(LINUX_AARCH64_BUILD_DIR)/$(EXECUTABLE_NAME)"

# Build all platform binaries
.PHONY: build_all
build_all: build_macos build_linux
	@echo "✅ All platform binaries built successfully"

# Test current platform build
.PHONY: test
test:
	swift test

# Test functionality of built binary
.PHONY: test_binary
test_binary:
ifeq ($(PLATFORM), macos)
	@echo "Testing macOS binary..."
	$(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME) --version
	$(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME) --help
	$(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME) . --verbose --exclude-tests
else
	@echo "Testing local binary..."
	.build/release/$(EXECUTABLE_NAME) --version
	.build/release/$(EXECUTABLE_NAME) --help
	.build/release/$(EXECUTABLE_NAME) . --verbose --exclude-tests
endif

# Create SPM artifact bundle
.PHONY: spm_artifactbundle
spm_artifactbundle: build_all
	@echo "Creating SPM artifact bundle for version $(VERSION)..."
	chmod +x Scripts/spm-artifact-bundle.sh
	./Scripts/spm-artifact-bundle.sh "$(VERSION)"
	@echo "✅ Artifact bundle created: $(PRODUCT_NAME).artifactbundle.zip"

# Update Package.swift with new version and checksum
.PHONY: update_package
update_package:
	@echo "Updating Package.swift with version v$(VERSION)..."
	chmod +x Scripts/update-artifact-bundle.sh
	./Scripts/update-artifact-bundle.sh "v$(VERSION)"
	@echo "✅ Package.swift updated"

# Create portable binary archives
.PHONY: package
package: build_all
	@echo "Creating portable binary packages for version $(VERSION)..."
	mkdir -p release
	
	# macOS universal binary
	mkdir -p "$(PRODUCT_NAME)-$(VERSION)-macos-universal"
	cp $(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME) "$(PRODUCT_NAME)-$(VERSION)-macos-universal/"
	cp LICENSE "$(PRODUCT_NAME)-$(VERSION)-macos-universal/" 2>/dev/null || true
	cp README.md "$(PRODUCT_NAME)-$(VERSION)-macos-universal/" 2>/dev/null || true
	tar -czf "release/$(PRODUCT_NAME)-$(VERSION)-macos-universal.tar.gz" "$(PRODUCT_NAME)-$(VERSION)-macos-universal"
	rm -rf "$(PRODUCT_NAME)-$(VERSION)-macos-universal"
	
	# Linux x86_64 binary
	mkdir -p "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64"
	cp $(LINUX_X86_64_BUILD_DIR)/$(EXECUTABLE_NAME) "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64/"
	cp LICENSE "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64/" 2>/dev/null || true
	cp README.md "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64/" 2>/dev/null || true
	tar -czf "release/$(PRODUCT_NAME)-$(VERSION)-linux-x86_64.tar.gz" "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64"
	rm -rf "$(PRODUCT_NAME)-$(VERSION)-linux-x86_64"
	
	# Linux ARM64 binary
	mkdir -p "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64"
	cp $(LINUX_AARCH64_BUILD_DIR)/$(EXECUTABLE_NAME) "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64/"
	cp LICENSE "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64/" 2>/dev/null || true
	cp README.md "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64/" 2>/dev/null || true
	tar -czf "release/$(PRODUCT_NAME)-$(VERSION)-linux-aarch64.tar.gz" "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64"
	rm -rf "$(PRODUCT_NAME)-$(VERSION)-linux-aarch64"
	
	# Generate checksums
	cd release && shasum -a 256 *.tar.gz > checksums.txt
	@echo "✅ Portable packages created in release/ directory"

# Install binary to system (macOS only)
.PHONY: install
install: build_macos
	@echo "Installing $(EXECUTABLE_NAME) to /usr/local/bin..."
	sudo cp $(MACOS_BUILD_DIR)/$(EXECUTABLE_NAME) /usr/local/bin/
	@echo "✅ $(EXECUTABLE_NAME) installed to /usr/local/bin"

# Uninstall binary from system
.PHONY: uninstall
uninstall:
	@echo "Removing $(EXECUTABLE_NAME) from /usr/local/bin..."
	sudo rm -f /usr/local/bin/$(EXECUTABLE_NAME)
	@echo "✅ $(EXECUTABLE_NAME) removed from /usr/local/bin"

# Development helpers
.PHONY: format
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "Formatting Swift code..."; \
		find Sources Tests -name "*.swift" | xargs swift-format --in-place; \
		echo "✅ Code formatted"; \
	else \
		echo "⚠️  swift-format not available"; \
	fi

.PHONY: lint
lint:
	@echo "Checking for build warnings..."
	swift build $(SWIFT_BUILD_FLAGS) 2>&1 | tee build.log
	@if grep -q "warning:" build.log; then \
		echo "⚠️  Build warnings found:"; \
		grep "warning:" build.log; \
		rm -f build.log; \
		exit 1; \
	else \
		echo "✅ No build warnings"; \
		rm -f build.log; \
	fi

# Release workflow
.PHONY: release
release: clean test lint build_all spm_artifactbundle package
	@echo "✅ Release build complete for version $(VERSION)"
	@echo "Artifacts created:"
	@echo "  - SPM artifact bundle: $(PRODUCT_NAME).artifactbundle.zip"
	@echo "  - Portable packages: release/*.tar.gz"
	@echo "  - Checksums: release/checksums.txt"

# Help
.PHONY: help
help:
	@echo "SwiftDependencyAudit Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build Targets:"
	@echo "  build          Build for current platform"
	@echo "  build_macos    Build universal macOS binary"
	@echo "  build_linux    Build Linux binaries (both architectures)"
	@echo "  build_all      Build all platform binaries"
	@echo ""
	@echo "Test Targets:"
	@echo "  test           Run Swift tests"
	@echo "  test_binary    Test built binary functionality"
	@echo "  lint           Check for build warnings"
	@echo ""
	@echo "Package Targets:"
	@echo "  spm_artifactbundle  Create SPM artifact bundle"
	@echo "  package        Create portable binary packages"
	@echo "  update_package Update Package.swift with new version"
	@echo ""
	@echo "Install Targets:"
	@echo "  install        Install binary to /usr/local/bin (macOS only)"
	@echo "  uninstall      Remove binary from /usr/local/bin"
	@echo ""
	@echo "Utility Targets:"
	@echo "  clean          Remove all build artifacts"
	@echo "  format         Format Swift code (requires swift-format)"
	@echo "  release        Complete release build workflow"
	@echo "  help           Show this help message"
	@echo ""
	@echo "Environment:"
	@echo "  Platform: $(PLATFORM)"
	@echo "  Version:  $(VERSION)"