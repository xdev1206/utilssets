#!/system/bin/sh

silent_log=(SecurityManage.Service:S ConfigFileProvider:S middleware_Core:S PayVIPManager:S BILogManager:S
            WtvApi_HardwareInfoManager:S PersistentConnect.Service:S)

logcat -ball -c;logcat -vthreadtime ${silent_log[@]}
