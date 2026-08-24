import argparse
import re
import subprocess

def args_parser():
    # 创建一个ArgumentParser对象
    parser = argparse.ArgumentParser(description='获取指定进程的资源信息')

    parser.add_argument('-s', metavar='SN', type=str, nargs='?', required=False, help='设备SN')
    # 添加字符串参数
    parser.add_argument('--name', type=str, required=True, help='进程名')

    # 解析参数
    args_param = parser.parse_args()
    return args_param


def run_adb_shell_command(cmd, sn=None):
    """
    执行ADB命令并返回结果。
    :param cmd: ADB命令字符串
    :return: 命令执行结果的字符串
    """
    if sn:
        assembled_cmd = "adb -s {0} shell \"{1}\"".format(sn, cmd)
        print("assembled cmd: ", assembled_cmd)
    else:
        assembled_cmd = "adb shell \"{0}\"".format(cmd)

    result = subprocess.run(assembled_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"Error executing shell command: {assembled_cmd}")
        print(f"Stderr: {result.stderr}")
        raise ValueError("cmd executing error or return value is empty")
    else:
        return result.stdout


def adb_devices_command(cmd):
    """
    执行ADB命令并返回结果。
    :param cmd: ADB命令字符串
    :return: 命令执行结果的字符串
    """
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"Error executing shell command: {cmd}")
        print(f"Stderr: {result.stderr}")
        raise ValueError("cmd executing error")
    else:
        return result.stdout

def adb_devices():
    # 示例：获取连接的设备列表
    devices_cmd = "adb devices"
    devices_output = adb_devices_command(devices_cmd)
    if devices_output:
        devices_map = {}
        devices = devices_output.splitlines()
        for i in range(1, len(devices)):
            print(devices[i])
            pattern = re.compile("\S+\s+")  # 10ADBR1JPG001ZY	device
            device = pattern.findall(devices[i])
            if len(device) > 0:
                print("sn: ", device[0].strip())
                devices_map[i] = device[0].strip()

        if len(devices_map) > 0:
            return devices_map
        else:
            raise ValueError("device map is empty")


def process_id(process_name, dev_sn):
    cmd = "ps -A -o pid,NAME | grep {0}".format(process_name)
    pid_ret = run_adb_shell_command(cmd, dev_sn)
    if pid_ret:
        pid = pid_ret.strip()
        print("{0}'s pid: {1}".format(process_name, pid))
    return pid


if __name__ == "__main__":
    try:
        args = args_parser()
        if args.s:
            dev_sn = args.s
        else:
            devs_map = adb_devices()
            if len(devs_map) > 1:
                print(devs_map)
                devs_number = input("请选择设备：")
                dev_sn = devs_map[int(devs_number)]
            else:
                dev_sn = devs_map[1]

        pid = process_id(args.name, dev_sn)

    except Exception as e:
        print("Error, ", e)
