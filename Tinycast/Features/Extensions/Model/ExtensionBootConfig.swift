import Foundation

/// Machine facts the Node shims answer from without a host call. Sent once, when the engine boots.
struct ExtensionBootConfig: Sendable {
    var arch: String
    var release: String
    var hostname: String
    var username: String
    var shell: String
    var homeDirectory: String
    var temporaryDirectory: String
    var workingDirectory: String
    var totalMemory: Double
    var userID: uid_t
    var groupID: gid_t
    var effectiveUserID: uid_t
    var effectiveGroupID: gid_t
    var groupIDs: [gid_t]
    var environmentVariables: [String: String]
    var additionalSearchPaths: [String]

    static func current(supportDirectory: URL, additionalSearchPaths: [String] = []) -> ExtensionBootConfig {
        let info = ProcessInfo.processInfo
        var arch = "arm64"
        #if arch(x86_64)
            arch = "x64"
        #endif
        // A GUI app inherits a bare environment; extensions shelling out expect a login-ish PATH.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var variables = info.environment
        variables["PATH"] =
            (additionalSearchPaths + (variables["PATH"].map { [$0] } ?? []) + ExtensionPackageManager.searchPaths)
            .joined(separator: ":")
        variables["HOME"] = home

        var groups = [gid_t](repeating: 0, count: Int(getgroups(0, nil)))
        let groupCount = getgroups(Int32(groups.count), &groups)
        groups = Array(groups.prefix(Int(max(groupCount, 0))))

        return ExtensionBootConfig(
            arch: arch,
            release: info.operatingSystemVersionString,
            hostname: info.hostName,
            username: NSUserName(),
            shell: info.environment["SHELL"] ?? "/bin/zsh",
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            temporaryDirectory: FileManager.default.temporaryDirectory.path,
            workingDirectory: supportDirectory.path,
            totalMemory: Double(info.physicalMemory),
            userID: getuid(),
            groupID: getgid(),
            effectiveUserID: geteuid(),
            effectiveGroupID: getegid(),
            groupIDs: groups,
            environmentVariables: variables,
            additionalSearchPaths: additionalSearchPaths)
    }

    func jsonString() -> String {
        ExtensionRuntime.jsonString(
            from: [
                "node": [
                    "arch": arch,
                    "release": release,
                    "hostname": hostname,
                    "username": username,
                    "shell": shell,
                    "homedir": homeDirectory,
                    "tmpdir": temporaryDirectory,
                    "cwd": workingDirectory,
                    "totalmem": totalMemory,
                    "uid": userID,
                    "gid": groupID,
                    "euid": effectiveUserID,
                    "egid": effectiveGroupID,
                    "groups": groupIDs,
                    "env": environmentVariables,
                    "execPath": ""
                ]
            ])
    }
}

struct ExtensionLaunchContext: Sendable {
    var extensionName: String
    var extensionTitle: String
    var commandName: String
    var commandMode: ExtensionCommandMode
    var assetsPath: String
    var supportPath: String
    var preferences: [String: ExtensionPreferenceValue]
    var caches: [String: [String: String]]
    var formValues: [String: String] = [:]
    var arguments: [String: String]
    var fallbackText: String?
    var launchType: ExtensionLaunchType = .userInitiated
    /// Injected, never read: a running command keeps what it booted with.
    var isDarkAppearance: Bool
    var launchContext: [String: RenderValue] = [:]

    func jsonString() -> String {
        var environment: [String: Any] = [
            "extensionName": extensionName,
            "commandName": commandName,
            "commandMode": commandMode.rawValue,
            "assetsPath": assetsPath,
            "supportPath": supportPath,
            "isDevelopment": false,
            // Extensions gate features on this; report the API level the shim implements.
            "raycastVersion": ExtensionRuntimeVersion.raycastAPI,
            "textSize": "medium",
            "appearance": isDarkAppearance ? "dark" : "light",
            "launchType": launchType.rawValue,
            "canAccess": false
        ]
        environment["ownerOrAuthorName"] = extensionTitle

        var launchProps: [String: Any] = ["launchType": launchType.rawValue, "arguments": arguments]
        if let fallbackText { launchProps["fallbackText"] = fallbackText }
        if !launchContext.isEmpty { launchProps["launchContext"] = launchContext.mapValues(\.jsonValue) }

        return ExtensionRuntime.jsonString(
            from: [
                "environment": environment,
                "preferences": preferences.mapValues(\.jsonValue),
                "caches": caches,
                "formValues": formValues,
                "launchProps": launchProps
            ])
    }
}

enum ExtensionRuntimeVersion {
    /// The @raycast/api version the bundled shim tracks. Surfaced as `environment.raycastVersion`.
    static let raycastAPI = "2.0.3"
}
