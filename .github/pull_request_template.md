### What does the PR do

<!-- Fill in the relevant information below to help us evaluate your proposed changes. -->

### Affected areas

<!-- List the affected areas (e.g wallet, browser, etc..) -->

### Quality checklist

- [ ] I am familiar with the [application architecture](/docs/architecture.md) and agreed good practices.
My PR is consistent with this document: [QML Architecture Guidelines](/guidelines/QML_ARCHITECTURE_GUIDE.md)
- [ ] I have updated the necessary documentation if needed (eg: updated BUILDING.md if I updated dependencies)

### Copilot review guidance

When asking GitHub Copilot to review this PR, include:

- https://github.com/TheQtCompanyRnD/agent-skills/tree/main/skills/qt-qml
- https://github.com/TheQtCompanyRnD/agent-skills/tree/main/skills/qt-qml-review
- https://github.com/TheQtCompanyRnD/agent-skills/tree/main/skills/qt-ui-design
- https://github.com/TheQtCompanyRnD/agent-skills/tree/main/skills/qt-cpp-review

Also ask Copilot to align feedback with repository architecture boundaries:

- QML/StatusQ: presentation and interaction
- Nim (`src/`): orchestration, signals, module wiring
- `vendor/status-go`: backend logic, persistence, protocol, notifications

### Screencapture of the functionality

<!-- Gif/Video or screenshot that demonstrates the functionality, especially important if it's a bug fix. -->

### Impact on end user

<!-- What is the impact of these changes on the end user (before/after behaviour) -->

### How to test

<!-- How should one proceed with testing this PR. -->
<!-- What kind of user flows should be checked? -->

### Risk 

<!-- Described potential risks and worst case scenarios. -->
