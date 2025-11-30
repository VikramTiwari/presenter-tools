SWIFTC = swiftc

PRESENTER_SOURCES = Presenter/main.swift \
					Presenter/AppDelegate.swift \
					Presenter/CursorHighlighter.swift \
					Presenter/KeystrokeVisualizer.swift \
					Presenter/MagnifyingGlass.swift \
					Presenter/WebcamController.swift \
					Shared/Utils.swift

RECORDER_SOURCES = Recorder/main.swift \
				   Recorder/AppDelegate.swift \
				   Recorder/RecorderManager.swift \
				   Recorder/ScreenRecorder.swift \
				   Recorder/WebcamRecorder.swift \
				   Recorder/AudioRecorder.swift \
				   Recorder/InputRecorder.swift \
				   Shared/Utils.swift

all: build-presenter build-recorder

build-presenter:
	$(SWIFTC) $(PRESENTER_SOURCES) -o PresenterApp

build-recorder:
	$(SWIFTC) $(RECORDER_SOURCES) -o RecorderApp

clean:
	rm -f PresenterApp RecorderApp
