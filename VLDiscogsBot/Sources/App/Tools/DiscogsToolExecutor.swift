import Foundation

struct DiscogsToolExecutor: Sendable {
    private let token: String
    private let username: String

    init(token: String, username: String) {
        self.token = token
        self.username = username
    }

    func execute(tool: String, input: [String: JSONValue]) async throws -> String {
        switch tool {
        case "search_discogs":
            let query = input["query"]?.string ?? ""
            let type  = input["type"]?.string
            return try await search(query: query, type: type)

        case "get_release":
            guard let id = input["release_id"]?.int else {
                return "Error: release_id is required"
            }
            return try await getRelease(id: id)

        case "get_collection":
            let page    = input["page"]?.int    ?? 1
            let perPage = input["per_page"]?.int ?? 25
            return try await getCollection(page: page, perPage: perPage)

        case "get_collection_value":
            return try await getCollectionValue()

        case "search_collection":
            let query = input["query"]?.string ?? ""
            return try await searchCollection(query: query)

        case "random_from_collection":
            return try await randomFromCollection()

        default:
            return "Unknown tool: \(tool)"
        }
    }

    // MARK: - Private

    private func search(query: String, type: String?) async throws -> String {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
        if let type { items.append(URLQueryItem(name: "type", value: type)) }
        items.append(URLQueryItem(name: "per_page", value: "5"))
        components.queryItems = items

        let data = try await get(components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []

        if results.isEmpty { return "No results found for '\(query)'." }

        let lines = results.prefix(5).map { r -> String in
            let title   = r["title"]  as? String ?? "Unknown"
            let id      = r["id"]     as? Int    ?? 0
            let year    = r["year"]   as? String ?? "?"
            let country = r["country"] as? String ?? "?"
            return "• \(title) (ID: \(id), \(year), \(country))"
        }
        return "Search results for '\(query)':\n" + lines.joined(separator: "\n")
    }

    private func getRelease(id: Int) async throws -> String {
        let url = URL(string: "https://api.discogs.com/releases/\(id)")!
        let data = try await get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let title   = json["title"]  as? String ?? "Unknown"
        let year    = json["year"]   as? Int    ?? 0
        let country = json["country"] as? String ?? "Unknown"
        let artists = (json["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown"
        let labels  = (json["labels"]  as? [[String: Any]])?.compactMap { $0["name"] as? String }.first ?? "Unknown"
        let genres  = (json["genres"]  as? [String])?.joined(separator: ", ") ?? "Unknown"
        let formats = (json["formats"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown"
        let notes   = json["notes"] as? String

        var lines = [
            "Title: \(title)",
            "Artist: \(artists)",
            "Year: \(year)",
            "Country: \(country)",
            "Label: \(labels)",
            "Genre: \(genres)",
            "Format: \(formats)",
        ]
        if let notes { lines.append("Notes: \(notes)") }

        if let pricing = json["lowest_price"] as? Double {
            lines.append("Lowest price: $\(String(format: "%.2f", pricing))")
        }

        return lines.joined(separator: "\n")
    }

    private func getCollection(page: Int, perPage: Int) async throws -> String {
        let clamped = min(max(perPage, 1), 100)
        var components = URLComponents(string: "https://api.discogs.com/users/\(username)/collection/folders/0/releases")!
        components.queryItems = [
            URLQueryItem(name: "page",     value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(clamped)"),
            URLQueryItem(name: "sort",     value: "added"),
            URLQueryItem(name: "sort_order", value: "desc"),
        ]

        let data = try await get(components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let releases = json["releases"] as? [[String: Any]] ?? []
        let pagination = json["pagination"] as? [String: Any] ?? [:]
        let total = pagination["items"] as? Int ?? 0
        let pages = pagination["pages"] as? Int ?? 1

        if releases.isEmpty { return "Your collection is empty." }

        let lines = releases.map { r -> String in
            let info   = r["basic_information"] as? [String: Any] ?? [:]
            let title  = info["title"]  as? String ?? "Unknown"
            let artist = (info["artists"] as? [[String: Any]])?.first?["name"] as? String ?? "Unknown"
            let year   = info["year"]   as? Int ?? 0
            let id     = r["id"]        as? Int ?? 0
            return "• \(artist) – \(title) (\(year)) [ID: \(id)]"
        }

        return "Collection (page \(page)/\(pages), \(total) total):\n" + lines.joined(separator: "\n")
    }

    private func randomFromCollection() async throws -> String {
        // First call to get total count
        var components = URLComponents(string: "https://api.discogs.com/users/\(username)/collection/folders/0/releases")!
        components.queryItems = [
            URLQueryItem(name: "page",     value: "1"),
            URLQueryItem(name: "per_page", value: "1"),
        ]
        let firstData = try await get(components.url!)
        let firstJson = try JSONSerialization.jsonObject(with: firstData) as? [String: Any] ?? [:]
        let pagination = firstJson["pagination"] as? [String: Any] ?? [:]
        let total = pagination["items"] as? Int ?? 0

        guard total > 0 else { return "Your collection is empty." }

        let randomIndex = Int.random(in: 0..<total)
        let page = randomIndex / 100 + 1
        let offset = randomIndex % 100

        components.queryItems = [
            URLQueryItem(name: "page",     value: "\(page)"),
            URLQueryItem(name: "per_page", value: "100"),
        ]
        let data = try await get(components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let releases = json["releases"] as? [[String: Any]] ?? []

        guard offset < releases.count, let r = releases[safe: offset] else {
            return "Could not retrieve a random record."
        }

        let info   = r["basic_information"] as? [String: Any] ?? [:]
        let title  = info["title"]  as? String ?? "Unknown"
        let artist = (info["artists"] as? [[String: Any]])?.first?["name"] as? String ?? "Unknown"
        let year   = info["year"]   as? Int ?? 0
        let id     = r["id"]        as? Int ?? 0
        let genres = (info["genres"] as? [String])?.joined(separator: ", ") ?? "Unknown"

        return "Random pick from your collection (\(total) total):\n• \(artist) – \(title) (\(year))\n  Genre: \(genres)\n  Release ID: \(id)"
    }

    private func searchCollection(query: String) async throws -> String {
        let lowered = query.lowercased()
        var matches: [String] = []
        var page = 1

        outer: repeat {
            var components = URLComponents(string: "https://api.discogs.com/users/\(username)/collection/folders/0/releases")!
            components.queryItems = [
                URLQueryItem(name: "page",     value: "\(page)"),
                URLQueryItem(name: "per_page", value: "100"),
            ]
            let data = try await get(components.url!)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let releases  = json["releases"]  as? [[String: Any]] ?? []
            let pagination = json["pagination"] as? [String: Any] ?? [:]
            let pages = pagination["pages"] as? Int ?? 1

            for r in releases {
                let info   = r["basic_information"] as? [String: Any] ?? [:]
                let title  = info["title"]  as? String ?? ""
                let artist = (info["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
                let year   = info["year"]   as? Int ?? 0
                let id     = r["id"]        as? Int ?? 0

                if title.lowercased().contains(lowered) || artist.lowercased().contains(lowered) {
                    matches.append("• \(artist) – \(title) (\(year)) [ID: \(id)]")
                }
            }

            if page >= pages { break outer }
            page += 1
        } while matches.count < 50

        if matches.isEmpty { return "No releases matching '\(query)' found in your collection." }
        return "Collection matches for '\(query)':\n" + matches.joined(separator: "\n")
    }

    private func getCollectionValue() async throws -> String {
        let url = URL(string: "https://api.discogs.com/users/\(username)/collection/value")!
        let data = try await get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let minimum = json["minimum"] as? String ?? "N/A"
        let median  = json["median"]  as? String ?? "N/A"
        let maximum = json["maximum"] as? String ?? "N/A"

        return "Collection value estimate:\n• Minimum: \(minimum)\n• Median: \(median)\n• Maximum: \(maximum)"
    }

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization")
        req.setValue("VLDiscogsBot/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DiscogsError.httpError(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        return data
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum DiscogsError: Error {
    case httpError(Int, String)
}
