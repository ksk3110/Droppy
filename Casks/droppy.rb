cask "droppy" do
  version "1.1"
  sha256 "136f4f64a310b1c7c2c80e72dd4fbf8ea3f7f69cf61609dea781cd22c7eb6d15"

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
