# threshold

A collection of scripts written to migrate Threshold content (Windows & System Center 2016) and
transform markdown content from the old publishing structure to the new structure.

1. threshold\runonce\migrate-media.ps1

    Run this script from the top most folder of your content hierarchy for your technology area. The
    script will scan the folder hierarchy and perform the following transformations on the content:

    - Scan for links to media files and copy the media files from the root media folder to media
    sub-folder under the current location.
    - Fix all links to media files to point to the new media location.
    - Fix all links to MD files within the content to point to their new location in the folder
    hierarchy.

    This assumes that the existing media folder is one-level above the current folder. This script
    is intended to be run only once per technology-level folder.

2. threshold\runonce\Replace-TokensInMdDocuments.ps1

    Replaces all 'token' references with with the token value.

3. threshold\runonce\update-toc.ps1

    Run this script from the root folder of the content repository where TOC.md exists. Point the
    script at the path for your topic. The script scans all of the files in the topic folder
    (recursively) and updates the TOC.md to point to the new location of the file. This assumes that
    the file name has not been changed from what appears in the TOC.md file.

4. threshold\make-renameMDFiles.ps1

    This script scans the current folder (recursively) for MD files and creates the CSV file. The
    CSV file has a column containing the new suggested name, the length of that name, and the full
    path to the existing file.

    The author then edits the CSV file to make any necessary adjustments to the new filename. Whole
    rows may be deleted if the original filename does not need to change. The column containing the
    length is there to aid the content owner in picking a name of the appropriate length based on
    the limitations or requirements of the publishing system.

    After the CSV file has been updated appropriately, the content owner then runs the
    process-renamefile.ps1 script to rename the files as defined in the CSV.

5. threshold\make-renameMediaFiles.ps1

    This script scans the current folder (recursively) for all non-MD files and creates the CSV file.
    The CSV file has a column containing the new suggested name, the length of that name, and the full
    path to the existing file.

    The author then edits the CSV file to make any necessary adjustments to the new filename. Whole
    rows can be deleted if the original filename does not need to change. The column containing the
    length is there to aid the content owner in picking a name of the appropriate length based on
    the limitations or requirements of the publishing system.

    Once the CSV file has been updated appropriately, the content owner then runs the
    process-renamefile.ps1 script to rename the files as defined in the CSV.

6. threshold\process-renamefile.ps1

    This script reads the CSV file created by the make-renameMDFiles.ps1 and make-renameMediaFiles.ps1
    scripts. For each row in the CSV file, the script renames the original file to the new name then
    scans the current folder (recursively) for all MD files containing a reference to the old name. The
    old name is replaced in the MD file with the new value. It does the same operation on the specified
    TOC.md file.

7. threshold\get-brokenlinks.ps1

    This script reads each MD file in the repo recursively looking for links to files. For each linked
    file it finds it checks to see if the URL to that file is correct. If it is not correct or not
    optimal relative to the current document the URL will be replaced with the optimal path. The new
    URL is displayed to the console. No changes are made to the existing MD files. This is a tool for
    reporting.

8. threshold\fix-brokenlinks.ps1

    This script reads each MD file in the repo recursively looking for links to files. For each linked
    file it finds it checks to see if the URL to that file is correct. If it is not correct or not
    optimal relative to the current document the URL will be replaced with the optimal path. The new
    URL is displayed to the console. The file is also updated with the new URL.
