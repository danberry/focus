import Foundation

// MARK: - MailtoComposer

enum MailtoComposer {

    // MARK: - Types

    struct EmailDraft: Sendable {
        let recipients: [String]
        let subject: String
        let body: String
    }

    // MARK: - URL Building

    /// Builds a `mailto:` URL for the given draft.
    /// Returns `nil` if there are no recipients or URL construction fails.
    static func url(for draft: EmailDraft) -> URL? {
        guard !draft.recipients.isEmpty else { return nil }
        let to = draft.recipients.joined(separator: ",")
        guard var components = URLComponents(string: "mailto:\(to)") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        return components.url
    }

    // MARK: - Draft Factory

    /// Builds a pre-composed email draft for a Dependabot alert notification.
    static func draft(
        for alert: DependabotAlert,
        repository: SavedRepository,
        recipients: [String]
    ) -> EmailDraft {
        let subject = "[Security] Dependabot alert: \(alert.packageName) (\(alert.severity)) in \(repository.displayName)"
        let body = emailBody(for: alert, repository: repository)
        return EmailDraft(recipients: recipients, subject: subject, body: body)
    }

    // MARK: - Private

    private static func emailBody(for alert: DependabotAlert, repository: SavedRepository) -> String {
        """
        A Dependabot security alert requires your attention.

        Repository: \(repository.owner)/\(repository.name)
        Package:    \(alert.packageName) (\(alert.ecosystem))
        Severity:   \(alert.severity.uppercased())
        GHSA ID:    \(alert.ghsaId)
        CVE:        \(alert.cveId ?? "N/A")
        Summary:    \(alert.summary)

        Affected manifest: \(alert.manifestPath ?? "unknown")
        Vulnerable range:  \(alert.vulnerableVersionRange)
        Fix available in:  \(alert.fixVersion ?? "No fix available")

        View on GitHub: \(alert.htmlUrl)
        """
    }
}
