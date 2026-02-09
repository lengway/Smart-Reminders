import SwiftUI
import UserNotifications
import CoreLocation

struct PermissionsBannerView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Требуются разрешения для уведомлений и локации")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            HStack(spacing: 12) {
                permissionPill(title: "Уведомления", status: viewModel.notificationStatus)
                permissionPill(title: "Локация", status: viewModel.locationStatus)
                Spacer()
                Button {
                    Task { await viewModel.requestNotifications(); await viewModel.requestLocation() }
                } label: {
                    Text("Разрешить")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isRequesting)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Разрешения нужны для корректной работы уведомлений и геозон")
    }
    
    private func permissionPill(title: String, status: UNAuthorizationStatus) -> some View {
        let color: Color
        switch status {
        case .authorized, .provisional, .ephemeral:
            color = .green
        case .denied:
            color = .red
        default:
            color = .gray
        }
        return Label(title, systemImage: "shield.lefthalf.fill")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    private func permissionPill(title: String, status: CLAuthorizationStatus) -> some View {
        let color: Color
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            color = .green
        case .denied, .restricted:
            color = .red
        default:
            color = .gray
        }
        return Label(title, systemImage: "location.fill")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
