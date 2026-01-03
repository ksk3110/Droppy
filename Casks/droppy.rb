cask "droppy" do
  version "2.1"
  sha256 "c9bdd07cd01850e9ef5c5764fa77a5997f0310a8d98b3861cf6db21147a725e0"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.1.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
