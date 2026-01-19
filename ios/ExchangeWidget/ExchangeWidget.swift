//
//  ExchangeWidget.swift
//  ExchangeWidget
//
//  Created by Eugenio Valeiras on 16/01/2026.
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Data Models

struct WidgetData: Codable {
    let totalBalance: Double
    let change24hPercent: Double
    let change24hUsd: Double
    let chartData: [Double]
    let assets: [AssetData]
    let lastUpdated: String

    static let placeholder = WidgetData(
        totalBalance: 144384.00,
        change24hPercent: 0.39,
        change24hUsd: 561.04,
        chartData: [100, 102, 101, 103, 105, 104, 106, 108, 107, 110, 112, 115],
        assets: [
            AssetData(symbol: "BTC", name: "Bitcoin", price: 95295.68, change24h: -0.77, sparkline: [95000, 95200, 95100, 95300, 95250, 95295]),
            AssetData(symbol: "NEXO", name: "NEXO Token", price: 1.0045, change24h: 3.71, sparkline: [0.97, 0.98, 0.99, 1.00, 1.002, 1.0045]),
            AssetData(symbol: "MON", name: "Monad", price: 0.02192, change24h: -4.53, sparkline: [0.023, 0.0225, 0.022, 0.0218, 0.0219, 0.02192])
        ],
        lastUpdated: ""
    )
}

struct AssetData: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let change24h: Double
    let sparkline: [Double]
}

// MARK: - API Response Models

struct BalanceResponse: Codable {
    let totalValueUsd: Double
    let change24h: Double?
    let changeUsd24h: Double?
    let byAsset: [AssetBalanceResponse]
}

struct AssetBalanceResponse: Codable {
    let asset: String
    let priceUsd: Double?
    let change24h: Double?
}

struct ChartDataResponse: Codable {
    let labels: [String]
    let data: [Double]
    let changeUsd: Double
    let changePercent: Double
    let timeframe: String
}

struct FavoritesResponse: Codable {
    let favorites: [String]
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let apiBaseUrl = "https://exchange-monitor-api.fly.dev/api"
    private let appGroupId = "group.com.eugeniovaleiras.exchangeMonitor"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(date: Date(), data: loadCachedData() ?? .placeholder)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        print("[Widget] getTimeline called at \(Date())")

        // Save timestamp to UserDefaults so we can debug from main app
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastTimelineCall")

        // Use cached data from Flutter (iOS widgets can't reliably make network requests in background)
        let data = loadCachedData() ?? .placeholder
        let currentDate = Date()

        defaults?.set(data.lastUpdated.isEmpty ? "no_cached_data" : "using_cache", forKey: "lastFetchError")
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastFetchTime")
        defaults?.set(!data.lastUpdated.isEmpty, forKey: "lastFetchSuccess")

        print("[Widget] Using cached data, lastUpdated: \(data.lastUpdated)")

        // Generate entries for the next 30 minutes (every 5 minutes)
        var entries: [WidgetEntry] = []
        for minuteOffset in stride(from: 0, to: 30, by: 5) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            entries.append(WidgetEntry(date: entryDate, data: data))
        }

        // Use .atEnd so iOS calls getTimeline again when all entries are consumed
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func loadCachedData() -> WidgetData? {
        let defaults = UserDefaults(suiteName: appGroupId)
        guard let jsonString = defaults?.string(forKey: "widgetData"),
              let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: jsonData)
    }

    private func getAuthToken() -> String? {
        let defaults = UserDefaults(suiteName: appGroupId)
        return defaults?.string(forKey: "authToken")
    }

    private func fetchFreshData(completion: @escaping (WidgetData?) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupId)

        guard let token = getAuthToken() else {
            print("[Widget] No auth token available")
            defaults?.set("no_token", forKey: "lastFetchError")
            completion(nil)
            return
        }

        print("[Widget] Auth token found: \(token)")
        defaults?.set(token, forKey: "debugToken")

        let group = DispatchGroup()

        var balanceResponse: BalanceResponse?
        var chartData: [Double] = []
        var favorites: [String] = []

        // Fetch balance data
        group.enter()
        fetchBalances(token: token) { response in
            balanceResponse = response
            group.leave()
        }

        // Fetch chart data
        group.enter()
        fetchChartData(token: token) { data in
            chartData = data
            group.leave()
        }

        // Fetch favorites
        group.enter()
        fetchFavorites(token: token) { favs in
            favorites = favs
            group.leave()
        }

        // Wait for all requests to complete
        group.notify(queue: .main) { [self] in
            guard let balance = balanceResponse else {
                print("[Widget] Balance fetch failed")
                defaults?.set("balance_fetch_failed", forKey: "lastFetchError")
                completion(nil)
                return
            }

            print("[Widget] Balance fetched successfully: $\(balance.totalValueUsd)")

            // Use fetched favorites or fallback to defaults
            let favoriteSymbols = favorites.isEmpty ? ["BTC", "ETH", "SOL"] : Array(favorites.prefix(3))

            // Build assets from balance data
            let assets = favoriteSymbols.compactMap { symbol -> AssetData? in
                guard let asset = balance.byAsset.first(where: { $0.asset.uppercased() == symbol.uppercased() }) else {
                    return nil
                }

                // Generate sparkline based on price and change
                let price = asset.priceUsd ?? 0
                let change = asset.change24h ?? 0
                let sparkline = generateSparkline(currentPrice: price, change24h: change)

                return AssetData(
                    symbol: symbol.uppercased(),
                    name: getAssetName(symbol.uppercased()),
                    price: price,
                    change24h: change,
                    sparkline: sparkline
                )
            }

            // Use fetched chart data or fallback to cache
            let cachedData = loadCachedData()
            let finalChartData = chartData.isEmpty ? (cachedData?.chartData ?? []) : chartData

            let widgetData = WidgetData(
                totalBalance: balance.totalValueUsd,
                change24hPercent: balance.change24h ?? 0,
                change24hUsd: balance.changeUsd24h ?? 0,
                chartData: finalChartData,
                assets: assets.isEmpty ? (cachedData?.assets ?? []) : assets,
                lastUpdated: ISO8601DateFormatter().string(from: Date())
            )

            // Save to cache
            if let jsonData = try? JSONEncoder().encode(widgetData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                defaults?.set(jsonString, forKey: "widgetData")
                defaults?.set("success", forKey: "lastFetchError")
                print("[Widget] Data saved to cache successfully")
            }

            completion(widgetData)
        }
    }

    private func fetchBalances(token: String, completion: @escaping (BalanceResponse?) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupId)

        guard let url = URL(string: "\(apiBaseUrl)/balances") else {
            defaults?.set("invalid_url", forKey: "balanceError")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30 // Increased timeout

        print("[Widget] Fetching balances from: \(url)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Widget] Balance fetch error: \(error.localizedDescription)")
                defaults?.set("network_error: \(error.localizedDescription)", forKey: "balanceError")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                defaults?.set("no_http_response", forKey: "balanceError")
                completion(nil)
                return
            }

            print("[Widget] Balance response status: \(httpResponse.statusCode)")
            defaults?.set("status_\(httpResponse.statusCode)", forKey: "balanceError")

            guard httpResponse.statusCode == 200 else {
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("[Widget] Error body: \(body)")
                    defaults?.set("status_\(httpResponse.statusCode): \(body.prefix(100))", forKey: "balanceError")
                }
                completion(nil)
                return
            }

            guard let data = data else {
                defaults?.set("no_data", forKey: "balanceError")
                completion(nil)
                return
            }

            do {
                let balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
                defaults?.set("success", forKey: "balanceError")
                completion(balanceResponse)
            } catch {
                print("[Widget] JSON decode error: \(error)")
                defaults?.set("decode_error: \(error.localizedDescription)", forKey: "balanceError")
                completion(nil)
            }
        }.resume()
    }

    private func fetchChartData(token: String, completion: @escaping ([Double]) -> Void) {
        guard let url = URL(string: "\(apiBaseUrl)/snapshots/chart-data?timeframe=24h") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let chartResponse = try? JSONDecoder().decode(ChartDataResponse.self, from: data) else {
                completion([])
                return
            }
            completion(chartResponse.data)
        }.resume()
    }

    private func fetchFavorites(token: String, completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "\(apiBaseUrl)/favorites") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let favoritesResponse = try? JSONDecoder().decode(FavoritesResponse.self, from: data) else {
                completion([])
                return
            }
            completion(favoritesResponse.favorites)
        }.resume()
    }

    private func generateSparkline(currentPrice: Double, change24h: Double) -> [Double] {
        guard currentPrice > 0 else { return [] }

        let startPrice = currentPrice / (1 + change24h / 100)
        let priceChange = currentPrice - startPrice
        var sparkline: [Double] = []

        for i in 0..<6 {
            let progress = Double(i) / 5.0
            // Add some variance to make it look more natural
            let variance = (i % 2 == 0 ? 0.02 : -0.01) * priceChange
            sparkline.append(startPrice + (priceChange * progress) + variance)
        }
        sparkline[5] = currentPrice // Ensure last point is current price

        return sparkline
    }

    private func getAssetName(_ symbol: String) -> String {
        let names: [String: String] = [
            "BTC": "Bitcoin",
            "ETH": "Ethereum",
            "NEXO": "NEXO Token",
            "MON": "Monad",
            "USDT": "Tether",
            "USDC": "USD Coin"
        ]
        return names[symbol] ?? symbol
    }
}

// MARK: - Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Colors

extension Color {
    static let widgetBackground = Color(red: 0.043, green: 0.055, blue: 0.067)
    static let brandAccent = Color(red: 0, green: 0.761, blue: 1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let positive = Color(red: 0.2, green: 0.78, blue: 0.64)
    static let negative = Color(red: 0.94, green: 0.27, blue: 0.27)
}

// MARK: - Sparkline Chart

struct SparklineChart: View {
    let data: [Double]
    let isPositive: Bool
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))

            ZStack {
                // Gradient fill
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (isPositive ? Color.positive : Color.negative).opacity(0.3),
                            (isPositive ? Color.positive : Color.negative).opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(isPositive ? Color.positive : Color.negative, lineWidth: 1.5)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Main Chart

struct MainChart: View {
    let data: [Double]
    let isPositive: Bool

    var body: some View {
        GeometryReader { geometry in
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))

            // Calculate Y position of first point (baseline for 24h comparison)
            let firstValue = data.first ?? 0
            let firstNormalizedY = range > 0 ? (firstValue - minValue) / range : 0.5
            let baselineY = geometry.size.height * (1 - CGFloat(firstNormalizedY))

            ZStack {
                // Dashed baseline at first point (24h ago)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: baselineY))
                }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Gradient fill
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (isPositive ? Color.positive : Color.negative).opacity(0.4),
                            (isPositive ? Color.positive : Color.negative).opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Main line
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(isPositive ? Color.positive : Color.negative, lineWidth: 2)
            }
        }
    }
}

// MARK: - Coin Icon

struct CoinIcon: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(named: symbol.lowercased()) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback for coins without bundled icon
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Text(String(symbol.prefix(1)))
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Asset Row (Small/Medium widgets)

struct AssetRow: View {
    let asset: AssetData

    var body: some View {
        HStack(spacing: 6) {
            // Coin icon
            CoinIcon(symbol: asset.symbol, size: 28)

            // Symbol and name
            VStack(alignment: .leading, spacing: 1) {
                Text(asset.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(asset.name)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 50, alignment: .leading)

            // Sparkline
            SparklineChart(data: asset.sparkline, isPositive: asset.change24h >= 0, height: 20)
                .frame(maxWidth: .infinity)

            // Price and change
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatPrice(asset.price))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 2) {
                    Image(systemName: asset.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                    Text(String(format: "%.2f%%", abs(asset.change24h)))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(asset.change24h >= 0 ? .positive : .negative)
            }
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.2f", price)
        } else if price >= 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.5f", price)
        }
    }
}

// MARK: - Asset Row Large (Large widget)

struct AssetRowLarge: View {
    let asset: AssetData

    var body: some View {
        HStack(spacing: 8) {
            // Coin icon
            CoinIcon(symbol: asset.symbol, size: 32)

            // Symbol and name
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(asset.name)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 75, alignment: .leading)

            // Sparkline chart
            SparklineChart(
                data: asset.sparkline.isEmpty ? [0, 0] : asset.sparkline,
                isPositive: asset.change24h >= 0,
                height: 35
            )

            // Price and change
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPrice(asset.price))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 2) {
                    Image(systemName: asset.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                    Text(String(format: "%.2f %%", abs(asset.change24h)))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(asset.change24h >= 0 ? .positive : .negative)
            }
            .frame(width: 75, alignment: .trailing)
        }
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.groupingSeparator = ","

        if price >= 1000 {
            formatter.maximumFractionDigits = 2
        } else if price >= 1 {
            formatter.maximumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 5
        }

        let formatted = formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
        return "$ \(formatted)"
    }
}

// MARK: - Widget View

struct ExchangeWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemLarge:
            largeWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private func formatLastUpdated(_ isoString: String) -> String {
        // Debug: show raw string if empty
        if isoString.isEmpty {
            return "No data"
        }

        var date: Date?

        // Try standard ISO8601 format first
        let isoFormatter = ISO8601DateFormatter()
        date = isoFormatter.date(from: isoString)

        // Try with fractional seconds (Flutter format: 2024-01-19T15:30:45.123456)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = isoFormatter.date(from: isoString)
        }

        // Fallback: try DateFormatter with multiple formats
        if date == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]

            for format in formats {
                dateFormatter.dateFormat = format
                if let parsed = dateFormatter.date(from: isoString) {
                    date = parsed
                    break
                }
            }
        }

        // If still no date, show parse error
        guard let finalDate = date else {
            return "Parse err"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: finalDate)
    }

    private func formatEntryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("My Wealth")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Spacer()
                // Show entry date (when iOS rendered) to debug refresh
                Text(formatEntryDate(entry.date))
                    .font(.system(size: 10))
                    .foregroundColor(.brandAccent.opacity(0.8))
            }

            Text(formatCurrency(entry.data.totalBalance))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.textPrimary)

            HStack(spacing: 4) {
                Image(systemName: entry.data.change24hPercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                Text(String(format: "%.2f %%", abs(entry.data.change24hPercent)))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(entry.data.change24hPercent >= 0 ? .positive : .negative)

            Spacer()

            MainChart(data: entry.data.chartData, isPositive: entry.data.change24hPercent >= 0)
                .frame(height: 40)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.widgetBackground)
    }

    var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("My Wealth")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.textSecondary.opacity(0.5))
                        Text(formatEntryDate(entry.date))
                            .font(.system(size: 10))
                            .foregroundColor(.brandAccent.opacity(0.8))
                    }

                    Text(formatCurrency(entry.data.totalBalance))
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("24h")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: entry.data.change24hPercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.2f %%", abs(entry.data.change24hPercent)))
                            .font(.system(size: 13, weight: .semibold))
                        Text("•")
                            .foregroundColor(.textSecondary)
                        Text(formatCurrency(abs(entry.data.change24hUsd)))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(entry.data.change24hPercent >= 0 ? .positive : .negative)
                }
            }

            Spacer()

            // Chart
            MainChart(data: entry.data.chartData, isPositive: entry.data.change24hPercent >= 0)
                .frame(height: 50)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.widgetBackground)
    }

    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            // My Wealth label with entry date for debug
            HStack {
                Text("My Wealth")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary.opacity(0.5))
                Text(formatEntryDate(entry.date))
                    .font(.system(size: 10))
                    .foregroundColor(.brandAccent.opacity(0.8))
                Spacer()
            }

            // Balance
            Text(formatCurrency(entry.data.totalBalance))
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.textPrimary)
                .padding(.top, 1)
                .padding(.bottom, 2)

            // 24h row
            HStack {
                Text("24h")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: entry.data.change24hPercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 9))
                    Text(String(format: "%.2f %%", abs(entry.data.change24hPercent)))
                        .font(.system(size: 13, weight: .medium))
                    Text("•")
                        .foregroundColor(.textSecondary)
                    Text(formatCurrency(abs(entry.data.change24hUsd)))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(entry.data.change24hPercent >= 0 ? .positive : .negative)
            }
            .padding(.bottom, 6)

            // Chart
            MainChart(data: entry.data.chartData, isPositive: entry.data.change24hPercent >= 0)
                .frame(height: 75)

            // Spacer pushes Markets Watchlist to bottom
            Spacer()

            // Markets Watchlist
            Text("Markets Watchlist")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .padding(.bottom, 8)

            // Assets
            VStack(spacing: 0) {
                ForEach(Array(entry.data.assets.prefix(3).enumerated()), id: \.element.id) { index, asset in
                    AssetRowLarge(asset: asset)
                        .padding(.vertical, 8)
                    if index < min(entry.data.assets.count, 3) - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.widgetBackground)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$ "
        formatter.roundingMode = .down  // Truncate instead of round
        formatter.maximumFractionDigits = value >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$ 0"
    }
}

// MARK: - Widget Configuration

struct ExchangeWidget: Widget {
    let kind: String = "ExchangeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ExchangeWidgetEntryView(entry: entry)
                    .containerBackground(Color.widgetBackground, for: .widget)
            } else {
                ExchangeWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Exchange Monitor")
        .description("Track your crypto portfolio")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    ExchangeWidget()
} timeline: {
    WidgetEntry(date: .now, data: .placeholder)
}
