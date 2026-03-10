import subprocess
import argparse
import time
from datetime import datetime

class ble():
    __b = 'bluetoothctl'
    __command_info = 'info'
    __command_devices = 'devices'
    __command_connected = 'Connected'

    def __init__(self):
        pass


    def get_connected_device_mac_list(self) -> list[str]:
        devices_text = subprocess.run([self.__b, self.__command_devices, self.__command_connected], capture_output=True, text=True).stdout
        lines = devices_text.splitlines()
        try:
            devices = [{"name":dev.split(' ')[2], "mac":dev.split(' ')[1]} for dev in lines]
        except Exception as e:
            import traceback
            print(traceback.print_exc())
            devices = None

        return devices


    def get_device_info_text(self, mac_address):
        return subprocess.run([self.__b, self.__command_info, mac_address], capture_output=True, text=True).stdout

    def get_device_info(self):
        devices = self.get_connected_device_mac_list()

        info_dict = {}
        if devices == None:
            return None

        for device_dic in devices:
            mac_addr = device_dic.get("mac")
            device_name = device_dic.get("name")
            info = b.get_device_info_text(mac_addr)
            info_dict[mac_addr] = {}
            split_info = info.splitlines()
            split_info = [info.replace("\t", "") for info in split_info]
            for info in split_info:
                if 'Name:' in info:
                    info_dict[mac_addr]['name'] = device_name
                elif 'Battery Percentage:' in info:
                    info_dict[mac_addr]['battery'] = int(info.replace('Battery Percentage: ', '').split(" ")[0], 16)

        return info_dict

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='connected ble battery infomation script')
    parser.add_argument('-d', '--delay', type=int, default=None)
    parser.add_argument('-l', '--length', help='device name length', type=int, default=5)

    args = parser.parse_args()

    b = ble()
    info_dict = b.get_device_info()
    if info_dict == None:
        exit()

    now = datetime.now()
    items = list(info_dict.items())
    if args.delay is None:
        no = now.second % len(items)
        device_info = items[no][1]

        print(f'{device_info.get("name")[:args.length]}|🔋{device_info.get("battery")}%')

    else:
        for k, v in info_dict.items():
            print(f'{v["name"][:args.length]} | 🔋 {v["battery"]}%')
            time.sleep(args.delay)


