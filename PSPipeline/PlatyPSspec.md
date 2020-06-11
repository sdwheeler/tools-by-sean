# PlatyPS 2.0 Update


## PlatyPS Schema

- Would like PlatyPS to add a line break after each Markdown block.
  - Example - Headers, Code blocks, Lists
  - Bug: Get-Help: Requires that the first line of text be immediately following Synopsis header.

## Title (H1)

- Would like to add to schema:
  - Display cmdlet alias based on platform
  - Could do as Yaml block with Windows: macOS: Linux: ?
  - Example:

```yaml
- aliases:
  windows: gci, dir, ls
  macOS: gci, dir
  linux: gci, dir
```

## Synopsis (H2)

- no changes

## Syntax (H2)

- no changes

### Parameter Set Name (H3)

- Parameter Sets - should be sorted starting with Default, then by Alpha
- Parameters - Should be sorted Positional, Required, then by Alpha

## Description (H2)

- No changes

## Examples (H2)

### Example (H3)

- Should require one code block at minimum per example
- Should not be restricted on elements or size

## Parameters (H2)

- Parameters Should be sorted Alpha - currently PlatyPS has a switch to force Alpha versus
  enumerated - but the default is off. Can we change the default to on?

### Parameter (H3)

- Yaml block should include:
  - Parameter Set Name
  - AcceptedValues - Should display enumerated values of parameter (like ValidateSet)
  - ConfirmImpact - Impact severity should be reflected and displayed to inform defaults for -Confirm

## Common Parameters/Workflow Parameters

- Should calculate path for link to About_CommonParameters instead of fwlink

## Inputs/Outputs

- Add cross reference link to the API reference for the input/output object type.
  - [xref link docs](https://review.docs.microsoft.com/en-us/help/contribute/links-how-to?branch=master#xref-cross-reference-links)

## Related links

- This list should use bullets
- PlatyPS would need to support bullets

- Should support Text (prose), not just links.

##############################################

## PlatyPS About_ Schema

- PlatyPS should process About_ topics
  - Should be rendered as plain text compatible with Get-Help.
  - Get-Help bug:Synopsis

## Title (H1)

- Title should be Sentence Case | About Topic
  - Title meta data 'about_<Topic>' should match the file basename.

## Short description (H2)

- Should be Sentence Case

## Long description (H2)

- Should be Sentence case
- Should allow multiple Long description subtopics
  - Should support subtopics at H3 or H2.

## See also (H2)

- This is required but may be empty
