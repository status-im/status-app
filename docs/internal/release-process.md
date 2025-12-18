# Release Process Guide

This guide is meant to explain the flow and rules of the release process, ie the period when we cut a release branch off the master branch in prevision of releasing it to users. Release Candidates (RC) are provided to test the Release.

1. A release branch **must** be created at the start of the Release Process for the [Status App](https://github.com/status-im/status-app)'s master branch and [status-go](https://github.com/status-im/status-go)'s develop branch
   1. The format for the status-app branch is `release/MAJOR.MINOR.x`, eg. `release/2.36.x`
   2. The format for the status-go branch is automatically done using the Release script. Ask a status-go maintainer to create it.
   3. The status-app release branch **must** always point to the status-go release branch.
   
2. Issues needing to be fixed on the RC **must** be added to the [Release Board](https://github.com/orgs/status-im/projects/97/views/1).
   
3. Only bug fixes **must** be provided to the release branch.
   
4. Moreover, only **critical** bug fixes **should** be added to the [Release Board](https://github.com/orgs/status-im/projects/97/views/1) and committed to the release branch.
   1. Critical bugs are issues that affect:
      1. security
      2. potential data or funds loss
      3. crashes
      4. full regressions
5. One or more Testing days **should** be done by the entire Status team to find any regressions.
   1. The Status team **should** split in testing groups to help test features.
   2. Testing groups **should** contain people from different teams to spread the knowledge.
   3. Testing days **must** use a list of current features to test.
   4. The list **should** include a column listing issues found and by whom.
   5. The list **should** include an indicator whether that feature is covered by end-to-end (e2e) test and/or functional tests.
   6. The list **should** contain a section documenting which features were recently **added** or **refactored**.
   7. The recently added or refactored features **should** be the most tested.
   8. Features on the list **can** be tested by multiple testing groups.

6. Regressions **should** be mentioned to the QA team so that they can plan and implement e2e tests to prevent further regressions of the sorts (to be implemented on master).

7. Code coverage does **not** need to be met on the release branch.

8.  Features **must not** be allowed to be added to the release branch under any circumstances.

9.  Fixes for issues identified during the RC phase **must** be worked on and committed on the release branch **first**.

10. Once a fix has been applied to the release branch, it **must** be ported to the master branch by the author of the commit.

11. A new RC build **can** be triggered every day, if there are new fixes in the release branch.
12. Releases and RCs **must** have unique semantic numbers in the `VERSION` file and `tag`.
    1.  Release format: `2.36.0`
    2.  RC format: `2.36.0-rc.1`
13. The commit updating the `VERSION` file **must** have a `tag` matching the same version number on it.


## Frequently asked questions

### When is a release ready to be cut?

A release is considered ready to be cut when all **Key** features are **Done**.

A **Key** feature is a feature identified on the [Roadmap](https://github.com/status-im/status-app/blob/master/docs/roadmap.md) as the most important features for that release.

A feature is considered **Done** when all issues of its Epic are closed. An Epic **must** include a testing issue, where one of the dev who worked on the issue meets with one of the designers and/or the Product Manager to demo the issue. Designers and/or the PM **should** open any issue they find on the new feature.

#### What happens to the other features not ready at the time of the release cut?

The remaining features listed on the [Roadmap](https://github.com/status-im/status-app/blob/master/docs/roadmap.md) on the same milestone, but that were not identified as **key**, will simply be pushed to the next milestone.

All new features **must** implement a **feature flag**. Therefore, unfinished features **must not** affect negatively the master and release branches.

### Why commit to the release branch first and not master?

1. It is faster for the release.
2. Less possibilities of conflicts on the release branch.
3. Cherry-picked commits are often **not** tested. That is acceptable on master, but **unacceptable** on the release branch.
4. Issues do **not** close as completed when merged on the release branch. Therefore, it is easy to spot that the commit needs to be cherry-picked to master.

