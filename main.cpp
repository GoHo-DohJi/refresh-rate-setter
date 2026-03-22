#include <windows.h>
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <thread>
#include <atomic>

#pragma comment(lib, "User32.lib")

#pragma comment(linker, "/SUBSYSTEM:CONSOLE")

struct DisplayState {
    std::wstring deviceName;
    DEVMODEW originalMode;
    DEVMODEW newMode;
};

bool GetCurrentMode(const std::wstring& device, DEVMODEW& mode) {
    ZeroMemory(&mode, sizeof(mode));
    mode.dmSize = sizeof(mode);
    return EnumDisplaySettingsW(device.c_str(), ENUM_CURRENT_SETTINGS, &mode);
}

bool ApplyMode(const std::wstring& device, DEVMODEW& mode) {
    LONG res = ChangeDisplaySettingsExW(
        device.c_str(),
        &mode,
        nullptr,
        CDS_UPDATEREGISTRY,
        nullptr
    );
    return res == DISP_CHANGE_SUCCESSFUL;
}

std::map<int, int> ParseDisplayArgs(int argc, wchar_t* argv[], bool& force) {
    std::map<int, int> result;
    force = false;

    for (int i = 1; i < argc; ++i) {
        std::wstring arg = argv[i];

        if (arg == L"--force") {
            force = true;
            continue;
        }

        if (arg.rfind(L"--D", 0) == 0) {
            size_t eq = arg.find(L'=');
            if (eq == std::wstring::npos) continue;

            int displayIndex = std::stoi(arg.substr(3, eq - 3));
            int hz = std::stoi(arg.substr(eq + 1));
            result[displayIndex] = hz;
        }
    }
    return result;
}

bool WaitForEnter(int seconds) {
    std::atomic<bool> pressed(false);

    std::thread inputThread([&]() {
        std::wstring dummy;
        std::getline(std::wcin, dummy);
        pressed = true;
    });

    for (int i = 0; i < seconds * 10; ++i) {
        if (pressed) break;
        Sleep(100);
    }

    if (inputThread.joinable())
        inputThread.detach();

    return pressed;
}

int wmain(int argc, wchar_t* argv[]) {
    bool force = false;
    auto targets = ParseDisplayArgs(argc, argv, force);

    if (targets.empty()) {
        std::wcout << L"No Displays Specified!\n"
                   << L"Usage:\n"
                   << L"refresh-rate-setter.exe --D1=240 [--D2=144] [--force]\n";
        return 1;
    }

    std::vector<DisplayState> states;

    for (const auto& [index, hz] : targets) {
        std::wstring device = L"\\\\.\\DISPLAY" + std::to_wstring(index);

        DisplayState state;
        state.deviceName = device;

        if (!GetCurrentMode(device, state.originalMode)) {
            std::wcout << L"Failed to Read Current Mode for " << device << L"\n";
            continue;
        }

        state.newMode = state.originalMode;
        state.newMode.dmFields = DM_DISPLAYFREQUENCY;
        state.newMode.dmDisplayFrequency = hz;

        if (!ApplyMode(device, state.newMode)) {
            std::wcout << L"Failed to Apply " << hz << L" Hz to " << device << L"\n";
            continue;
        }

        std::wcout << L"Applied " << hz << L" Hz to " << device << L"\n";
        states.push_back(state);
    }

    if (states.empty()) {
        std::wcout << L"No Changes Applied\n";
        return 1;
    }

    if (force) {
        std::wcout << L"Force Flag Set. Changes Kept\n";
        return 0;
    }

    std::wcout << L"\nKeep Changes? Press ENTER within 5 seconds...\n";

    if (WaitForEnter(5)) {
        std::wcout << L"Changes Confirmed\n";
        return 0;
    }

    std::wcout << L"Reverting Changes...\n";

    for (auto& state : states) {
        ApplyMode(state.deviceName, state.originalMode);
    }

    std::wcout << L"All Displays ReStored\n";
    return 0;

}
