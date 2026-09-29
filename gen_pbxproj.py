#!/usr/bin/env python3
"""
Generate a minimal iOS app Xcode project (project.pbxproj) for StumbleLite.

Run: python3 gen_pbxproj.py
Produces: ./StumbleLite.xcodeproj/

Targets iOS 16.0. Bundle id com.example.StumbleLite.
"""

import hashlib
import os
from pathlib import Path

PROJECT_NAME = "StumbleLite"
SOURCE_DIR_NAME = "StumbleLite"
BUNDLE_ID = "com.example.StumbleLite"
DEPLOYMENT_TARGET = "16.0"

SWIFT_FILES = [
    "AppDelegate.swift",
    "SceneDelegate.swift",
    "GameViewController.swift",
    "JoystickView.swift",
    "Player3D.swift",
    "Obstacle3D.swift",
    "WinViewController.swift",
    "Physics.swift",
]
RESOURCE_FILES = [
    "Assets.xcassets",
]


def uid(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest().upper()[:24]


def main():
    root = Path(__file__).parent
    source_dir = root / SOURCE_DIR_NAME
    if not source_dir.is_dir():
        raise SystemExit(f"Source directory not found: {source_dir}")

    # Stable UIDs
    file_refs = {f: uid("file:" + f) for f in SWIFT_FILES + RESOURCE_FILES}
    info_plist_ref = uid("file:Info.plist")
    build_files = {f: uid("build:" + f) for f in SWIFT_FILES + RESOURCE_FILES}

    src_phase = uid("phase:sources")
    res_phase = uid("phase:resources")
    fmw_phase = uid("phase:frameworks")
    main_group = uid("group:main")
    products_group = uid("group:products")
    source_group = uid("group:source")
    target = uid("target")
    project = uid("project")

    config_list_proj = uid("configlist:project")
    config_list_target = uid("configlist:target")
    proj_cfg_debug = uid("projconfig:debug")
    proj_cfg_release = uid("projconfig:release")
    target_cfg_debug = uid("targetconfig:debug")
    target_cfg_release = uid("targetconfig:release")
    product_ref = uid("product")

    # ---------- Build sections ----------

    # PBXBuildFile
    out = []
    out.append("/* Begin PBXBuildFile section */")
    for f in SWIFT_FILES:
        out.append(
            f"\t\t{build_files[f]} /* {f} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {f} */; }};"
        )
    for f in RESOURCE_FILES:
        out.append(
            f"\t\t{build_files[f]} /* {f} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {f} */; }};"
        )
    out.append("/* End PBXBuildFile section */")

    # PBXFileReference
    out.append("/* Begin PBXFileReference section */")
    for f in SWIFT_FILES:
        out.append(
            f"\t\t{file_refs[f]} /* {f} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"path = {f}; sourceTree = \"<group>\"; }};"
        )
    for f in RESOURCE_FILES:
        ft = "folder.assetcatalog" if f.endswith(".xcassets") else "text"
        out.append(
            f"\t\t{file_refs[f]} /* {f} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = {ft}; "
            f"path = {f}; sourceTree = \"<group>\"; }};"
        )
    out.append(
        f"\t\t{info_plist_ref} /* Info.plist */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        f"path = Info.plist; sourceTree = \"<group>\"; }};"
    )
    out.append(
        f"\t\t{product_ref} /* {PROJECT_NAME}.app */ = "
        f"{{isa = PBXFileReference; explicitFileType = wrapper.application; "
        f"includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    out.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    out.append(f"\t\t{fmw_phase} /* Frameworks */ = {{")
    out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    out.append("/* Begin PBXGroup section */")
    out.append(f"\t\t{main_group} = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{source_group} /* {SOURCE_DIR_NAME} */,")
    out.append(f"\t\t\t\t{products_group} /* Products */,")
    out.append("\t\t\t);")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    out.append(f"\t\t{source_group} /* {SOURCE_DIR_NAME} */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    for f in SWIFT_FILES + RESOURCE_FILES:
        out.append(f"\t\t\t\t{file_refs[f]} /* {f} */,")
    out.append(f"\t\t\t\t{info_plist_ref} /* Info.plist */,")
    out.append("\t\t\t);")
    out.append(f"\t\t\tpath = {SOURCE_DIR_NAME};")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    out.append(f"\t\t{products_group} /* Products */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{product_ref} /* {PROJECT_NAME}.app */,")
    out.append("\t\t\t);")
    out.append("\t\t\tname = Products;")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    out.append("/* End PBXGroup section */")

    # PBXNativeTarget
    out.append("/* Begin PBXNativeTarget section */")
    out.append(f"\t\t{target} /* {PROJECT_NAME} */ = {{")
    out.append("\t\t\tisa = PBXNativeTarget;")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_target} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;")
    out.append("\t\t\tbuildPhases = (")
    out.append(f"\t\t\t\t{src_phase} /* Sources */,")
    out.append(f"\t\t\t\t{fmw_phase} /* Frameworks */,")
    out.append(f"\t\t\t\t{res_phase} /* Resources */,")
    out.append("\t\t\t);")
    out.append("\t\t\tbuildRules = (")
    out.append("\t\t\t);")
    out.append("\t\t\tdependencies = (")
    out.append("\t\t\t);")
    out.append(f"\t\t\tname = {PROJECT_NAME};")
    out.append(f"\t\t\tproductName = {PROJECT_NAME};")
    out.append(f"\t\t\tproductReference = {product_ref} /* {PROJECT_NAME}.app */;")
    out.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    out.append("\t\t};")
    out.append("/* End PBXNativeTarget section */")

    # PBXProject
    out.append("/* Begin PBXProject section */")
    out.append(f"\t\t{project} /* Project object */ = {{")
    out.append("\t\t\tisa = PBXProject;")
    out.append("\t\t\tattributes = {")
    out.append("\t\t\t\tBuildIndependentTargetsInParallel = YES;")
    out.append("\t\t\t\tLastSwiftUpdateCheck = 2640;")
    out.append("\t\t\t\tLastUpgradeCheck = 2640;")
    out.append("\t\t\t\tTargetAttributes = {")
    out.append(f"\t\t\t\t\t{target} = {{")
    out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;")
    out.append("\t\t\t\t\t};")
    out.append("\t\t\t\t};")
    out.append("\t\t\t};")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
    out.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    out.append("\t\t\tdevelopmentRegion = en;")
    out.append("\t\t\thasScannedForEncodings = 0;")
    out.append("\t\t\tknownRegions = (")
    out.append("\t\t\t\ten,")
    out.append("\t\t\t\tBase,")
    out.append("\t\t\t);")
    out.append(f"\t\t\tmainGroup = {main_group};")
    out.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    out.append("\t\t\tprojectDirPath = \"\";")
    out.append("\t\t\tprojectRoot = \"\";")
    out.append("\t\t\ttargets = (")
    out.append(f"\t\t\t\t{target} /* {PROJECT_NAME} */,")
    out.append("\t\t\t);")
    out.append("\t\t};")
    out.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    out.append("/* Begin PBXResourcesBuildPhase section */")
    out.append(f"\t\t{res_phase} /* Resources */ = {{")
    out.append("\t\t\tisa = PBXResourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for f in RESOURCE_FILES:
        out.append(f"\t\t\t\t{build_files[f]} /* {f} in Resources */,")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    out.append("/* Begin PBXSourcesBuildPhase section */")
    out.append(f"\t\t{src_phase} /* Sources */ = {{")
    out.append("\t\t\tisa = PBXSourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for f in SWIFT_FILES:
        out.append(f"\t\t\t\t{build_files[f]} /* {f} in Sources */,")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXSourcesBuildPhase section */")

    # Project-level XCBuildConfiguration (Debug + Release) — compiler flags
    common_proj_debug = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_ENABLE_OBJC_WEAK", "YES"),
        ("CLANG_WARN_BOOL_CONVERSION", "YES"),
        ("CLANG_WARN_CONSTANT_CONVERSION", "YES"),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("CLANG_WARN_EMPTY_BODY", "YES"),
        ("CLANG_WARN_ENUM_CONVERSION", "YES"),
        ("CLANG_WARN_INFINITE_RECURSION", "YES"),
        ("CLANG_WARN_INT_CONVERSION", "YES"),
        ("CLANG_WARN_OBJC_LITERAL_CONVERSION", "YES"),
        ("CLANG_WARN_RANGE_LOOP_ANALYSIS", "YES"),
        ("CLANG_WARN_STRICT_PROTOTYPES", "YES"),
        ("CLANG_WARN_SUSPICIOUS_MOVE", "YES"),
        ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
        ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("ENABLE_TESTABILITY", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_DYNAMIC_NO_PIC", "NO"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("GCC_OPTIMIZATION_LEVEL", "0"),
        ("GCC_PREPROCESSOR_DEFINITIONS", '("DEBUG=1", "$(inherited)", )'),
        ("GCC_WARN_64_TO_32_BIT_CONVERSION", "YES"),
        ("GCC_WARN_ABOUT_RETURN_TYPE", "YES_ERROR"),
        ("GCC_WARN_UNDECLARED_SELECTOR", "YES"),
        ("GCC_WARN_UNINITIALIZED_AUTOS", "YES_AGGRESSIVE"),
        ("GCC_WARN_UNUSED_FUNCTION", "YES"),
        ("GCC_WARN_UNUSED_VARIABLE", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
        ("MTL_FAST_MATH", "YES"),
        ("ONLY_ACTIVE_ARCH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", '"DEBUG $(inherited)"'),
        ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
    ]

    common_proj_release = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_ENABLE_OBJC_WEAK", "YES"),
        ("CLANG_WARN_BOOL_CONVERSION", "YES"),
        ("CLANG_WARN_CONSTANT_CONVERSION", "YES"),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("CLANG_WARN_EMPTY_BODY", "YES"),
        ("CLANG_WARN_ENUM_CONVERSION", "YES"),
        ("CLANG_WARN_INFINITE_RECURSION", "YES"),
        ("CLANG_WARN_INT_CONVERSION", "YES"),
        ("CLANG_WARN_OBJC_LITERAL_CONVERSION", "YES"),
        ("CLANG_WARN_RANGE_LOOP_ANALYSIS", "YES"),
        ("CLANG_WARN_STRICT_PROTOTYPES", "YES"),
        ("CLANG_WARN_SUSPICIOUS_MOVE", "YES"),
        ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
        ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
        ("ENABLE_NS_ASSERTIONS", "NO"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("GCC_WARN_64_TO_32_BIT_CONVERSION", "YES"),
        ("GCC_WARN_ABOUT_RETURN_TYPE", "YES_ERROR"),
        ("GCC_WARN_UNDECLARED_SELECTOR", "YES"),
        ("GCC_WARN_UNINITIALIZED_AUTOS", "YES_AGGRESSIVE"),
        ("GCC_WARN_UNUSED_FUNCTION", "YES"),
        ("GCC_WARN_UNUSED_VARIABLE", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("MTL_ENABLE_DEBUG_INFO", "NO"),
        ("MTL_FAST_MATH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_COMPILATION_MODE", "wholemodule"),
        ("VALIDATE_PRODUCT", "YES"),
    ]

    common_target = [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CODE_SIGN_IDENTITY", '"-"'),  # "-" means ad-hoc (works in simulator)
        ("CURRENT_PROJECT_VERSION", "1"),
        ("DEVELOPMENT_TEAM", '""'),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", f"{SOURCE_DIR_NAME}/Info.plist"),
        ("INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "YES"),
        ("INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents", "YES"),
        ("INFOPLIST_KEY_UILaunchScreen_Generation", "YES"),
        ("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad", '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
        ("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone", '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("LD_RUNPATH_SEARCH_PATHS", '("$(inherited)", "@executable_path/Frameworks", )'),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("SWIFT_VERSION", "5.0"),
        ("TARGETED_DEVICE_FAMILY", "1"),  # iPhone only
    ]

    out.append("/* Begin XCBuildConfiguration section */")

    def emit_config(uid_val, name, settings):
        out.append(f"\t\t{uid_val} /* {name} */ = {{")
        out.append("\t\t\tisa = XCBuildConfiguration;")
        out.append("\t\t\tbuildSettings = {")
        for k, v in settings:
            out.append(f"\t\t\t\t{k} = {v};")
        out.append("\t\t\t};")
        out.append(f"\t\t\tname = {name};")
        out.append("\t\t};")

    emit_config(proj_cfg_debug, "Debug", common_proj_debug)
    emit_config(proj_cfg_release, "Release", common_proj_release)
    emit_config(target_cfg_debug, "Debug", common_target)
    emit_config(target_cfg_release, "Release", common_target)

    out.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    out.append("/* Begin XCConfigurationList section */")
    out.append(f"\t\t{config_list_proj} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{proj_cfg_debug} /* Debug */,")
    out.append(f"\t\t\t\t{proj_cfg_release} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")
    out.append(f"\t\t{config_list_target} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{target_cfg_debug} /* Debug */,")
    out.append(f"\t\t\t\t{target_cfg_release} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")
    out.append("/* End XCConfigurationList section */")

    body = "\n".join(out)

    content = (
        "// !$*UTF8*$!\n"
        "{\n"
        "\tarchiveVersion = 1;\n"
        "\tclasses = {\n"
        "\t};\n"
        "\tobjectVersion = 56;\n"
        "\tobjects = {\n\n"
        f"{body}\n\n"
        "\t};\n"
        f"\trootObject = {project} /* Project object */;\n"
        "}\n"
    )

    # Write project files
    project_dir = root / f"{PROJECT_NAME}.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    pbxproj = project_dir / "project.pbxproj"
    pbxproj.write_text(content)
    print(f"Generated: {pbxproj}")

    # Workspace
    workspace = project_dir / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace version = "1.0">\n'
        '   <FileRef location = "self:">\n'
        '   </FileRef>\n'
        '</Workspace>\n'
    )

    # Shared scheme (so xcodebuild can find it without xcuserdata)
    xcshareddata = project_dir / "xcshareddata" / "xcschemes"
    xcshareddata.mkdir(parents=True, exist_ok=True)
    scheme_path = xcshareddata / f"{PROJECT_NAME}.xcscheme"
    scheme_path.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Scheme LastUpgradeVersion = "2640" version = "1.7">\n'
        '   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">\n'
        '      <BuildActionEntries>\n'
        '         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" '
        'buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">\n'
        f'            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target}" '
        f'BuildableName = "{PROJECT_NAME}.app" BlueprintName = "{PROJECT_NAME}" '
        f'ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">\n'
        '            </BuildableReference>\n'
        '         </BuildActionEntry>\n'
        '      </BuildActionEntries>\n'
        '   </BuildAction>\n'
        '   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" '
        'selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">\n'
        '      <Testables>\n'
        '      </Testables>\n'
        '   </TestAction>\n'
        '   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" '
        'selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" '
        'useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" '
        'debugServiceExtension = "internal" allowLocationSimulation = "YES">\n'
        '      <BuildableProductRunnable runnableDebuggingMode = "0">\n'
        f'         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target}" '
        f'BuildableName = "{PROJECT_NAME}.app" BlueprintName = "{PROJECT_NAME}" '
        f'ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">\n'
        '         </BuildableReference>\n'
        '      </BuildableProductRunnable>\n'
        '   </LaunchAction>\n'
        '   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" '
        'useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">\n'
        '      <BuildableProductRunnable runnableDebuggingMode = "0">\n'
        f'         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target}" '
        f'BuildableName = "{PROJECT_NAME}.app" BlueprintName = "{PROJECT_NAME}" '
        f'ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">\n'
        '         </BuildableReference>\n'
        '      </BuildableProductRunnable>\n'
        '   </ProfileAction>\n'
        '   <AnalyzeAction buildConfiguration = "Debug">\n'
        '   </AnalyzeAction>\n'
        '   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">\n'
        '   </ArchiveAction>\n'
        '</Scheme>\n'
    )
    print(f"Generated: {scheme_path}")
    print(f"\nNext:\n  xcodebuild -project {PROJECT_NAME}.xcodeproj -scheme {PROJECT_NAME} "
          f"-destination 'generic/platform=iOS Simulator' -configuration Debug build")


if __name__ == "__main__":
    main()
