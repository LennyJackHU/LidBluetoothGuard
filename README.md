# Lid Bluetooth Guard

一个 macOS 原生菜单栏小工具：每 10 秒检测一次 MacBook 合盖状态；如果策略已启用且屏幕盖已合上，就关闭蓝牙。界面使用 SwiftUI，合盖状态来自 IOKit，蓝牙电源控制使用 IOBluetooth。

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

## License

MIT License. See [LICENSE](LICENSE).

