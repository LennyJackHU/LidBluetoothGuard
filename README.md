# Lid Bluetooth Guard

一个 macOS 原生菜单栏小工具：监听 MacBook 合盖/开盖事件；如果策略已启用且屏幕盖已合上，就关闭蓝牙。界面使用 SwiftUI，合盖状态来自 IOKit，蓝牙电源控制使用 IOBluetooth。

## 运行

```bash
swift run LidBluetoothGuard
```

也可以直接用 Xcode 打开 `Package.swift`，选择 `LidBluetoothGuard` scheme 后点击 Run。仅本地构建和调试不需要 Apple ID。

## 打包成 `.app`

```bash
./Scripts/package-app.sh
```

打包完成后应用位于：

```text
.build/release/LidBluetoothGuard.app
```

## 系统依赖

最低系统版本：

- macOS 13.0，因为菜单栏界面使用 SwiftUI `MenuBarExtra`。

当前验证环境：

- macOS 15.7.3 (24G419)
- macOS SDK 26.2
- Apple Swift 6.2.3
- arm64 Apple Silicon

依赖的系统框架和符号：

```text
IOKit.framework
- IOServiceGetMatchingService
- IOServiceMatching
- IONotificationPortCreate
- IONotificationPortGetRunLoopSource
- IOServiceAddInterestNotification
- IORegistryEntryCreateCFProperty
- IOObjectRelease
- IONotificationPortDestroy
- kIOMainPortDefault
- kIOGeneralInterest

IOPMrootDomain registry property
- AppleClamshellState

IOBluetooth.framework, runtime-loaded with dlopen/dlsym
- IOBluetoothPreferenceGetControllerPowerState
- IOBluetoothPreferenceSetControllerPowerState
```

说明：

- `IOKit.framework` 是链接期依赖。
- `IOBluetooth.framework` 不再作为链接期依赖，而是在运行时从 `/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth` 动态加载。
- 如果未来 macOS 移除 `IOBluetoothPreferenceGetControllerPowerState` 或 `IOBluetoothPreferenceSetControllerPowerState`，App 应该不会因为缺少符号而启动崩溃，但蓝牙开关功能会失效。
- 这两个 IOBluetooth 符号不是适合 Mac App Store 分发的公开稳定 API。

## License

MIT License. See [LICENSE](LICENSE).

## 注意

- 这个工具需要保持运行，才能接收合盖/开盖事件。
- WidgetKit 小组件不能在后台监听合盖事件，也不能直接修改蓝牙电源，所以这里实现为菜单栏小组件。
- 关闭蓝牙使用运行时加载的 `IOBluetoothPreferenceSetControllerPowerState`，适合本机自用，不适合提交 Mac App Store。
- 当前策略使用 IOKit 事件通知，不使用定时器轮询。合盖事件会在系统睡眠前发出，但 macOS 仍可能因硬件、系统版本或睡眠时序影响实际执行结果。
- “开盖后恢复蓝牙”只会恢复本 App 在上一次合盖时关闭过的蓝牙；如果用户在合盖前本来就关闭了蓝牙，开盖时不会强行打开。
- App 不联网、不执行 shell、不读写用户文件；菜单只保留策略开关、开盖恢复选项和退出项。
- 正式分发时请使用 Developer ID 签名、公证和 hardened runtime。它能降低被篡改或被 Gatekeeper 拦截的风险，但不能阻止已经获得用户权限的恶意软件退出或替换这个 App。
