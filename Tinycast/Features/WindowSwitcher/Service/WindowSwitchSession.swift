import AppKit

@MainActor
@Observable
final class WindowSwitchSession {
    private(set) var snapshot: [WindowSwitchEntry] = []
    /// The rows the list reads: ranked once per query change, so one keystroke ranks once.
    private(set) var filtered: [WindowSwitchEntry] = []
    private(set) var isDiscovering = false

    private var query = ""
    private var revision = 0
    /// Live AX handles, so they are never observed and never outlive the show.
    @ObservationIgnored private var elements: [UInt32: WindowSwitchSweep.Element] = [:]
    @ObservationIgnored private var remoteReferences: [UInt32: WindowSwitchSweep.RemoteReference] = [:]
    /// Held only while rows are shown, so an app that quits takes its rows with it.
    @ObservationIgnored private var terminationToken: NotificationCenter.ObservationToken?

    @discardableResult
    func present(_ snapshot: WindowSwitchSweep.Snapshot) -> Int {
        revision &+= 1
        isDiscovering = true
        self.snapshot = WindowSwitchOrder.sorted(snapshot.entries)
        elements = snapshot.elements
        remoteReferences = [:]
        observeTerminations()
        applyQuery()
        return revision
    }

    func merge(_ remote: WindowSwitchSweep.RemoteSnapshot, revision: Int) -> Bool {
        guard revision == self.revision else { return false }
        isDiscovering = false
        let existingIDs = Set(snapshot.map(\.windowID))
        for entry in remote.entries where !existingIDs.contains(entry.windowID) {
            if let reference = remote.references[entry.windowID] {
                remoteReferences[entry.windowID] = reference
            }
        }
        snapshot = WindowSwitchOrder.merging(snapshot, with: remote.entries)
        applyQuery()
        return true
    }

    func element(for windowID: UInt32) -> WindowSwitchSweep.Element? {
        if let element = elements[windowID] { return element }
        guard let reference = remoteReferences[windowID] else { return nil }
        let element = WindowSwitchSweep.element(for: reference)
        if let element { elements[windowID] = element }
        return element
    }

    func reset() {
        if let terminationToken {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationToken)
        }
        terminationToken = nil
        snapshot = []
        filtered = []
        isDiscovering = false
        elements = [:]
        remoteReferences = [:]
        revision &+= 1
        query = ""
    }

    func filter(_ query: String) {
        self.query = query
        applyQuery()
    }

    func markMinimized(_ windowID: UInt32) {
        guard let index = snapshot.firstIndex(where: { $0.windowID == windowID }) else { return }
        var entries = snapshot
        entries[index].isMinimized = true
        snapshot = WindowSwitchOrder.sorted(entries)
        applyQuery()
    }

    private func observeTerminations() {
        guard terminationToken == nil else { return }
        terminationToken = NSWorkspace.shared.notificationCenter.addObserver(
            of: NSWorkspace.shared, for: NSWorkspace.DidTerminateApplicationMessage.self
        ) { [weak self] in self?.removeWindows(of: $0.application.processIdentifier) }
    }

    private func removeWindows(of pid: pid_t) {
        let gone = Set(snapshot.compactMap { entry in
            (elements[entry.windowID]?.app.processIdentifier == pid
                || remoteReferences[entry.windowID]?.pid == pid) ? entry.windowID : nil
        })
        guard !gone.isEmpty else { return }
        for windowID in gone { elements[windowID] = nil }
        for windowID in gone { remoteReferences[windowID] = nil }
        snapshot.removeAll { gone.contains($0.windowID) }
        applyQuery()
    }

    private func applyQuery() {
        filtered = WindowSwitchQuery.rank(
            snapshot, for: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
