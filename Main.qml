import QtQuick
import Quickshell
import qs.Services.System

Item {
    id: root

    property var pluginApi: null

    // readonly property bool InternetEnabled: pluginApi?.pluginSettings?.InternetEnabled ?? true
    //调用pluginApi.pluginSettings.InternetEnabled
    // property real cpuUsage: SystemStatService.cpuUsage
    // readonly property bool isRunning: cpuUsage >= minimumThreshold

    // readonly property var icons: ["icons/my-active-0-symbolic.svg", "icons/my-active-1-symbolic.svg", "icons/my-active-2-symbolic.svg", "icons/my-active-3-symbolic.svg", "icons/my-active-4-symbolic.svg"]
    // readonly property var idleIcons: ["icons/my-idle-0-symbolic.svg", "icons/my-idle-1-symbolic.svg", "icons/my-idle-2-symbolic.svg", "icons/my-idle-3-symbolic.svg"]
}