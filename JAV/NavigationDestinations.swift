import SwiftUI

extension View {
    /// Registers the shared navigation destinations used by value-based
    /// `NavigationLink`s (movies and people) across every tab stack.
    func appDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { MovieDetailView(movie: $0) }
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
    }
}
