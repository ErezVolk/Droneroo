.PHONY: all

all:
	xcodebuild -project Droneroo.xcodeproj -scheme Droneroo -configuration Release -destination 'generic/platform=macOS' -destination 'generic/platform=iOS' -quiet
