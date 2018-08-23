# Managing the PowerShell-Docs repo

## Managing Issues

### Sources

- Direct input in GitHub
  - Community contributors
  - Internal contributors
  - Transcriptions of LiveFyre comments
- LiveFyre
  - Published SLA is 24 hours
  - Not meeting goal
  - Lots of noise - mix of rants, support questions, docs questions/issue reports, product feedback
  - Little to no participation from PM/Dev teams to respond
- Feedback via the Docs feedback form
  - Not enabled yet
  - SLA (proposed)
    - First ACK - 5 business days
    - Fix/change - none

### Labeling

- All labels have descriptions of purpose
- Labels added to be compatible with CXP processes in azure-docs repo
- Most labels are long-lived, meaning that they will be used without regard to project timelines,
  etc.
- Label Types
  - Area labels - Prefix = Area. Used to indicate what part of PowerShell the issue is discussing.
    Useful for feature owners to find issues for their feature.
  - Review labels - Prefix = Review. Used to indicate that we are waiting on a response from
    someone about a question posed in the issue.
  - Project labels - Prefix = Project. These are short-lived labels used to associate issues with a
    specific project effort. The project label should be deleted when the project is complete.
  - Priority labels - Prefix = Pri. Used to indicated the priority of the issue. The priority is
    subjective value assigned by the triage team based on a best guess at the priority and severity
    of the issue. This is an attempt to provide a filter for choosing what issues to work first.
  - Other labels - Prefix n/a. There are several other labels used for managing issue states. See
    the label description for appropriate usage. Also, see the section on Triage process for
    specific use cases.

### Triage process

The PowerShell docs team meets once per week to discuss any issues added since last meeting. An
issue is considered to have been triaged when labels have been assigned and/or and owner has been
assigned. This triage is considered to be the "first response acknowledgement" of the issue for the
purpose of measuring the SLA. PowerShell docs team members are encouraged to review the issues
daily and triage new issues as they arrive. The weekly triage meeting can then be used to discuss
the new issues in more detail, as needed.

Issues created directly in our repo using GitHub should be triaged and handled the same as issues
that are created by the documentation feedback control. These issues will lack a "Details" section.
If the issue contains insufficient information, assign it to the contributor and assign the
Review-Issue-Author label.

In general, we will use the guidance for managing issues that is described in the APEX Contributor
Guide Triaging GitHub issues article. The following items describe how our process differs from
this document.

- Misplaced product feedback
  - Reply to the issue per the guidance.
  - Use the issue mover tool to move the issue to the appropriate product repo.
- Support requests through feedback
  - If the support question is simple, answer it politely and close the issue.
  - If the question is more complicated, or the submitter replies with more questions, redirect
    them to forums and support channels.
  - Suggested text for redirecting to forums:

    ```
    This is not the right forum for these kind of questions. Try posting your
    question in a community support forum. For a list of community forums see:
    https://docs.microsoft.com/en-us/powershell/#pivot=main&panel=community
    ```

- Code of conduct violations
  - Follow the guidance in the contributor guide.
  - Each occurrence of this should be discussed in the weekly triage so we can decide on the need
    for further action.

## Managing Pull requests

### PR Review

#### Best practices

- The person submitting the PR should not be merge the PR without a peer review.

  Reviewer coverage
  - Bobby --> Sean
  - Sean --> David
  - David --> Bobby

- Assign the peer reviewer when the PR is submitted. Early assignment allows the reviewer to
  respond sooner with editorial remarks.
- Use comments to describe the nature of the change or the type of review being requested. Be sure
  to @mention the reviewer. For example, if the change is minor and you don't need a full technical
  review, explain this in a comment.

#### Process steps

1. Create PR
1. Assign peer reviewer
1. Incorporate review feedback
1. Review preview rendering
1. Add sign-off comment (include Acrolinx info)

### PR Merger process

- `staging` is the only branch that should ever be merged into `live`
- Merges from short-lived (working) branches should be squashed

### Merging a working branch into the `staging` branch

Checklist
- [ ] Is the PR Review complete
- [ ] Correct target branch for the change
- [ ] No merge conflicts
- [ ] All validation and build step pass
- [ ] Squash and merge

### Merging a working branch into a `release-` branch

Checklist
- [ ] Is the PR Review complete
- [ ] Correct target branch for the change
- [ ] No merge conflicts
- [ ] All validation and build step pass
- [ ] Squash and merge

### Merging `staging` into a `release-` branch

Checklist
- [ ] Is the PR Review complete
- [ ] Correct target branch for the change
- [ ] No merge conflicts
- [ ] All validation and build step pass
- [ ] Create a merge commit

### Merging a `release-` branch into `staging`

Checklist
- [ ] Is the PR Review complete
- [ ] Correct target branch for the change
- [ ] No merge conflicts
- [ ] All validation and build step pass
- [ ] Create a merge commit

### Merging `staging` into the `live` branch

Checklist
- [ ] Is the PR Review complete
- [ ] Correct target branch for the change
- [ ] No merge conflicts
- [ ] All validation and build step pass
- [ ] Create a merge commit
