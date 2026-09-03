import SwiftUI
import UIKit

/// Simple cached image loader that goes through the server's `/api/image` proxy.
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    func load(_ path: String?) {
        image = nil
        guard let url = APIClient.resolveImageURL(path) else { return }
        let key = url.absoluteString as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    Self.cache.setObject(img, forKey: key)
                    await MainActor.run { self.image = img }
                }
            } catch {
                // silently ignore — placeholder remains
            }
        }
    }
}

struct RemoteImage: View {
    let url: String?
    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.card
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .onAppear { loader.load(url) }
        .onChange(of: url) { newValue in loader.load(newValue) }
    }
}
