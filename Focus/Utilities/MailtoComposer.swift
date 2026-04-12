import Foundation

// MARK: - MailtoComposer

/// A namespace for composing `mailto:` URLs that pre-fill an email draft.
///
/// `MailtoComposer` builds RFC 2368-compliant `mailto:` URLs. Callers pass
/// the resulting URL to `UIApplication.shared.open(_:)` to hand off to the
/// device's default mail client.
///
/// ## URL structure
/// ```
/// mailto:<to1>,<to2>?subject=<subject>&body=<body>
/// ```
/// Recipients are encoded in the path component; `subject` and `body` are
/// percent-escaped as query items via `URLComponents`.
///
/// ## Pre-filled fields
/// | Field     | Source                                          |
/// | --------- | ----------------------------------------------- |
/// | `to`      | ``EmailDraft/recipients``, joined by comma      |
/// | `subject` | ``EmailDraft/subject``                          |
/// | `body`    | ``EmailDraft/body``                             |
enum MailtoComposer {

    // MARK: - EmailDraft

    /// A value type representing the pre-filled content of an outgoing email.
    struct EmailDraft: Sendable {

        /// The email addresses of the intended recipients.
        let recipients: [String]

        /// The pre-filled subject line for the email.
        let subject: String

        /// The pre-filled plain-text body for the email.
        ///
        /// `mailto:` does not support HTML; body content is always treated as plain text.
        let body: String
    }

    // MARK: - URL Building

    /// Builds a `mailto:` URL for the given draft.
    ///
    /// Recipients are joined with commas and placed in the `mailto:` path
    /// component. `subject` and `body` are percent-escaped and appended as
    /// query items by `URLComponents`.
    ///
    /// - Parameter draft: The email draft to encode as a `mailto:` URL.
    /// - Returns: A `mailto:` URL, or `nil` if the draft has no recipients or
    ///   `URLComponents` fails to construct a valid URL.
    static func url(for draft: EmailDraft) -> URL? {
        guard !draft.recipients.isEmpty else { return nil }
        // TODO: Validate each recipient as a well-formed email address — malformed
        //       addresses silently produce a URL that Mail rejects at open time.
        let to = draft.recipients.joined(separator: ",")
        // TODO: Enforce a maximum URL length — mailto: bodies can exceed the ~8 KB
        //       iOS URI limit, causing UIApplication.open to silently fail.
        guard var components = URLComponents(string: "mailto:\(to)") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        return components.url
    }

    // MARK: - Draft Factory

    // TODO: Add draft factories for code scanning and secret scanning alert types —
    //       currently only Dependabot alerts can be shared via email.

    /// Builds a pre-composed email draft for a Dependabot alert notification.
    ///
    /// The subject line follows the format:
    /// `[Security] Dependabot alert: <package> (<severity>) in <repo>`.
    /// The body is a fixed plain-text summary of the alert's key fields.
    ///
    /// - Parameters:
    ///   - alert: The Dependabot alert to summarize in the email.
    ///   - repository: The repository that owns the alert.
    ///   - recipients: The email addresses to pre-fill in the `to` field.
    /// - Returns: An ``EmailDraft`` ready to pass to ``url(for:)``.
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

    /// Builds the plain-text email body summarizing a Dependabot alert.
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
