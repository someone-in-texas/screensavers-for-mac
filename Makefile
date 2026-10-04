.PHONY: build test preview install uninstall package release-check clean
build:
	./Scripts/build.sh
test: build
	./Scripts/test.sh
preview: build
	open build/products/PreviewHost.app
install:
	./Scripts/install.sh
uninstall:
	./Scripts/uninstall.sh
package:
	./Scripts/package.sh
release-check:
	./Scripts/release-check.sh
clean:
	rm -rf build dist

.PHONY: security-check
security-check:
	./Scripts/security-check.sh

.PHONY: ai-helper test-ai-helper
ai-helper:
	./Scripts/build-ai-helper.sh
test-ai-helper:
	./Scripts/test-ai-helper.sh
