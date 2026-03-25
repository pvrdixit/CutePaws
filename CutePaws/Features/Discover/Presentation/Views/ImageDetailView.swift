import SwiftUI
import UIKit

struct ImageDetailView: View {
    @ObservedObject var viewModel: ImageDetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor.ignoresSafeArea()

            TabView(selection: $viewModel.selectedIndex) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    imagePage(for: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard !isCurrentImageZoomed else { return }
                        guard value.translation.height > 120 else { return }
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        dismiss()
                    }
            )

            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
        .onChange(of: viewModel.selectedIndex) { _, _ in
            isCurrentImageZoomed = false
        }
        .statusBarHidden()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentBreedName)
                    .font(.headline)
                    .foregroundStyle(headerForegroundColor)

                Text(viewModel.positionText)
                    .font(.caption)
                    .foregroundStyle(headerForegroundColor.opacity(0.72))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(headerForegroundColor)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
        }
    }

    @ViewBuilder
    private func imagePage(for item: MediaItem) -> some View {
        if hasImage(at: item.localFilePath) {
            ZoomableImageView(
                imagePath: item.localFilePath,
                imageID: item.id,
                isSelected: viewModel.currentItem?.id == item.id
            ) { isZoomed in
                if viewModel.currentItem?.id == item.id {
                    isCurrentImageZoomed = isZoomed
                }
            }
            .ignoresSafeArea()
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo")
                .foregroundStyle(emptyStateForegroundColor)
        }
    }

    private func hasImage(at path: String?) -> Bool {
        guard let path else { return false }
        return UIImage(contentsOfFile: path) != nil
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(uiColor: .systemBackground)
    }

    private var headerForegroundColor: Color {
        Color(uiColor: .label)
    }

    private var emptyStateForegroundColor: Color {
        Color(uiColor: .secondaryLabel)
    }
}

#Preview {
    let items = PreviewData.mediaItems
    return ImageDetailView(
        viewModel: ImageDetailViewModel(items: items, selectedItemID: items[0].id)
    )
}
