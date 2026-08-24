#!/usr/bin/env bash

fastboot oem device-info # depends on oem
fastboot oem xxx_skip_confirm_key # depends on oem
fastboot oem unlock # depends on oem
fastboot flashing unlock

fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot getvar current-slot

fastboot reboot
