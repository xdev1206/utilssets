#!/bin/bash

set -x

adb root
adb remount

adb shell setprop debug.neuron.runtime.DumpVerbose 1
adb shell setprop debug.neuron.runtime.EnableDebugger 1
adb shell setprop debug.neuron.adapter.AdapterSetDebugLevel 31
adb shell setprop debug.neuron.adapter.AdapterShowTargetReport 1

adb shell stop neuralnetworks_hal_service_mtk_neuron
adb shell stop neuralnetworks_hal_service_shim_mtk
sleep 1
adb shell start neuralnetworks_hal_service_mtk_neuron
adb shell start neuralnetworks_hal_service_shim_mtk
