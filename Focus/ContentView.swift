import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "scope")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Focus")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
