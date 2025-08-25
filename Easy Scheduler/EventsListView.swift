import SwiftUI

struct EventsListView: View {
    var body: some View {
        NavigationView {
            Text("Your events will appear here.")
                .navigationTitle("Your Events")
        }
    }
}

struct EventsListView_Previews: PreviewProvider {
    static var previews: some View {
        EventsListView()
    }
}
