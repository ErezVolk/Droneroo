.PHONY: all test clean lint

all:
	xcodebuild -project Droneroo.xcodeproj -scheme Droneroo -configuration Release -destination 'generic/platform=macOS' -destination 'generic/platform=iOS' -quiet

clean:
	xcodebuild -project Droneroo.xcodeproj -scheme Droneroo -configuration Release -destination 'generic/platform=macOS' -destination 'generic/platform=iOS' -quiet clean

test:
	xcodebuild test -scheme Droneroo

lint:
	swiftlint
