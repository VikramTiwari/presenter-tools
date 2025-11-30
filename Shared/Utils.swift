import Foundation
import AppKit

class Utils {
    static func setDesktopIconsVisible(_ visible: Bool) {
        let process = Process()
        process.launchPath = "/usr/bin/defaults"
        process.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", visible ? "true" : "false"]
        process.launch()
        process.waitUntilExit()
        
        let killProcess = Process()
        killProcess.launchPath = "/usr/bin/killall"
        killProcess.arguments = ["Finder"]
        killProcess.launch()
        killProcess.waitUntilExit()
    }
}
