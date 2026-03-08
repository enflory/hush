.PHONY: app install clean icon

app:
	./scripts/build-app.sh

install: app
	cp -R build/Hush.app /Applications/
	@echo "Installed to /Applications/Hush.app"

clean:
	rm -rf build

icon:
	swift scripts/generate-icon.swift
