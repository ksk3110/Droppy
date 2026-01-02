cask "droppy" do
  version "1.2.5"
  sha256 "6e7982f7b58aad47caf450928d40c4276675937c231b78e65945228acd94c1b1"

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
