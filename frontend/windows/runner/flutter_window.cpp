#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <fstream>
#include <filesystem>
#include <string>
#include <vector>
#include <winspool.h>
#include <windows.h>

static std::wstring Utf8ToWString(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), NULL, 0);
  if (size_needed <= 0) return std::wstring();
  std::wstring wstr(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), &wstr[0], size_needed);
  return wstr;
}

static bool SendBytesToPrinter(const std::wstring& printerName, const std::string& data) {
  HANDLE hPrinter = NULL;
  if (!OpenPrinterW(const_cast<LPWSTR>(printerName.c_str()), &hPrinter, NULL)) {
    return false;
  }

  DOC_INFO_1W docInfo;
  docInfo.pDocName = const_cast<LPWSTR>(L"TTP244 Job");
  docInfo.pOutputFile = NULL;
  docInfo.pDatatype = const_cast<LPWSTR>(L"RAW");

  DWORD dwJob = StartDocPrinterW(hPrinter, 1, reinterpret_cast<LPBYTE>(&docInfo));
  if (dwJob == 0) {
    ClosePrinter(hPrinter);
    return false;
  }

  if (!StartPagePrinter(hPrinter)) {
    EndDocPrinter(hPrinter);
    ClosePrinter(hPrinter);
    return false;
  }

  DWORD dwWritten = 0;
  BOOL bSuccess = WritePrinter(hPrinter, (LPVOID)data.c_str(), (DWORD)data.size(), &dwWritten);

  EndPagePrinter(hPrinter);
  EndDocPrinter(hPrinter);
  ClosePrinter(hPrinter);

  return bSuccess == TRUE && dwWritten == data.size();
}

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Set up a MethodChannel to receive TSPL print commands from Dart.
  // Method: 'printTspl' expects arguments: { 'commands': '<tspl string>' }
  auto messenger = flutter_controller_->engine()->messenger();
  flutter::MethodChannel<flutter::EncodableValue> channel(
      messenger, "ttp244_printer",
      &flutter::StandardMethodCodec::GetInstance());

  channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string method_name = call.method_name();
        if (method_name == "printTspl") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("ARG_ERROR", "Missing arguments");
            return;
          }

          auto it = args->find(flutter::EncodableValue("commands"));
          if (it == args->end()) {
            result->Error("ARG_ERROR", "Missing 'commands' argument");
            return;
          }

          try {
            const std::string commands = std::get<std::string>(it->second);

            // Optional printer name argument
            std::string printerNameStr;
            auto itPrinter = args->find(flutter::EncodableValue("printerName"));
            if (itPrinter != args->end()) {
              try {
                printerNameStr = std::get<std::string>(itPrinter->second);
              } catch (...) { printerNameStr.clear(); }
            }

            bool printed = false;
            std::string usedPrinterName;

            // Attempt raw printing via Windows spooler if available
            try {
              std::wstring printerW;
              if (!printerNameStr.empty()) {
                printerW = Utf8ToWString(printerNameStr);
              } else {
                // Get default printer name
                DWORD size = 0;
                GetDefaultPrinterW(NULL, &size);
                if (size > 0) {
                  std::wstring buf(size, L'\0');
                  if (GetDefaultPrinterW(&buf[0], &size)) {
                    // buf may contain trailing null
                    printerW = std::wstring(buf.c_str());
                  }
                }
              }

              if (!printerW.empty()) {
                printed = SendBytesToPrinter(printerW, commands);
                // Convert printerW back to UTF-8 to return
                int needed = WideCharToMultiByte(CP_UTF8, 0, printerW.c_str(), -1, NULL, 0, NULL, NULL);
                if (needed > 0) {
                  std::string dest(needed - 1, '\0');
                  WideCharToMultiByte(CP_UTF8, 0, printerW.c_str(), -1, &dest[0], needed, NULL, NULL);
                  usedPrinterName = dest;
                }
              }
            } catch (...) {
              printed = false;
            }

            if (printed) {
              flutter::EncodableMap response;
              response[flutter::EncodableValue("printed")] = flutter::EncodableValue(true);
              response[flutter::EncodableValue("printer")] = flutter::EncodableValue(usedPrinterName);
              result->Success(flutter::EncodableValue(response));
              return;
            }

            // Fallback: write to temp file so Dart can inspect commands
            std::filesystem::path temp = std::filesystem::temp_directory_path();
            auto filename = temp / ("ttp244_" + std::to_string(GetTickCount64()) + ".tspl");
            std::ofstream ofs(filename.string(), std::ios::binary);
            ofs << commands;
            ofs.close();

            flutter::EncodableMap response;
            response[flutter::EncodableValue("path")] = flutter::EncodableValue(filename.string());
            response[flutter::EncodableValue("printed")] = flutter::EncodableValue(false);
            result->Success(flutter::EncodableValue(response));
          } catch (const std::exception& ex) {
            result->Error("PRINT_ERROR", ex.what());
          }
          return;
        }

        result->NotImplemented();
      });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
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
