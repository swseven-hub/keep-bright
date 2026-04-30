import Foundation

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseName: String
    let releaseURL: URL
    let downloadURL: URL?
}

enum UpdateCheckResult {
    case updateAvailable(UpdateInfo)
    case upToDate(currentVersion: String, latestVersion: String)
    case failed(String)
}

final class UpdateChecker {
    private let defaultsKey = "LastAutomaticUpdateCheckDate"
    private let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/swseven-hub/keep-bright/releases/latest")!
    private static let releasePathPrefix = "/swseven-hub/keep-bright/releases/"
    private static let downloadPathPrefix = "/swseven-hub/keep-bright/releases/download/"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func checkAutomatically(completion: @escaping (UpdateCheckResult) -> Void) {
        guard shouldCheckAutomatically() else {
            return
        }

        check { [weak self] result in
            if case .failed = result {
                completion(result)
                return
            }

            self?.markAutomaticCheckDate()
            completion(result)
        }
    }

    func check(completion: @escaping (UpdateCheckResult) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KeepBright/\(Self.headerSafeToken(currentVersion))", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            let result = self.parseResponse(data: data, response: response, error: error)
            DispatchQueue.main.async {
                completion(result)
            }
        }.resume()
    }

    private func shouldCheckAutomatically(now: Date = Date()) -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: defaultsKey) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastDate) >= automaticCheckInterval
    }

    private func markAutomaticCheckDate(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: defaultsKey)
    }

    private func parseResponse(data: Data?, response: URLResponse?, error: Error?) -> UpdateCheckResult {
        if let error {
            return .failed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failed("没有收到有效的服务器响应。")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            return .failed("GitHub 返回了 HTTP \(httpResponse.statusCode)。")
        }

        guard let data else {
            return .failed("GitHub 响应为空。")
        }

        do {
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.normalizedTagName
            guard let releaseURL = Self.trustedGitHubReleaseURL(release.htmlURL) else {
                return .failed("GitHub 返回了不可信的发布链接。")
            }

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                let downloadURL = release.assets
                    .first { $0.name.hasSuffix(".zip") }
                    .flatMap { Self.trustedGitHubDownloadURL(from: $0.browserDownloadURL) }

                let info = UpdateInfo(
                    currentVersion: currentVersion,
                    latestVersion: latestVersion,
                    releaseName: release.displayName,
                    releaseURL: releaseURL,
                    downloadURL: downloadURL
                )
                return .updateAvailable(info)
            }

            return .upToDate(currentVersion: currentVersion, latestVersion: latestVersion)
        } catch {
            return .failed("无法解析 GitHub 版本信息：\(error.localizedDescription)")
        }
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = numericVersionParts(candidate)
        let currentParts = numericVersionParts(current)
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let candidateValue = index < candidateParts.count ? candidateParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0

            if candidateValue > currentValue {
                return true
            }

            if candidateValue < currentValue {
                return false
            }
        }

        return false
    }

    private static func trustedGitHubReleaseURL(_ url: URL) -> URL? {
        guard url.scheme == "https",
              url.host?.lowercased() == "github.com",
              url.path.hasPrefix(releasePathPrefix) else {
            return nil
        }

        return url
    }

    private static func trustedGitHubDownloadURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme == "https",
              url.host?.lowercased() == "github.com",
              url.path.hasPrefix(downloadPathPrefix) else {
            return nil
        }

        return url
    }

    private static func headerSafeToken(_ value: String) -> String {
        let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_"
        let filteredCharacters = value.map { character in
            allowedCharacters.contains(character) ? character : "_"
        }
        let token = String(filteredCharacters)
        return token.isEmpty ? "0.0.0" : token
    }

    private static func numericVersionParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    var displayName: String {
        guard let name, !name.isEmpty else {
            return tagName
        }

        return name
    }

    var normalizedTagName: String {
        tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }

        return String(dropFirst(prefix.count))
    }
}
