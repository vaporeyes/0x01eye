// ABOUTME: Hosts the Flutter Windows window and desktop color picker channel.
// ABOUTME: Samples the screen pixel under the global cursor for desktop picks.
#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstdio>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::optional<std::string> SampleCursorColor() {
  POINT point;
  if (!GetCursorPos(&point)) {
    return std::nullopt;
  }

  HDC screen = GetDC(nullptr);
  if (screen == nullptr) {
    return std::nullopt;
  }

  COLORREF pixel = GetPixel(screen, point.x, point.y);
  ReleaseDC(nullptr, screen);
  if (pixel == CLR_INVALID) {
    return std::nullopt;
  }

  char hex[8];
  std::snprintf(hex, sizeof(hex), "#%02X%02X%02X", GetRValue(pixel),
                GetGValue(pixel), GetBValue(pixel));
  return std::string(hex);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  desktop_color_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "eye_inspector/desktop_color",
          &flutter::StandardMethodCodec::GetInstance());
  desktop_color_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "sampleCursorColor") {
          auto hex = SampleCursorColor();
          if (hex.has_value()) {
            result->Success(flutter::EncodableValue(hex.value()));
          } else {
            result->Success();
          }
          return;
        }

        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    desktop_color_channel_ = nullptr;
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
