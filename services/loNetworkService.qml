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

// 修改此文件要重新运行 NOCTALIA_DEBUG=1 qs -c noctalia-shell
// WARM：... Not a function
Singleton {
    id: root
    // 属性代理
    readonly property bool isWifiEnabled: Settings.data.network.wifiEnabled

    // 方法代理 
    function signalIcon(strength, connected) {
        return NetworkService.signalIcon(strength, connected);
    }

    // ===========属性============
    //property bool isNetworkingEnabled: true
    property var _pendingCallback: null

    // ++function=================

    function setInternetEnabled() {
      if (!ProgramCheckerService.nmcliAvailable)
        return;
      //TODO 不应该用NetworkService.ethernetConnected
      //Logger.i("bNet","networkConnectivity",NetworkService.networkConnectivity)
      runCommand(["nmcli", "networking", NetworkService.ethernetConnected ? "off" : "on"], NetworkService.refreshEthernet);
    }

    function toggleinterfaceConnect(ifname , isConnect){
      if (!ProgramCheckerService.nmcliAvailable)
        return;
      runCommand(["nmcli", "device", isConnect ? "connect" : "disconnect" , ifname], NetworkService.refreshEthernet);
    }


    function runCommand(cmdArgs, callback) {
        if (commandRunner.running) {
            console.warn("Command runner busy, ignoring:", cmdArgs);
            return ;
        }
        root._pendingCallback = callback;
        commandRunner.command = cmdArgs;
        commandRunner.running = true;
    }


    // ==PROCESS===================
    Process {
      id: commandRunner

      stdout: StdioCollector {
        onStreamFinished: {
          Logger.i("bNet", "commandRunner executed: " , commandRunner.command);
          if (root._pendingCallback) {
              root._pendingCallback();
              root._pendingCallback = null;
          }
        }
      }

      stderr: StdioCollector {
        onStreamFinished: {
          if (text.trim()) {
            Logger.w("bNet", "Error commandRunner" + text);
          }
        }
      }
    }

    

}

