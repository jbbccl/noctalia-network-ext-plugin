pragma Singleton
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Singleton {
    id: root
    // 属性代理
    readonly property bool isWifiEnabled: Settings.data.network.wifiEnabled

    // 方法代理 
    function signalIcon(strength, connected) {
        return NetworkService.signalIcon(strength, connected);
    }

    // 添加
    function setInternetEnabled() {
        Logger.i(NetworkService.ethernetConnected);
        if (!ProgramCheckerService.nmcliAvailable)
            return;
        internetStateEnableProcess.running = true;

    }
    
    Process {
    id: internetStateEnableProcess
    running: false
    command: ["nmcli", "networking", NetworkService.ethernetConnected ? "off" : "on"]

    stdout: StdioCollector {
      onStreamFinished: {
        Logger.i("Network", "Internet state change command executed", NetworkService.ethernetConnected ? "off" : "on");
        // Re-check the state to ensure it's in sync
        // TODO
        NetworkService.refreshEthernet();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Network", "Error changing Internet state: " + text);
        }
      }
    }
  }
}

