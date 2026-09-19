import Foundation

enum AppRoute: Hashable {
    case welcome
    case folder(URL)
    case document(URL)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute = .welcome

    func navigate(to route: AppRoute) {
        self.route = route
    }
}
