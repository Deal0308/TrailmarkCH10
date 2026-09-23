#if os(iOS)
import MapKit
import SwiftUI

/// MapKit is confined to this rendering adapter; route acquisition and memo association
/// are already completed by the location service and view model before data reaches it.
public struct JourneyMapSurface: View {
    private let journey: Journey
    private let memos: [JournalMedia]
    private let onSelectMemo: (JournalMedia) -> Void
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.colorScheme) private var scheme
    public init(journey: Journey, memos: [JournalMedia], onSelectMemo: @escaping (JournalMedia) -> Void) {
        self.journey = journey; self.memos = memos; self.onSelectMemo = onSelectMemo
    }
    public var body: some View {
        if journey.points.isEmpty && memos.allSatisfy({ $0.coordinate == nil }) {
            ScrollView {
                TrailmarkEmptyState(title: "The route begins here", message: "Your route appears with accurate location updates. Memos and Health stay available along the way.", systemImage: "map")
            }
            .trailmarkScreen()
        } else {
            Map(position: $position) {
                ForEach(segments) { segment in
                    if segment.points.count > 1 {
                        MapPolyline(coordinates: segment.points.map(\.mapCoordinate))
                            .stroke(TrailmarkTheme.accent(for: scheme), lineWidth: 5)
                    }
                }
                if let first = journey.points.first { Marker("Start", systemImage: "flag.fill", coordinate: first.mapCoordinate).tint(TrailmarkTheme.forest) }
                if let last = journey.points.last { Marker(journey.status == .recording ? "Latest fix" : "End", systemImage: "flag.checkered", coordinate: last.mapCoordinate).tint(TrailmarkTheme.sky) }
                ForEach(memos) { memo in
                    if let point = memo.coordinate {
                        Annotation(memo.type == .video ? "Video memo" : "Voice memo", coordinate: point.mapCoordinate) {
                            Button { onSelectMemo(memo) } label: {
                                Image(systemName: memo.type == .video ? "video.fill" : "mic.fill")
                                    .frame(width: 44, height: 44).background(TrailmarkTheme.clay, in: Circle()).foregroundStyle(.white)
                            }
                            .accessibilityLabel("Play \(memo.type.rawValue) memo from \(memo.date.formatted(date: .omitted, time: .shortened))")
                        }
                    }
                }
            }
            .mapControls { MapCompass(); MapScaleView() }
            .overlay(alignment: .topTrailing) {
                Button("Fit route", systemImage: "arrow.up.left.and.arrow.down.right") { position = .automatic }
                    .labelStyle(.iconOnly).frame(width: 44, height: 44).background(.regularMaterial, in: Circle()).padding(8)
            }
        }
    }
    private var segments: [Segment] {
        Dictionary(grouping: journey.points, by: \.segment).map { Segment(id: $0.key, points: $0.value) }.sorted { $0.id < $1.id }
    }
    private struct Segment: Identifiable { let id: Int; let points: [GeoPoint] }
}
private extension GeoPoint {
    var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
#endif
