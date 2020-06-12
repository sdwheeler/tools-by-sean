# Feature Request - PowerShell Reference metadata validation

PlatyPS is dependent on metadata to build MAML and CAB artifacts from markdown files. There are two
types of YAML metadata included in the PowerShell reference markdown files.

- Frontmatter metadata - used by PlatyPS and OPS
- Parameter metadata - describes the attributes of a cmdlet parameter

For a future version of PlatyPS, we are thinking about adding cmdlet metadata to track aliases and
platform support.

This FR is only talking about the **Frontmatter** metadata.

## Current issues

PlatyPS cmdlets create the necessary metadata but authors can change it. PlatyPS does not update the
frontmatter metadata. So changes in a module do not update the metadata and errors introduced by a
writer are not validated for correctness.

## Features needed

- The OPS build system should validate PowerShell metadata and issue the appropriate suggestions,
  warnings, and errors to the PR during build.
- PlatyPS should provide the same kinds of validation so that content owners can do their own
  content validation during the writing process.
  - QUESTION: should the validation be created in both tools or created in PlatyPS and leveraged in
    OPS? PlatyPS could be the tool used by OPS to perform the validation step. PlatyPS could apply
    the rules and report the results to OPS. OPS could determine the severities, add the results to
    the build log, and add comments to the PR.
- Rules and severities should be configurable so that they are easy to update without code changes.

## TO DO

- Identify the metadata and which processes are depend on it
- Classify the metadata as required or optional
- Define validation rules and severities

