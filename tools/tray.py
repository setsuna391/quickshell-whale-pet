#!/usr/bin/env python3
"""Optional Linux StatusNotifier tray for the Quickshell pet."""
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
from gi.repository import AyatanaAppIndicator3 as Indicator, Gtk


def main():
    if len(sys.argv) != 3:
        return 2
    config_dir, icon = sys.argv[1:]
    indicator = Indicator.Indicator.new("dsh-pet", icon, Indicator.IndicatorCategory.APPLICATION_STATUS)
    indicator.set_status(Indicator.IndicatorStatus.ACTIVE)
    indicator.set_title("DSH 桌面宠物")
    menu = Gtk.Menu()

    def call(method):
        subprocess.Popen(["qs", "ipc", "-p", config_dir, "call", "dsh-pet", method],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    for label, method in [("显示 / 隐藏", "toggleVisible"), ("切换模型", "nextModel"),
                          ("退出", "quit")]:
        item = Gtk.MenuItem(label=label)
        item.connect("activate", lambda _item, name=method: call(name))
        menu.append(item)
    menu.show_all()
    indicator.set_menu(menu)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
