import SwiftUI
import UIKit

struct GameCardView: View {
    let game: Game
    let progress: Double
    let artwork: UIImage?
    let containerStatus: ContainerStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artworkOrPlaceholder
                .frame(maxWidth: .infinity)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    playBadge
                }
                .overlay(alignment: .topLeading) {
                    if game.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(game.executableName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            metadataRow
        }
    }

    private var artworkOrPlaceholder: some View {
        Group {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
            .padding(8)
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if let lastPlayed = game.lastPlayed {
                Label(lastPlayed.relativeDescription, systemImage: "clock")
                    .lineLimit(1)
            } else {
                Label("Never", systemImage: "clock")
            }
            Spacer()
            if let containerStatus {
                Circle()
                    .fill(containerColor(containerStatus))
                    .frame(width: 8, height: 8)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func containerColor(_ status: ContainerStatus) -> Color {
        switch status {
        case .notCreated: return .gray.opacity(0.5)
        case .creating: return .blue
        case .ready: return .green
        case .launching: return .orange
        case .running: return .green
        case .error: return .red
        case .resetting: return .orange
        case .deleted: return .gray.opacity(0.5)
        }
    }
}