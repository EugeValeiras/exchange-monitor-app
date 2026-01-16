//
//  ExchangeWidget.swift
//  ExchangeWidget
//
//  Created by Eugenio Valeiras on 16/01/2026.
//

import WidgetKit
import SwiftUI

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

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(date: Date(), data: loadData() ?? .placeholder)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let currentDate = Date()
        let data = loadData() ?? .placeholder
        let entry = WidgetEntry(date: currentDate, data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadData() -> WidgetData? {
        let defaults = UserDefaults(suiteName: "group.com.eugeniovaleiras.exchangeMonitor")
        guard let jsonString = defaults?.string(forKey: "widgetData"),
              let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: jsonData)
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

    var body: some View {
        GeometryReader { geometry in
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))

            ZStack {
                // Dashed middle line
                Path { path in
                    let midY = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
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
                            Color.brandAccent.opacity(0.4),
                            Color.brandAccent.opacity(0.0)
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
                .stroke(Color.brandAccent, lineWidth: 2)
            }
        }
    }
}

// MARK: - Asset Row

struct AssetRow: View {
    let asset: AssetData

    var body: some View {
        HStack(spacing: 8) {
            // Logo placeholder (circle with first letter)
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(asset.symbol.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )

            // Symbol and name
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(asset.name)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 55, alignment: .leading)

            // Sparkline
            SparklineChart(data: asset.sparkline, isPositive: asset.change24h >= 0, height: 24)
                .frame(maxWidth: .infinity)

            // Price and change
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPrice(asset.price))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 2) {
                    Image(systemName: asset.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                    Text(String(format: "%.2f %%", abs(asset.change24h)))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(asset.change24h >= 0 ? .positive : .negative)
            }
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$ %.2f", price)
        } else if price >= 1 {
            return String(format: "$ %.4f", price)
        } else {
            return String(format: "$ %.5f", price)
        }
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

    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My Wealth")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)

            Text(formatCurrency(entry.data.totalBalance))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 4) {
                Image(systemName: entry.data.change24hPercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                Text(String(format: "%.2f %%", abs(entry.data.change24hPercent)))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(entry.data.change24hPercent >= 0 ? .positive : .negative)

            Spacer()

            MainChart(data: entry.data.chartData)
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
                    Text("My Wealth")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    Text(formatCurrency(entry.data.totalBalance))
                        .font(.system(size: 24, weight: .bold))
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

            // Chart
            MainChart(data: entry.data.chartData)
                .frame(height: 50)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.widgetBackground)
    }

    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Wealth")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)

                    Text(formatCurrency(entry.data.totalBalance))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("24h")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: entry.data.change24hPercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.2f %%", abs(entry.data.change24hPercent)))
                            .font(.system(size: 14, weight: .semibold))
                        Text("•")
                            .foregroundColor(.textSecondary)
                        Text(formatCurrency(abs(entry.data.change24hUsd)))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(entry.data.change24hPercent >= 0 ? .positive : .negative)
                }
            }

            // Chart
            MainChart(data: entry.data.chartData)
                .frame(height: 70)

            // Markets Watchlist
            Text("Markets Watchlist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.top, 4)

            // Assets
            VStack(spacing: 10) {
                ForEach(entry.data.assets.prefix(3)) { asset in
                    AssetRow(asset: asset)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.widgetBackground)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$ "
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
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    ExchangeWidget()
} timeline: {
    WidgetEntry(date: .now, data: .placeholder)
}
