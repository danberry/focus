import Foundation
import SwiftData

// MARK: - Export Payload

/// The top-level container for a Focus data export.
struct FocusExportPayload: Codable {
    var version: Int = 1
    var exportedAt: Date
    var organizations: [ExportedOrganization]
    var departments: [ExportedDepartment]
    var disciplines: [ExportedDiscipline]
    var jobTitles: [ExportedJobTitle]
    var teams: [ExportedTeam]
    var repositories: [ExportedRepository]
    var members: [ExportedMember]
}

struct ExportedOrganization: Codable {
    var id: String
    var githubId: String
    var login: String
    var name: String?
    var avatarUrl: String?
    var organizationDescription: String?
    var addedAt: Date
}

struct ExportedDepartment: Codable {
    var id: String
    var name: String
    var departmentDescription: String?
    var organizationId: String?
}

struct ExportedDiscipline: Codable {
    var id: String
    var name: String
    var tracksGitHubActivity: Bool
}

struct ExportedJobTitle: Codable {
    var id: String
    var name: String
    var disciplineId: String?
}

struct ExportedTeam: Codable {
    var id: String
    var name: String
    var teamDescription: String
    var departmentId: String?
    var organizationId: String?
}

struct ExportedRepository: Codable {
    var id: String
    var githubId: String
    var owner: String
    var name: String
    var displayName: String
    var primaryLanguage: String?
    var organizationLogin: String?
    var isInMaintenance: Bool
    var teamId: String?
}

struct ExportedMember: Codable {
    var id: String
    var name: String
    var githubId: Int?
    var githubLogin: String?
    var teamId: String?
    var jobTitleId: String?
    var managerId: String?
}

// MARK: - DataExportService

/// Exports and imports user-configured SwiftData records to/from a portable JSON file.
///
/// Only manually-configured entities are included (organizations, departments, disciplines,
/// job titles, teams, repositories, members). Synced data (alerts, contributions, snapshots)
/// is excluded because it is re-fetched from GitHub after a fresh install.
@MainActor
final class DataExportService {

    // MARK: - Export

    /// Fetches all user-configured entities from the context and encodes them as JSON data.
    func exportData(from context: ModelContext) throws -> Data {
        let orgs = try context.fetch(FetchDescriptor<SavedOrganization>())
        let departments = try context.fetch(FetchDescriptor<Department>())
        let disciplines = try context.fetch(FetchDescriptor<Discipline>())
        let jobTitles = try context.fetch(FetchDescriptor<JobTitle>())
        let teams = try context.fetch(FetchDescriptor<Team>())
        let repos = try context.fetch(FetchDescriptor<SavedRepository>())
        let members = try context.fetch(FetchDescriptor<Member>())

        // Assign a stable UUID to each model for this export run.
        // ObjectIdentifier gives a unique key per reference without relying on hashValue.
        var exportIds: [ObjectIdentifier: String] = [:]
        func exportId(_ model: some AnyObject) -> String {
            let key = ObjectIdentifier(model)
            if let existing = exportIds[key] { return existing }
            let id = UUID().uuidString
            exportIds[key] = id
            return id
        }

        let exportedOrgs = orgs.map { org in
            ExportedOrganization(
                id: exportId(org),
                githubId: org.githubId,
                login: org.login,
                name: org.name,
                avatarUrl: org.avatarUrl,
                organizationDescription: org.organizationDescription,
                addedAt: org.addedAt
            )
        }

        let exportedDepts = departments.map { dept in
            ExportedDepartment(
                id: exportId(dept),
                name: dept.name,
                departmentDescription: dept.departmentDescription,
                organizationId: dept.organization.map { exportId($0) }
            )
        }

        let exportedDisciplines = disciplines.map { disc in
            ExportedDiscipline(
                id: exportId(disc),
                name: disc.name,
                tracksGitHubActivity: disc.tracksGitHubActivity
            )
        }

        let exportedJobTitles = jobTitles.map { jt in
            ExportedJobTitle(
                id: exportId(jt),
                name: jt.name,
                disciplineId: jt.discipline.map { exportId($0) }
            )
        }

        let exportedTeams = teams.map { team in
            ExportedTeam(
                id: exportId(team),
                name: team.name,
                teamDescription: team.teamDescription,
                departmentId: team.department.map { exportId($0) },
                organizationId: team.organization.map { exportId($0) }
            )
        }

        let exportedRepos = repos.map { repo in
            ExportedRepository(
                id: exportId(repo),
                githubId: repo.githubId,
                owner: repo.owner,
                name: repo.name,
                displayName: repo.displayName,
                primaryLanguage: repo.primaryLanguage,
                organizationLogin: repo.organizationLogin,
                isInMaintenance: repo.isInMaintenance,
                teamId: repo.team.map { exportId($0) }
            )
        }

        let exportedMembers = members.map { member in
            ExportedMember(
                id: exportId(member),
                name: member.name,
                githubId: member.githubId,
                githubLogin: member.githubLogin,
                teamId: member.team.map { exportId($0) },
                jobTitleId: member.jobTitle.map { exportId($0) },
                managerId: member.manager.map { exportId($0) }
            )
        }

        let payload = FocusExportPayload(
            exportedAt: .now,
            organizations: exportedOrgs,
            departments: exportedDepts,
            disciplines: exportedDisciplines,
            jobTitles: exportedJobTitles,
            teams: exportedTeams,
            repositories: exportedRepos,
            members: exportedMembers
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    // MARK: - Import

    /// Decodes a JSON export file and inserts all entities into the context.
    ///
    /// Existing data is left in place; duplicate records (matched by `githubId` for
    /// orgs and repos, or by name for other entities) are skipped.
    func importData(from data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(FocusExportPayload.self, from: data)

        // Build lookup maps keyed by export ID so relationships can be resolved.
        var orgMap: [String: SavedOrganization] = [:]
        var deptMap: [String: Department] = [:]
        var disciplineMap: [String: Discipline] = [:]
        var jobTitleMap: [String: JobTitle] = [:]
        var teamMap: [String: Team] = [:]
        var repoMap: [String: SavedRepository] = [:]
        var memberMap: [String: Member] = [:]

        // Fetch existing records to detect duplicates.
        let existingOrgs = (try? context.fetch(FetchDescriptor<SavedOrganization>())) ?? []
        let existingRepos = (try? context.fetch(FetchDescriptor<SavedRepository>())) ?? []
        let existingDisciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        let existingJobTitles = (try? context.fetch(FetchDescriptor<JobTitle>())) ?? []
        let existingDepts = (try? context.fetch(FetchDescriptor<Department>())) ?? []
        let existingTeams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        let existingMembers = (try? context.fetch(FetchDescriptor<Member>())) ?? []

        // --- Disciplines ---
        let disciplinesByName = Dictionary(uniqueKeysWithValues: existingDisciplines.map { ($0.name, $0) })
        for exported in payload.disciplines {
            if let existing = disciplinesByName[exported.name] {
                disciplineMap[exported.id] = existing
            } else {
                let disc = Discipline(name: exported.name, tracksGitHubActivity: exported.tracksGitHubActivity)
                context.insert(disc)
                disciplineMap[exported.id] = disc
            }
        }

        // --- Job Titles ---
        let jobTitlesByName = Dictionary(uniqueKeysWithValues: existingJobTitles.map { ($0.name, $0) })
        for exported in payload.jobTitles {
            if let existing = jobTitlesByName[exported.name] {
                jobTitleMap[exported.id] = existing
            } else {
                let jt = JobTitle(name: exported.name)
                jt.discipline = exported.disciplineId.flatMap { disciplineMap[$0] }
                context.insert(jt)
                jobTitleMap[exported.id] = jt
            }
        }

        // --- Organizations ---
        let orgsByGithubId = Dictionary(uniqueKeysWithValues: existingOrgs.map { ($0.githubId, $0) })
        for exported in payload.organizations {
            if let existing = orgsByGithubId[exported.githubId] {
                orgMap[exported.id] = existing
            } else {
                let org = SavedOrganization(
                    githubId: exported.githubId,
                    login: exported.login,
                    name: exported.name,
                    avatarUrl: exported.avatarUrl,
                    organizationDescription: exported.organizationDescription
                )
                context.insert(org)
                orgMap[exported.id] = org
            }
        }

        // --- Departments ---
        let deptsByName = Dictionary(uniqueKeysWithValues: existingDepts.map { ($0.name, $0) })
        for exported in payload.departments {
            if let existing = deptsByName[exported.name] {
                deptMap[exported.id] = existing
            } else {
                let dept = Department(name: exported.name, departmentDescription: exported.departmentDescription)
                dept.organization = exported.organizationId.flatMap { orgMap[$0] }
                context.insert(dept)
                deptMap[exported.id] = dept
            }
        }

        // --- Teams ---
        let teamsByName = Dictionary(uniqueKeysWithValues: existingTeams.map { ($0.name, $0) })
        for exported in payload.teams {
            if let existing = teamsByName[exported.name] {
                teamMap[exported.id] = existing
            } else {
                let team = Team(name: exported.name, teamDescription: exported.teamDescription)
                team.department = exported.departmentId.flatMap { deptMap[$0] }
                team.organization = exported.organizationId.flatMap { orgMap[$0] }
                context.insert(team)
                teamMap[exported.id] = team
            }
        }

        // --- Repositories ---
        let reposByGithubId = Dictionary(uniqueKeysWithValues: existingRepos.map { ($0.githubId, $0) })
        for exported in payload.repositories {
            if let existing = reposByGithubId[exported.githubId] {
                repoMap[exported.id] = existing
            } else {
                let repo = SavedRepository(
                    githubId: exported.githubId,
                    owner: exported.owner,
                    name: exported.name,
                    displayName: exported.displayName,
                    primaryLanguage: exported.primaryLanguage
                )
                repo.organizationLogin = exported.organizationLogin
                repo.isInMaintenance = exported.isInMaintenance
                repo.team = exported.teamId.flatMap { teamMap[$0] }
                context.insert(repo)
                repoMap[exported.id] = repo
            }
        }

        // --- Members (first pass: insert without manager) ---
        let membersByName = Dictionary(uniqueKeysWithValues: existingMembers.map { ($0.name, $0) })
        for exported in payload.members {
            if let existing = membersByName[exported.name] {
                memberMap[exported.id] = existing
            } else {
                let member = Member(name: exported.name, githubId: exported.githubId, githubLogin: exported.githubLogin)
                member.team = exported.teamId.flatMap { teamMap[$0] }
                member.jobTitle = exported.jobTitleId.flatMap { jobTitleMap[$0] }
                context.insert(member)
                memberMap[exported.id] = member
            }
        }

        // --- Members (second pass: wire manager relationships) ---
        for exported in payload.members {
            guard let managerId = exported.managerId,
                  let member = memberMap[exported.id],
                  let manager = memberMap[managerId] else { continue }
            member.manager = manager
        }

        try context.save()
    }

    // MARK: - Purge

    /// Deletes every record from the store — both user-configured and synced data.
    func purgeAllData(from context: ModelContext) throws {
        try context.delete(model: Member.self)
        try context.delete(model: SavedRepository.self)
        try context.delete(model: Team.self)
        try context.delete(model: JobTitle.self)
        try context.delete(model: Discipline.self)
        try context.delete(model: Department.self)
        try context.delete(model: SavedOrganization.self)
        try context.delete(model: DependabotAlert.self)
        try context.delete(model: CodeScanningAlert.self)
        try context.delete(model: SecretScanningAlert.self)
        try context.delete(model: MemberContribution.self)
        try context.delete(model: DailyContribution.self)
        try context.delete(model: RepositoryVelocity.self)
        try context.delete(model: OpenPullRequest.self)
        try context.delete(model: PRWeeklySnapshot.self)
        try context.delete(model: SecurityWeeklySnapshot.self)
        try context.delete(model: Codeowner.self)
        try context.save()
    }
}
