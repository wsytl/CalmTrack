fastlane documentation
----

> 完整中文指南（本机打包 / 装到 iPhone / TestFlight 升级）见 **docs/fastlane-guide.md**

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

模拟器构建验证（CI 用；无需签名）

### ios archive

```sh
[bundle exec] fastlane ios archive
```

真机 Release archive 并导出 Development 签名 ipa（本机；Automatic signing）

### ios test_build

```sh
[bundle exec] fastlane ios test_build
```

构建并编译测试（CI 用；模拟器，无签名）

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
