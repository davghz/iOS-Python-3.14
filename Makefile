THEOS ?= /Users/davgz/theos

include $(THEOS)/makefiles/common.mk

before-stage::
	@if [ -d overlay ]; then rsync -a overlay/ layout/; fi

include $(THEOS_MAKE_PATH)/aggregate.mk
