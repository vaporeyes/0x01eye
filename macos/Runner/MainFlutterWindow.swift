// ABOUTME: Hosts the Flutter macOS window and desktop color picker channel.
// ABOUTME: Uses the native macOS sampler to pick any visible screen color.
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "eye_inspector/desktop_color",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "pickColor" {
        NSColorSampler().show { color in
          guard let color = color?.usingColorSpace(.sRGB) else {
            result(nil)
            return
          }

          let red = Int(round(color.redComponent * 255))
          let green = Int(round(color.greenComponent * 255))
          let blue = Int(round(color.blueComponent * 255))
          result(String(format: "#%02X%02X%02X", red, green, blue))
        }
      } else if call.method == "sampleCursorColor" {
        result(Self.sampleCursorColor())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private static func sampleCursorColor() -> String? {
    let location = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }),
      let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
        as? NSNumber
    else {
      return nil
    }

    let displayID = CGDirectDisplayID(screenNumber.uint32Value)
    let sampleRect = CGRect(
      x: location.x - screen.frame.minX,
      y: screen.frame.maxY - location.y,
      width: 1,
      height: 1)
    guard let image = CGDisplayCreateImage(displayID, rect: sampleRect) else {
      return nil
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let color = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else {
      return nil
    }

    let red = Int(round(color.redComponent * 255))
    let green = Int(round(color.greenComponent * 255))
    let blue = Int(round(color.blueComponent * 255))
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}
