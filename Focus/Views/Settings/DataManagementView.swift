import SwiftUI
import SwiftData
import UIKit

// MARK: - DataManagementView

/// Provides controls for exporting and importing user-configured Focus data.
///
/// Export produces a JSON file containing organizations, departments, disciplines,
/// job titles, teams, repositories, and members. Synced data (alerts, contributions)
/// is excluded because it is re-fetched from GitHub after reinstall.
struct DataManagementView: View {

    // MARK: - Properties

    @Environment(\.modelContext) private var context

    @State private var exportURL: IdentifiableURL?
    @State private var showImporter = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isPurging = false
    @State private var showPurgeConfirmation = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Button {
                    exportData()
                } label: {
                    if isExporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .disabled(isExporting || isImporting)
            } header: {
                Text("Export")
            } footer: {
                Text("Saves a JSON file containing your repositories, teams, members, and settings. Synced data from GitHub is excluded and will be re-fetched automatically.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    if isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .disabled(isExporting || isImporting)
            } header: {
                Text("Import")
            } footer: {
                Text("Restores data from a previously exported JSON file. Existing records are kept; duplicates are skipped.")
            }

            Section {
                Button(role: .destructive) {
                    showPurgeConfirmation = true
                } label: {
                    if isPurging {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Purge All Data", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .disabled(isExporting || isImporting || isPurging)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Permanently removes all data from this device, including your organizations, teams, members, and all synced GitHub data. This cannot be undone.")
            }
        }
        .navigationTitle("Data Management")
        .confirmationDialog(
            "Purge All Data?",
            isPresented: $showPurgeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Purge All Data", role: .destructive) {
                purgeData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete everything from this device. This cannot be undone.")
        }
        .sheet(item: $exportURL) { identifiable in
            ActivityView(activityItems: [identifiable.url])
                .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Data Management", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Helpers

    private func exportData() {
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let service = DataExportService()
                let data = try service.exportData(from: context)
                let filename = "focus-export-\(formattedDate()).json"
                let url = FileManager.default.temporaryDirectory.appending(path: filename)
                try data.write(to: url)
                exportURL = IdentifiableURL(url: url)
            } catch {
                alertMessage = "Export failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = "Could not access the selected file."
                    showAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                let service = DataExportService()
                try service.importData(from: data, into: context)
                alertMessage = "Import completed successfully."
                showAlert = true
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func purgeData() {
        isPurging = true
        Task { @MainActor in
            defer { isPurging = false }
            do {
                let service = DataExportService()
                try service.purgeAllData(from: context)
                alertMessage = "All data has been purged."
                showAlert = true
            } catch {
                alertMessage = "Purge failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}

// MARK: - IdentifiableURL

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ActivityView

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
