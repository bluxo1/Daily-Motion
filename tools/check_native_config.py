"""Static native privacy/build guards; never hardware/restore evidence."""

import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
mobile = root / "apps/mobile"
namespace = "{http://schemas.android.com/apk/res/android}"
manifest = ET.parse(mobile / "android/app/src/main/AndroidManifest.xml").getroot()
application = manifest.find("application")
assert application is not None
assert application.attrib[namespace + "allowBackup"] == "false"
assert application.attrib[namespace + "fullBackupContent"] == "false"
assert application.attrib[namespace + "enableOnBackInvokedCallback"] == "true"
assert any(
    x.attrib[namespace + "name"] == "android.permission.INTERNET"
    for x in manifest.findall("uses-permission")
)
rules = ET.parse(mobile / "android/app/src/main/res/xml/data_extraction_rules.xml").getroot()
domains = {
    "root",
    "file",
    "database",
    "sharedpref",
    "external",
    "device_root",
    "device_file",
    "device_database",
    "device_sharedpref",
}
for category in ("cloud-backup", "device-transfer"):
    section = rules.find(category)
    assert section is not None
    assert {
        x.attrib["domain"] for x in section.findall("exclude") if x.attrib["path"] == "."
    } == domains
    assert not section.findall("include")
entitlements = plistlib.loads((mobile / "ios/Runner/Runner.entitlements").read_bytes())
assert "keychain-access-groups" in entitlements
assert (mobile / "ios/Runner.xcodeproj/project.pbxproj").read_text().count(
    "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"
) == 3
delegate = (mobile / "ios/Runner/AppDelegate.swift").read_text()
assert "isExcludedFromBackup = true" in delegate
assert "mach_continuous_time()" in delegate
assert "directory.path.hasPrefix(support.path" in delegate
gradle = (mobile / "android/app/build.gradle.kts").read_text()
assert 'signingConfigs.getByName("debug")' not in gradle
print(
    "Static Android backup/back/network and iOS backup/Keychain/clock guards passed; "
    "hardware qualification remains separate"
)
