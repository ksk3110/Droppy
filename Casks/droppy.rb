cask "droppy" do
  version "2.0"
  sha256 "8c7ec3d356e2c1b004dd309d28c1b7be518ca88117c7e8ce5329ae80468cb4de"

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
