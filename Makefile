keystore_path = $(wildcard ~)/keystores/kolibri
apk_path = bin

build_tools_path = $(wildcard ~/.buildozer/android/platform/android-sdk-21/build-tools/22.0.1)

# Specify where to look for keystores, apk
vpath %.keystore $(keystore_path)
vpath %.apk $(apk_path)


# ENVIRONMENT SETUP TOOLS


## Clear out apks
.PHONY: clean
clean:
	mkdir -p $(apk_path)
	rm -f $(apk_path)/*.apk 2> /dev/null
	rm -rf ./src/kolibri 2> /dev/null

## Update build system (download NDK/SDK, build Python, etc)
.PHONY: updatedependencies
updatedependencies:
	buildozer android update

## Replace the default loading page, so that it will be replaced with our own version
.PHONY: replaceloadingpage
replaceloadingpage:
	rm -f .buildozer/android/platform/build/dists/kolibri/webview_includes/_load.html
	cp ./assets/_load.html .buildozer/android/platform/build/dists/kolibri/webview_includes/
	cp ./assets/loading-spinner.gif .buildozer/android/platform/build/dists/kolibri/webview_includes/

## Extract the whl file
.PHONY: extractkolibriwhl
extractkolibriwhl:
	unzip -q "src/kolibri*.whl" "kolibri/*" -x "kolibri/dist/cext*" -d src/

## Generate the andoid version
.PHONY: generateversion
generateversion:
	python ./scripts/generateversion.py


# APK SIGNING


## Creates a keystore in user's home directory
debug.keystore:
	mkdir -p $(keystore_path)
	keytool -genkey -v -keystore $(keystore_path)/$@ -alias debug -keyalg RSA -keysize 2048 -validity 10000

## Checks for keystore in user's home directory. Always use LE's official key.
release.keystore: # NOTE assumes file name. May need to change this.

## Creates debug apk if none is found
%-debug.apk: debugapk ;

## Recipe for a signed debug apk.
## Note: release not necessary, built into buildozer(?), which achieves same the env vars
.PHONY: signeddebugapk
signeddebugapk: %-debug.apk | debug.keystore $(build_tools_path)
	### Will prompt for debug password
	jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore $(word 2, $^) $< debug
	### Replacing unsigned APK with signed APK
	$(build_tools_path)/zipalign -v 4 $< $<


# APK BUILDING


## Target specifying everything that needs to happen before a debug build
.PHONY: debug_build_reqs
debug_build_reqs: clean updatedependencies replaceloadingpage extractkolibriwhl generateversion

## Build the debug version of the apk
.PHONY: debugapk
debugapk: debug_build_reqs
	buildozer android debug

## Build the release version of the apk
.PHONY: releaseapk
releaseapk: release.keystore debug_build_reqs
	### Appropriate environment variables need to be set for this to work
	buildozer android release


# APK DEVICE DEPLOYMENT


# Deploys the apk on a device
.PHONY: installapk
installapk:
	buildozer android deploy

# Run apk on device
.PHONY: runapk
runapk:
	buildozer android run
	buildozer android adb -- logcat | grep -i python

.PHONY: uninstallapk
uninstallapk:
	adb uninstall org.le.kolibri


# DOCKER BUILDING


# Build the docker image
.PHONY: builddocker
builddocker:
	docker build -t kolibrikivy .

# Run the docker image
.PHONY: rundocker
rundocker: clean builddocker
	./scripts/rundocker.sh
