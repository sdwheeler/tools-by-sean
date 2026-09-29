

:r0:vnotee::
(
Status
======

To do
======

Done
====

Git
====

Contacts
========

Details
=======
)

:r0:dnotee::
{
global

Time := FormatTime(, "yyyy-MM-dd")
Send(Time)
Send("{Space}| Sprint")
return
}

:r0:rnotee::
(
====================================================
                    To do
====================================================

Tasks
------
1.
2.
3.


Public PRs
-----------
1.
2.
3.


Git Issues
----------
1.
2.
3.


====================================================
                   Done
====================================================

Tasks
------

Public PRs
-----------

Git Issues
----------
)


:r0:ishnew::
(
Thanks for contacting Microsoft with feedback about our product documentation. Depending on the complexity, it could take from a few business days to a few weeks to look further into your question, issue, or suggestion. We'll contact you if we need further information, and you'll receive an email message each time we "@mention" you in a comment. 

If you're suggesting a simple change to the documentation, it might be faster to submit the suggestion yourself by creating a GitHub pull request (PR). Here's how:

1. On the page you have feedback about, select the **Edit** link at the top right.
1. On the next page, select the **Pencil** icon at the top right.
1. On the next page, in the **Edit file** text window, make your edits directly to the text you want to change.
    If you need help with formatting the new or changed text, see our [Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet).
1. After you've made your edits, under **Commit changes**:
    a. In the first text box, enter a brief description of the change you've made.
    b. In the **Add an optional extended description** box, paste the link to your GitHub issue.
1. Select **Propose file change**.
1. On the **Comparing changes** page, select **Create pull request**.	
1. On the **Open a pull request** page, select **Create pull request**. 
    
Allow a day or more for the article's author to review and approve your change or offer an alternative solution.
    
By opening a pull request, you're helping the author add your approved change directly to the documentation. After the updated article is published, GitHub lists you as an article contributor.

If your issue is more complex than a simple change in the documentation, that's okay.  We'll continue to research your suggestion and then get back to you with our response.

Thanks again for submitting your feedback. Your suggestions help improve our documentation.
)

:r0:ishport::
(
Thanks for contacting Microsoft about your issue. As we understand it, you're describing a problem with the product itself and not with the product documentation. 

To get assistance or support for your product issue, we recommend that you engage with the product community or open a ticket with Microsoft Support. For more information, see __________________.

To provide product suggestions or ideas for improvement, go to ___________.

If you're submitting feedback about the product documentation, please reply to this comment to clarify your issue further. Otherwise, we'll proceed with closing out this Git issue within a few business days.

We're sorry that the _________ Docs team was unable to assist you further with your issue, but we appreciate your reaching out to us. If you experience other issues in the future, we encourage you to contact us again.
)

:r0:ishclose::
(
Thanks again for contacting Microsoft. We've submitted a documentation change based on your suggestion, and the updated article should be live by tomorrow. Please let us know if there�s anything more we can do for you. To follow up on this issue, leave us a comment with an @mention.
)

:r0:azprpr::
{
global
(
It may be faster for you to edit the content yourself via a Pull Request (PR). To do so, please do the following:

1. Navigate to the page of interest
2. Select  "Edit" button at the top right
3. Modify the URL so that 'azure-docs' becomes 'azure-docs-pr' 
5. Press enter to navigate to the newly-changed URL and reload the page
6. Select the pencil to edit the document
7. Modify the text within the text box in markdown format - more info: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet 
8. Scroll down to the bottom, name your file change, and select "Propose file change" 
9. Select "Create pull request" on the 'Open a pull request' page
10. Once the build finishes (should take about 5-10 minutes), review your changes by clicking the "View" link within the PR
11. Once you're satisfied with your changes, type @_________ in the comments so that I can review and sign off to approve the changes

If you're getting a 404, you may need to link your Github account to Microsoft, and join the MicrosoftDocs organization. More information can be found here: https://review.docs.microsoft.com/en-us/help/contribute/contribute-get-started-setup-github?branch=master

Feel free to ping me directly on Teams or over email if you run into any issues. 
)
}

:r0:sqlprpr::
{
global
(
It may be faster for you to edit the content yourself via a Pull Request (PR). To do so, please do the following:

1. Navigate to the page of interest
2. Select the "Edit" button at the top right
3. Modify the URL so that 'sql-docs' becomes 'sql-docs-pr' and 'live' becomes 'master'
4. Press enter to navigate to the newly-changed URL and reload the page
5. Select the pencil to edit the document
6. Modify the text within the text box in markdown format - more info: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet 
7. Scroll down to the bottom, name your file change, and select "Propose file change" 
8. Select "Create pull request" on the 'Open a pull request' page
9. Once the build finishes (should take about 5-10 minutes), review your changes by clicking the "View" link within the PR
10. Once you're satisfied with your changes, type @________ in the comments so that I can review and sign off to approve the changes

If you're getting a 404, you may need to link your Github account to Microsoft, and join the MicrosoftDocs organization. More information can be found here: https://review.docs.microsoft.com/en-us/help/contribute/contribute-get-started-setup-github?branch=master

Feel free to ping me directly on Teams or over email if you run into any issues. 
)


:r0:pubprpr::
(
It may be faster for you to edit the content yourself via a Pull Request (PR). To do so, please do the following:

1. Navigate to the page of interest
2. Select the "Edit" button at the top right of the page
3. Select the "Pencil" icon on the right
4. Modify the text within the text box in markdown format - more info: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet 
5. Name your file change and provide a description, if necessary
6. Select "Propose file change" 
7. Select "Create pull request" on the 'Comparing changes' page
8. Select "Create pull request" on the 'Open a pull request' page
9. Feel free to type @_____  in the comments so I can review the change as well, if I'm not the author of the page

Feel free to ping me directly on Teams or over email if you run into any issues. 
)
}

:r0:datep0::
{
  global
  Date := A_Now
  nDate := FormatTime(Date, "MM/dd")
  Send(nDate)
Return 
}

:r0:datep2::
{
  global
  Date := A_Now
  Date := DateAdd((Date != "" ? Date : A_Now), 2, 'Days')
  nDate := FormatTime(Date, "MM/dd")
  Send(nDate)
Return
}