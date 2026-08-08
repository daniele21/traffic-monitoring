#if os(macOS)
import Combine
import Foundation

@MainActor
final class HistoricalAnalyticsViewModel: ObservableObject {
    @Published private(set) var overallSummary = UsageSummary()
    @Published private(set) var trendSummary = UsageSummary()
    @Published private(set) var networkRows: [NetworkUsageHistoryRow] = []
    @Published private(set) var trendByNetwork: [NetworkTrendPoint] = []
    @Published private(set) var totalTrend: [UsageTrendPoint] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefreshedAt: Date?

    let store: LocalUsageStore
    private let aggregator = UsageAnalyticsAggregator()

    init(store: LocalUsageStore) {
        self.store = store
    }

    var peakPoint: UsageTrendPoint? {
        totalTrend.max { $0.totalBytes < $1.totalBytes }
    }

    var networkPeakPoint: NetworkTrendPoint? {
        trendByNetwork.max { $0.totalBytes < $1.totalBytes }
    }

    func refresh(
        timeframe: AnalyticsTimeframe,
        customStart: Date,
        customEnd: Date,
        selectedNetworkIdentity: String?
    ) {
        do {
            let period = timeframe.interval(customStart: customStart, customEnd: customEnd)
            let snapshots = try store.snapshots(in: period)
            let granularity = timeframe.granularity

            overallSummary = aggregator.summary(snapshots)
            networkRows = aggregator.usageByNetwork(snapshots)

            let trendBuckets: [UsageBucketSnapshot]
            if let selectedNetworkIdentity {
                trendBuckets = snapshots.filter { $0.identityKey == selectedNetworkIdentity }
            } else {
                trendBuckets = snapshots
            }

            trendSummary = aggregator.summary(trendBuckets)
            trendByNetwork = aggregator.trendByNetwork(trendBuckets, granularity: granularity)
            totalTrend = aggregator.timeSeries(trendBuckets, granularity: granularity)
            lastRefreshedAt = Date()
            errorMessage = store.persistenceErrorMessage
        } catch {
            errorMessage = "Analytics could not be loaded: \(error.localizedDescription)"
        }
    }
}

enum AnalyticsTimeframe: String, CaseIterable, Identifiable {
    case today = "Today"
    case sevenDays = "7 days"
    case thirtyDays = "30 days"
    case month = "This month"
    case all = "All time"
    case custom = "Custom"

    var id: Self { self }

    var granularity: UsageTimeGranularity {
        switch self {
        case .today:
            .hour
        case .sevenDays, .thirtyDays, .month, .all, .custom:
            .day
        }
    }

    var peakLabel: String {
        granularity == .hour ? "Highest usage hour" : "Highest usage day"
    }

    func interval(
        now: Date = Date(),
        customStart: Date,
        customEnd: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .today:
            return DateInterval(start: calendar.startOfDay(for: now), end: now)

        case .sevenDays:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return DateInterval(start: start, end: now)

        case .thirtyDays:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return DateInterval(start: start, end: now)

        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)

        case .all:
            return nil

        case .custom:
            let firstDay = min(calendar.startOfDay(for: customStart), calendar.startOfDay(for: customEnd))
            let lastDay = max(calendar.startOfDay(for: customStart), calendar.startOfDay(for: customEnd))
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)
            return DateInterval(start: firstDay, end: exclusiveEnd)
        }
    }
}
#endif
