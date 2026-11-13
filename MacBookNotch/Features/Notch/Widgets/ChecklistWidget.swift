import SwiftUI

/// Today's tasks, checked off with a click. New tasks are typed right in the notch.
struct ChecklistWidget: View {
    let checklist: ChecklistStore
    let model: NotchViewModel
    let focusPanel: () -> Void

    @State private var isAdding = false

    var body: some View {
        // Sized so the header and five rows fit exactly in the card.
        WidgetCard(padding: Theme.Spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer(minLength: 0)
                    if !checklist.items.isEmpty {
                        Text("\(checklist.completedCount)/\(checklist.items.count)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .accessibilityLabel("\(checklist.completedCount) of \(checklist.items.count) done")
                    }
                }
                .frame(height: 14)

                ForEach(checklist.items) { item in
                    ChecklistRow(item: item, checklist: checklist)
                }

                if isAdding {
                    NewTaskField(checklist: checklist, onDone: stopAdding)
                } else if checklist.canAdd {
                    Button(action: startAdding) {
                        HStack(spacing: Theme.Spacing.small - 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 14)
                            Text(checklist.items.isEmpty ? "Add a task for today" : "Add a task")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity, minHeight: ChecklistRow.height, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a task")
                }

                if checklist.items.isEmpty && !isAdding {
                    Text("Up to \(ChecklistStore.maximumItems) tasks. Checked ones clear the next day.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's checklist")
        .onAppear { checklist.clearTasksFinishedBeforeToday() }
    }

    private func startAdding() {
        model.hold(.editing)
        focusPanel()
        isAdding = true
    }

    private func stopAdding() {
        isAdding = false
        model.release(.editing)
    }
}

private struct ChecklistRow: View {
    static let height: CGFloat = 16

    let item: ChecklistItem
    let checklist: ChecklistStore

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.small - 2) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { checklist.toggle(item.id) }
            } label: {
                HStack(spacing: Theme.Spacing.small - 2) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.isDone ? Theme.Colors.positive : Theme.Colors.secondaryText)
                        .frame(width: 14)
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .strikethrough(item.isDone, color: Theme.Colors.tertiaryText)
                        .foregroundStyle(item.isDone ? Theme.Colors.tertiaryText : Theme.Colors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.title)
            .accessibilityLabel(item.title)
            .accessibilityValue(item.isDone ? "Done" : "Not done")
            .accessibilityHint("Toggles whether the task is done")
            .accessibilityAction(named: "Delete") { checklist.remove(item.id) }

            if isHovered {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { checklist.remove(item.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(width: 16, height: Self.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete task")
                .accessibilityHidden(true)
            }
        }
        .frame(height: Self.height)
        .onHover { isHovered = $0 }
    }
}

/// A one-line field for a new task. Return adds it and keeps the field open for the next; Escape or clicking away ends.
private struct NewTaskField: View {
    let checklist: ChecklistStore
    let onDone: () -> Void

    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.small - 2) {
            Image(systemName: "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.tertiaryText)
                .frame(width: 14)
                .accessibilityHidden(true)
            TextField("New task", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .focused($isFocused)
                .onSubmit(add)
                .onExitCommand(perform: onDone)
                .accessibilityLabel("New task")
        }
        .frame(height: ChecklistRow.height)
        .onChange(of: isFocused) { _, focused in
            if !focused { onDone() }
        }
        .task {
            // Give the panel a moment to become the key window before moving focus into it.
            try? await Task.sleep(for: .milliseconds(50))
            isFocused = true
        }
    }

    private func add() {
        withAnimation(.easeOut(duration: 0.15)) { _ = checklist.add(title) }
        title = ""
        if !checklist.canAdd || !isFocused { onDone() }
    }
}
