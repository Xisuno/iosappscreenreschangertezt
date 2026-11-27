TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
# Use rootless for Dopamine/palera1n rootless; remove the line for rootful
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ResoTweak
ResoTweak_FILES = Tweak.x
ResoTweak_FRAMEWORKS = UIKit QuartzCore Metal
ResoTweak_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
