cask "droppy" do
  version "1.2"
  sha256 "6b99d7f5ee6c9aaa7b6d5f86f6e3d86813f3ce9f66b03fb52a180f9d893a1c97"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
