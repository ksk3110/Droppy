cask "droppy" do
  version "2.1.3"
  sha256 "97d57c47813ec4b36c27a53bdb4db8ad6706ab1296cbb62a20297bcea6342ae5"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.1.3.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
