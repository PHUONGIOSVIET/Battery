ARCHS := arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := BatteryPro
BatteryPro_FILES := main.m BatteryProApplication.mm RootViewController.mm
BatteryPro_FRAMEWORKS := UIKit CoreGraphics
BatteryPro_CODESIGN_FLAGS := -S
BatteryPro_INSTALL_PATH := /Applications

include $(THEOS_MAKE_PATH)/application.mk
