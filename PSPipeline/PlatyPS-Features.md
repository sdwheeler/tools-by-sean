PlatyPS Feature list
- v2.x features
  - Convert parsing to use markdig
  - Convert About_ Markdown to plain text
    - needed for downlevel support
- v3.0 features
  - Convert to new v3 schema(s)
  - Update New-YamlHelp to output new schema
    - fix existing output bugs
  - add validation of new schema to enable pester tests and local build validation
  - Convert About_ to MAML?
    - Would that work with Get-Help?
    - Should we do this if the intent is to move to Markdown help in console?
  - Update Get-Help to support new schema as necessary?

Notes

- Schema for About topics
  - Does not match requirements for Get-Help rendering (Synopsis not displayed)
  - Need a structured schema of About_ topics so that they can be transformed for different
    rendering scenarios (console, web, etc.)
  - Does not convert About*.md to text file format - using Pandoc for now but that has side effects
    on the output.
- Schema for cmdlet help - requirements
  - Parameters
    - Parameter order - positional followed by the rest alpha sort
      - Separate rendering for console vs. HTML
    - Reflect cmdlet Impact severity to inform defaults for -Confirm
    - Reflect wildcard support
    - List param set names with syntax and as metadata for parameter
      - Show required and named vs. positional per set-name
    - Reflect accepted values where possible - include in parameter metadata
  - Cmdlet
    - Show applies-to info (platform and PS version)
      - Currently supported in YAML front matter - should this be moved into a YAML block for the
        cmdlet within the document instead of in the front matter?
    - Show cmdlet aliases by platform - Example:

      ```yaml
          - aliases:
            win: gci, dir, ls
            macOS: gci, dir
            linux: gci, dir
      ```

OPS Rendering Issues

- Common Parameters missing
- Parameter set names not shown
- Module landing pages not rendering synopsis correctly

Help Cmdlets

- Get-Help does not display Synopsis correctly.
  - For About topics it is hard coded to choose Line #5 of the help file.
  - For cmdlets, Synopsis is blank if there is a blank line after "### SYNOPSIS" in Markdown
- Get-Help should more easily show more metadata
  - Parameter set name
  - Cmdlet aliases (for the current platform)
  - Parameter aliases
  - Applies-to info
  - Impact severity
- Update-Help may need to change

Unknown

- Need way to increment the version number of the CAB files
  - Could be automatic in every build
  - Could be scheduled
  - Could be a workflow step (scripted) done by the author
  - Need to figure out limits of version number fields
  - Need rules for when to increment major, minor, subminor, etc. (Semvar?)
