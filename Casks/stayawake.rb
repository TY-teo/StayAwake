cask "stayawake" do
  version "1.0.0"
  sha256 "3783cb8e5193d4b7daf6e9ea2bb90c42c403e2ec4969ffd749716770e08dbd6a"

  url "https://github.com/TY-teo/StayAwake/releases/download/v#{version}/StayAwake-#{version}.dmg"
  name "StayAwake"
  desc "Menu bar app that prevents sleep, even with the lid closed"
  homepage "https://github.com/TY-teo/StayAwake"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "StayAwake.app"

  uninstall quit: "com.chenran.stayawake"

  zap trash: "~/Library/Preferences/com.chenran.stayawake.plist"

  caveats <<~EOS
    StayAwake is ad-hoc signed and not notarized. If macOS blocks the first
    launch, allow it in System Settings > Privacy & Security > Open Anyway.

    Before upgrading or uninstalling, turn off "合盖继续运行" and quit StayAwake
    from its menu. Before uninstalling, also disable "切换时免输密码" and "开机自启"
    in the app to remove the optional sudoers rule and login item.
  EOS
end
