import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

import "services"

Item {
  id: root

  property ShellScreen screen
  property var pluginApi: null
  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  //readonly property var loNetworkService: LoNetworkService

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId]
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0) {
      var widgets = Settings.data.bar.widgets[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  // readonly property bool isBarVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"
  // readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : widgetMetadata.displayMode

  implicitWidth: pill.width
  implicitHeight: pill.height

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": Settings.data.network.wifiEnabled ? I18n.tr("actions.disable-wifi") : I18n.tr("actions.enable-wifi"),
        "action": "toggle-wifi",
        "icon": Settings.data.network.wifiEnabled ? "wifi-off" : "wifi"
      },
      {
        "label": NetworkService.ethernetConnected ? pluginApi.tr("actions.disable-eth") : pluginApi.tr("actions.enable-eth") ,
        "action": "toggle-eth",
        "icon": NetworkService.ethernetConnected ? "ethernet-off" : "ethernet"   
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                  var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
                    if (popupMenuWindow) {
                      popupMenuWindow.close();
                    }
                    if (action === "toggle-wifi") {
                      NetworkService.setWifiEnabled(!Settings.data.network.wifiEnabled);
                    } else if (action === "toggle-eth") {
                      LoNetworkService.setInternetEnabled();
                    } else if (action === "widget-settings") {
                    BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                  }
                }
  }

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: {
      try {
        if (NetworkService.ethernetConnected) {
          return NetworkService.internetConnectivity ? "ethernet" : "ethernet-off";
        }
        let connected = false;
        let signalStrength = 0;
        for (const net in NetworkService.networks) {
          if (NetworkService.networks[net].connected) {
            connected = true;
            signalStrength = NetworkService.networks[net].signal;
            break;
          }
        }
        return connected ? NetworkService.signalIcon(signalStrength, true) : "wifi-off";
      } catch (error) {
        Logger.e("Wi-Fi", "Error getting icon:", error);
        return "wifi-off";
      }
    }
    text: {
      try {
        if (NetworkService.ethernetConnected) {
          return "";
        }
        for (const net in NetworkService.networks) {
          if (NetworkService.networks[net].connected) {
            return net;
          }
        }
        return "";
      } catch (error) {
        Logger.e("Wi-Fi", "Error getting ssid:", error);
        return "error";
      }
    }
    // autoHide: false
    // forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
    // forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""
    onClicked: {
      root.openPanel();
    }
    onRightClicked: {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
      if (popupMenuWindow) {
        popupMenuWindow.showContextMenu(contextMenu);
        contextMenu.openAtItem(pill, screen);
      }
    }
    tooltipText: {
      try {
        if (NetworkService.ethernetConnected) {
          const d = NetworkService.activeEthernetDetails || ({});
          let base = "";
          if (d.ifname && d.ifname.length > 0)
            base = d.ifname;
          else if (d.connectionName && d.connectionName.length > 0)
            base = d.connectionName;
          else if (NetworkService.activeEthernetIf && NetworkService.activeEthernetIf.length > 0)
            base = NetworkService.activeEthernetIf;
          else
            base = I18n.tr("control-center.wifi.label-ethernet");
          const speed = (d.speed && d.speed.length > 0) ? d.speed : "";
          return speed ? (base + " — " + speed) : base;
        }
        // Wi‑Fi tooltip: SSID — link speed (if available)
        if (pill.text !== "") {
          const w = NetworkService.activeWifiDetails || ({});
          const rate = (w.rateShort && w.rateShort.length > 0) ? w.rateShort : (w.rate || "");
          return rate && rate.length > 0 ? (pill.text + " — " + rate) : pill.text;
        }
      } catch (e) {
        // noop
      }
      return I18n.tr("tooltips.manage-wifi");
    }
  }

  function openPanel() {
    if (pluginApi) {
        var result = pluginApi.openPanel(root.screen, root);
        Logger.i("bNet", "OpenPanel result:", result);
    } else {
        Logger.e("bNet", "PluginAPI is null");
    }
  }

}
