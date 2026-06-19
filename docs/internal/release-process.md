# Release Process Guide

This guide is meant to explain the flow and rules of the release process, i.e. the period when we cut a release branch off the master branch in anticipation of releasing it to users. Release Candidates (RC) are provided to test the Release.

## Before the release process

1. Close all the must have issues of the milestone.
   1. The release process **must never** be started if must have issues still exist.
   2. Either postpone the release or de-scope the must have issues.
2. Disable feature flags of any features that didn't get completed.
   1. See the [Cross-Team Epic Delivery Workflow](epic-delivery-workflow.md) document for the definition of a completed feature.
3. Define a priority matrix prior to the testing day.
   1. This matrix should explain what constitutes a Must have, Should have and Could have bug for the release.
   2. Keep in mind that only the must have issues **should** be worked on during the release process, all others **should** be moved to the next milestone.
4. One or more testing days **should** be done by the entire Status team to find any regressions before cutting.
   1. The Status team **should** split in testing groups to help test features.
   2. Testing groups **should** contain people from different teams to spread the knowledge.
   3. Testing days **should** happen on days where most of the team is available.
   4. Testing days **must** use a list of current features to test.
   5. The list **should** include a column listing issues found and by whom.
   6. The list **should** include an indicator whether that feature is covered by end-to-end (e2e) test and/or functional tests.
   7. The list **should** contain a section documenting which features were recently **added** or **refactored**.
   8. The recently added or refactored features **should** be the most tested.
   9. Features on the list **can** be tested by multiple testing groups.
   10. Testing days **can** happen during the release process too.

## During the release process

1. A release branch **must** be created at the start of the Release Process for the [Status App](https://github.com/status-im/status-app)'s master branch and [status-go](https://github.com/status-im/status-go)'s develop branch
   1. The format for the status-app branch is `release/MAJOR.MINOR.x`, eg. `release/2.36.x`
   2. The format for the status-go branch is automatically done using the Release script. Ask a status-go maintainer to create it.
   3. The status-app release branch **must** always point to the status-go release branch.
2. The first RC of the release branch **should** be sent to the Apple App Store immediately
   1. This ensures that any question from the Apple review team can be answered and addressed as soon as possible
   2. Once the release is ready, the final build will be sent to the App Store and **should** pass easily
3. All remaining issues from the milestone should be moved to the next milestone.
   1. Issues needing to be fixed on the RC will be added to the current milestone.
   
4. Only bug fixes **must** be provided to the release branch.
   
5. Moreover, only **critical** bug fixes **should** be added to the current milestone and committed to the release branch.
   1. Critical bugs are issues that affect:
      1. security
      2. potential data or funds loss
      3. crashes
      4. full regressions

6. Regressions **should** be mentioned to the QA team so that they can plan and implement e2e tests to prevent further regressions of this sort (to be implemented on master).
   1. Use the `needs-autotests` label on the issue to flag it.

7. Code coverage does **not** need to be met on the release branch.

8.  Features **must not** be allowed to be added to the release branch under any circumstances.

9.  Fixes for issues identified during the RC phase **must** be worked on and committed on the release branch **first**.

10. A new RC build **can** be triggered every day, if there are new fixes in the release branch.

11. Releases and RCs **must** have unique semantic numbers in the `VERSION` file and `tag`.
    1.  Release format: `2.36.0`
    2.  RC format: `2.36.0-rc.1`

12. The commit updating the `VERSION` file **must** have a `tag` matching the same version number on it.

13. The release branch **must** be rebased on top of the master branch each time a new RC is cut
    1.  This ensures that the master branch stays up to date with the release branch
    2.  It also lowers the amount of effort needed by devs, as no one needs to cherry-pick


## Frequently asked questions

### When is a release ready to be cut?

A release is considered ready to be cut when all **Key** features are **Done** and when all the must have issues are closed.

A **Key** feature is a feature identified on the [Roadmap](https://github.com/status-im/status-app/blob/master/docs/roadmap.md) as the most important features for that release.

A feature is considered **Done** when all issues of its Epic are closed. An Epic **must** include a testing issue, where one of the dev who worked on the issue meets with one of the designers and/or the Product Manager to demo the issue. Designers and/or the PM **should** open any issue they find on the new feature. Refer to the [Epic Delivery Workflow guide](/docs/internal/epic-delivery-workflow.md) for the full rundown.

#### What happens to the other features not ready at the time of the release cut?

The remaining features listed on the [Roadmap](https://github.com/status-im/status-app/blob/master/docs/roadmap.md) on the same milestone, but that were not identified as **key**, will simply be pushed to the next milestone.

All new features **must** implement a **feature flag**. Therefore, unfinished features **must not** affect negatively the master and release branches.

### Why commit to the release branch first and not master?

1. It is faster for the release.
2. Less possibilities of conflicts on the release branch.
3. Cherry-picked commits are often **not** tested. That is acceptable on master, but **unacceptable** on the release branch.
4. Issues do **not** close as completed when merged on the release branch. Therefore, it is easy to spot that the commit needs to be cherry-picked to master.

