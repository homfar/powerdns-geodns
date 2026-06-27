.PHONY: validate check no-secrets line-endings tree

validate: check no-secrets no-brand

check:
	@bash scripts/validate.sh

no-secrets:
	@echo "Checking for common secret patterns..."
	@! grep -RniE "(PRIVATE KEY|MAXMIND_LICENSE_KEY=.+[A-Za-z0-9]{8}|PASSWORD=.+|SECRET=.+|TOKEN=.+)" . \
		--exclude-dir=.git \
		--exclude=README.md \
		--exclude=SECURITY.md \
		--exclude=Makefile \
		--exclude='*.example' \
		--exclude='*.md' || \
		(echo "Potential secret found. Review before publishing." && exit 1)

line-endings:
	@echo "Checking for CRLF line endings..."
	@! grep -RIl $$'\r' . --exclude-dir=.git || \
		(echo "CRLF line endings found. Convert files to LF." && exit 1)

tree:
	@find . -maxdepth 3 -type f | sort

no-brand:
	@echo "Checking for removed project-specific branding..."
	@! grep -RniE "ipm[y]p|ipm[y]p\.com|ipm[y]p\.ir" . --exclude-dir=.git || \
		(echo "Project-specific brand reference found. Keep this repository brand-neutral." && exit 1)
