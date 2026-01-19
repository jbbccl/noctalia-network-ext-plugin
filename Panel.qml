import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets
import "component"
import "services"

Item {
  id: root

  property var pluginApi: null
  
  // readonly property ShellScreen screen: pluginApi?.panelOpenScreen || null
  
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  
  // Preferred dimensions
  property real contentPreferredWidth: Math.round(440 * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round(500 * Style.uiScaleRatio)

  // Network panel specific properties
  property string passwordSsid: ""
  property string expandedSsid: ""
  property bool hasHadNetworks: false

  // Info panel collapsed by default, view mode persisted under Settings.data.ui.wifiDetailsViewMode
  // Ethernet details UI state (mirrors Wi‑Fi info behavior)
  property bool ethernetInfoExpanded: false
  property bool ethernetDetailsGrid: (Settings.data && Settings.data.ui && Settings.data.network.wifiDetailsViewMode !== undefined) ? (Settings.data.network.wifiDetailsViewMode === "grid") : true

  // Unified panel view mode: "wifi" | "ethernet" (persisted)
  property string panelViewMode: "wifi"
  property bool panelViewPersistEnabled: false

  onPanelViewModeChanged: {
    // Persist last view (only after restored the initial value)
    if (panelViewPersistEnabled && Settings.data && Settings.data.ui && Settings.data.ui.networkPanelView !== undefined)
      Settings.data.ui.networkPanelView = panelViewMode;
    // Reset transient states to avoid layout artifacts
    passwordSsid = "";
    expandedSsid = "";
    if (panelViewMode === "wifi") {
      ethernetInfoExpanded = false;
      if (Settings.data.network.wifiEnabled && !NetworkService.scanning && Object.keys(NetworkService.networks).length === 0)
        NetworkService.scan();
    } else {
      if (NetworkService.ethernetConnected) {
        NetworkService.refreshActiveEthernetDetails();
      } else {
        NetworkService.refreshEthernet();
      }
    }
  }

  // Computed network lists
  readonly property var knownNetworks: {
    if (!Settings.data.network.wifiEnabled)
      return [];

    var nets = Object.values(NetworkService.networks);
    var known = nets.filter(n => n.connected || n.existing || n.cached);

    // Sort: connected first, then by signal strength
    known.sort((a, b) => {
                 if (a.connected !== b.connected)
                 return b.connected - a.connected;
                 return b.signal - a.signal;
               });

    return known;
  }

  readonly property var availableNetworks: {
    if (!Settings.data.network.wifiEnabled)
      return [];

    var nets = Object.values(NetworkService.networks);
    var available = nets.filter(n => !n.connected && !n.existing && !n.cached);

    // Sort by signal strength
    available.sort((a, b) => b.signal - a.signal);

    return available;
  }

  onKnownNetworksChanged: {
    if (knownNetworks.length > 0)
      hasHadNetworks = true;
  }

  onAvailableNetworksChanged: {
    if (availableNetworks.length > 0)
      hasHadNetworks = true;
  }

  Connections {
    target: Settings.data.network
    function onWifiEnabledChanged() {
      if (!Settings.data.network.wifiEnabled)
        root.hasHadNetworks = false;
    }
  }

  // Initialize panel when loaded
  Component.onCompleted: {
    hasHadNetworks = false;
    NetworkService.scan();
    // Preload active Wi‑Fi details so Info shows instantly
    NetworkService.refreshActiveWifiDetails();
    // Also fetch Ethernet details if connected
    NetworkService.refreshActiveEthernetDetails();
    // Restore last view if valid, otherwise choose what's available (prefer Wi‑Fi when both exist)
    if (Settings.data && Settings.data.ui && Settings.data.ui.networkPanelView) {
      const last = Settings.data.ui.networkPanelView;
      if (last === "ethernet" && NetworkService.hasEthernet()) {
        panelViewMode = "ethernet";
      } else {
        panelViewMode = "wifi";
      }
    } else {
      if (!Settings.data.network.wifiEnabled && NetworkService.hasEthernet())
        panelViewMode = "ethernet";
      else
        panelViewMode = "wifi";
    }
    panelViewPersistEnabled = true;
  }

  anchors.fill: parent

  // Panel content container
  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    property real contentPreferredHeight: Math.min(root.contentPreferredHeight, mainColumn.implicitHeight + Style.marginL * 2)

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.marginM * 2

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            id: modeIcon
            icon: panelViewMode === "wifi" ? (Settings.data.network.wifiEnabled ? "wifi" : "wifi-off") : (NetworkService.hasEthernet() ? (NetworkService.ethernetConnected ? "ethernet" : "ethernet") : "ethernet-off")
            pointSize: Style.fontSizeXXL
            color: panelViewMode === "wifi" ? (Settings.data.network.wifiEnabled ? Color.mPrimary : Color.mOnSurfaceVariant) : (NetworkService.ethernetConnected ? Color.mPrimary : Color.mOnSurfaceVariant)
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                if (panelViewMode === "wifi") {
                  if (NetworkService.hasEthernet()) {
                    panelViewMode = "ethernet";
                  } else {
                    TooltipService.show(parent, I18n.tr("wifi.panel.no-ethernet-devices"));
                  }
                } else {
                  panelViewMode = "wifi";
                }
              }
              onEntered: TooltipService.show(parent, panelViewMode === "wifi" ? I18n.tr("control-center.wifi.label-ethernet") : I18n.tr("wifi.panel.title"))
              onExited: TooltipService.hide()
            }
          }

          NText {
            text: panelViewMode === "wifi" ? I18n.tr("wifi.panel.title") : I18n.tr("control-center.wifi.label-ethernet")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }
          //wifi开关
          NToggle {
            id: wifiSwitch
            visible: panelViewMode === "wifi"
            checked: Settings.data.network.wifiEnabled
            onToggled: checked => NetworkService.setWifiEnabled(checked)
            baseSize: Style.baseWidgetSize * 0.65
          }

          NIconButton {
            icon: "refresh"
            tooltipText: I18n.tr("common.refresh")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: panelViewMode === "wifi" ? (Settings.data.network.wifiEnabled && !NetworkService.scanning) : true
            onClicked: {
              if (panelViewMode === "wifi")
                NetworkService.scan();
              else
                NetworkService.refreshEthernet();
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
                pluginApi.closePanel(root.screen)
            }
          }
        }
      }

      // Unified scrollable content (Wi‑Fi or Ethernet view)
      ColumnLayout {
        id: wifiSectionContainer
        visible: true
        Layout.fillWidth: true
        spacing: Style.marginM

        // Mode switch (Wi‑Fi / Ethernet)
        NTabBar {
          id: modeTabBar
          visible: NetworkService.hasEthernet()
          margins: Style.marginS
          Layout.fillWidth: true
          border.color: Style.boxBorderColor
          border.width: Style.borderS
          spacing: Style.marginM
          distributeEvenly: true
          currentIndex: root.panelViewMode === "wifi" ? 0 : 1
          onCurrentIndexChanged: {
            root.panelViewMode = (currentIndex === 0) ? "wifi" : "ethernet";
          }

          NTabButton {
            text: I18n.tr("tooltips.manage-wifi")
            tabIndex: 0
            checked: modeTabBar.currentIndex === 0
          }

          NTabButton {
            text: I18n.tr("control-center.wifi.label-ethernet")
            tabIndex: 1
            checked: modeTabBar.currentIndex === 1
          }
        }

        // Error message
        Rectangle {
          visible: panelViewMode === "wifi" && NetworkService.lastError.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: errorRow.implicitHeight + (Style.marginM * 2)
          color: Qt.alpha(Color.mError, 0.1)
          radius: Style.radiusS
          border.width: Style.borderS
          border.color: Color.mError

          RowLayout {
            id: errorRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: "warning"
              pointSize: Style.fontSizeL
              color: Color.mError
            }

            NText {
              text: NetworkService.lastError
              color: Color.mError
              pointSize: Style.fontSizeS
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "close"
              baseSize: Style.baseWidgetSize * 0.6
              onClicked: NetworkService.lastError = ""
            }
          }
        }

        // Unified scrollable content
        NScrollView {
          id: contentScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          clip: true

          ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: Style.marginM

            // Wi‑Fi disabled state
            NBox {
              id: disabledBox
              visible: panelViewMode === "wifi" && !Settings.data.network.wifiEnabled
              Layout.fillWidth: true
              Layout.preferredHeight: disabledColumn.implicitHeight + Style.marginM * 2

              ColumnLayout {
                id: disabledColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginL

                Item {
                  Layout.fillHeight: true
                }

                NIcon {
                  icon: "wifi-off"
                  pointSize: 48
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.disabled")
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.enable-message")
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  horizontalAlignment: Text.AlignHCenter
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Scanning state (show when no networks and we haven't had any yet)
            NBox {
              id: scanningBox
              visible: panelViewMode === "wifi" && Settings.data.network.wifiEnabled && Object.keys(NetworkService.networks).length === 0 && !root.hasHadNetworks
              Layout.fillWidth: true
              Layout.preferredHeight: scanningColumn.implicitHeight + Style.marginM * 2

              ColumnLayout {
                id: scanningColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginL

                Item {
                  Layout.fillHeight: true
                }

                NBusyIndicator {
                  running: true
                  color: Color.mPrimary
                  size: Style.baseWidgetSize
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.searching")
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Empty state when no networks (only show after we've had networks before, meaning a real empty result)
            NBox {
              id: emptyBox
              visible: panelViewMode === "wifi" && Settings.data.network.wifiEnabled && !NetworkService.scanning && Object.keys(NetworkService.networks).length === 0 && root.hasHadNetworks
              Layout.fillWidth: true
              Layout.preferredHeight: emptyColumn.implicitHeight + Style.marginM * 2

              ColumnLayout {
                id: emptyColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginL

                Item {
                  Layout.fillHeight: true
                }

                NIcon {
                  icon: "search"
                  pointSize: 48
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.no-networks")
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NButton {
                  text: I18n.tr("wifi.panel.scan-again")
                  icon: "refresh"
                  Layout.alignment: Qt.AlignHCenter
                  onClicked: NetworkService.scan()
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Networks list container (Wi‑Fi)
            ColumnLayout {
              id: networksList
              visible: panelViewMode === "wifi" && Settings.data.network.wifiEnabled && Object.keys(NetworkService.networks).length > 0
              width: parent.width
              spacing: Style.marginM

              WiFiNetworksList {
                label: I18n.tr("wifi.panel.known-networks")//已知网络
                model: root.knownNetworks
                passwordSsid: root.passwordSsid
                expandedSsid: root.expandedSsid
                onPasswordRequested: ssid => {
                                       root.passwordSsid = ssid;
                                       root.expandedSsid = "";
                                     }
                onPasswordSubmitted: (ssid, password) => {
                                       NetworkService.connect(ssid, password);
                                       root.passwordSsid = "";
                                     }
                onPasswordCancelled: root.passwordSsid = ""
                onForgetRequested: ssid => root.expandedSsid = root.expandedSsid === ssid ? "" : ssid
                onForgetConfirmed: ssid => {
                                     NetworkService.forget(ssid);
                                     root.expandedSsid = "";
                                   }
                onForgetCancelled: root.expandedSsid = ""
              }

              WiFiNetworksList {
                label: I18n.tr("wifi.panel.available-networks")//可用网络
                model: root.availableNetworks
                passwordSsid: root.passwordSsid
                expandedSsid: root.expandedSsid
                onPasswordRequested: ssid => {
                                       root.passwordSsid = ssid;
                                       root.expandedSsid = "";
                                     }
                onPasswordSubmitted: (ssid, password) => {
                                       NetworkService.connect(ssid, password);
                                       root.passwordSsid = "";
                                     }
                onPasswordCancelled: root.passwordSsid = ""
                onForgetRequested: ssid => root.expandedSsid = root.expandedSsid === ssid ? "" : ssid
                onForgetConfirmed: ssid => {
                                     NetworkService.forget(ssid);
                                     root.expandedSsid = "";
                                   }
                onForgetCancelled: root.expandedSsid = ""
              }
            }

            // Ethernet view
            ColumnLayout {
              id: ethernetSection
              visible: panelViewMode === "ethernet"
              width: parent.width
              spacing: Style.marginM

              // Section label
              NText {
                text: I18n.tr("wifi.panel.available-interfaces")//可用接口
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
              }

              // Empty state when no Ethernet devices
              NBox {
                visible: !(NetworkService.ethernetInterfaces && NetworkService.ethernetInterfaces.length > 0)
                Layout.fillWidth: true
                Layout.preferredHeight: emptyEthColumn.implicitHeight + Style.marginM * 2

                ColumnLayout {
                  id: emptyEthColumn
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginL

                  Item {
                    Layout.fillHeight: true
                  }

                  NIcon {
                    icon: "ethernet-off"
                    pointSize: 48
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                  }

                  NText {
                    text: I18n.tr("available-interfaces")//可用接口
                    pointSize: Style.fontSizeL
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                  }

                  Item {
                    Layout.fillHeight: true
                  }
                }

              }

              // Interfaces list TODO
              InterfaceList {
                  id: ethernetInterfacesList
                  model: NetworkService.ethernetInterfaces || []
                  onToggleInterfaceConnect: (ifname, isConnect) => {
                                      LoNetworkService.toggleinterfaceConnect(ifname, isConnect);
                                     }
              }
              //这里加一个信息
            }
          }
        }
      }
    }
  }
}