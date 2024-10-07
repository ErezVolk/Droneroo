.PHONY: all clean lint

all:
	xcodebuild -project Droneroo.xcodeproj -scheme Droneroo -configuration Release -destination 'generic/platform=macOS' -destination 'generic/platform=iOS' -quiet

clean:
	xcodebuild -project Droneroo.xcodeproj -scheme Droneroo -configuration Release -destination 'generic/platform=macOS' -destination 'generic/platform=iOS' -quiet clean

lint:
	swiftlint
