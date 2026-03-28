import Foundation

enum DiscoverViewState: Equatable {
    case loading
    case loaded
    case error(String)
}
