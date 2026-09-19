#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

swift build -c release --product MarkdownReader

app_dir="$project_dir/build/墨页.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
iconset_dir="$project_dir/build/AppIcon.iconset"

mkdir -p "$macos_dir" "$resources_dir" "$iconset_dir"
cp ".build/release/MarkdownReader" "$macos_dir/MarkdownReader"
cp "Resources/Info.plist" "$contents_dir/Info.plist"

make_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "Resources/AppIcon.png" --out "$iconset_dir/$filename" >/dev/null
}

make_icon 16 "icon_16x16.png"
make_icon 32 "icon_16x16@2x.png"
make_icon 32 "icon_32x32.png"
make_icon 64 "icon_32x32@2x.png"
make_icon 128 "icon_128x128.png"
make_icon 256 "icon_128x128@2x.png"
make_icon 256 "icon_256x256.png"
make_icon 512 "icon_256x256@2x.png"
make_icon 512 "icon_512x512.png"
make_icon 1024 "icon_512x512@2x.png"

iconutil -c icns "$iconset_dir" -o "$resources_dir/AppIcon.icns"

# SwiftPM gives the executable an ad-hoc linker signature. Once it is placed
# in an application bundle, sign the complete bundle so macOS seals Info.plist
# and the generated icon resources together.
codesign --force --deep --sign - --timestamp=none "$app_dir" >/dev/null

echo "Built $app_dir"
