# Markdown examples

## Inserting special characters in Markdown

### Commonly used symbols

|         **Name**         | **Encoding** |      **Example**      |
| ------------------------ | ------------ | --------------------- |
| Registered Trademark     | `&reg;`      | Windows Server&reg;   |
| Trademark                | `&trade;`    | Azure Design&trade;   |
| Copyright                | `&copy;`     | &copy; 2016 Microsoft |
| Checkmark                | `&check;`    | &check;               |
| X-Mark (Multiplication)  | `&#x2715;`   | &#x2715;              |
| Smart left double quote  | `&ldquo;`    | &ldquo;               |
| Smart right double quote | `&rdquo;`    | &rdquo;               |
| Smart left single quote  | `&lsquo;`    | **&lsquo;**           |
| Smart right single quote | `&rsquo;`    | **&rsquo;**           |
| Horizontal ellipsis      | `&hellip;`   | &hellip;              |
| Euro                     | `&euro;`     | &euro;                |
| n-dash                   | `&ndash;`    | &ndash;               |
| m-dash                   | `&mdash;`    | &mdash;               |

### Resources

- [HTML Entity List](http://www.freeformatter.com/html-entities.html)
- [UTF-8 encoding table](http://www.utf8-chartable.de/)

***

## GFM Extensions

Checkboxes
- [ ] This is a checkbox in GFM
- [x] This is a checkbox in GFM

Single column table with no header

|   |
|---|
|single column table|
|single column table|
|single column table|

Multiline cell examples

|Operator|Description                                                  |
|--------|-------------------------------------------------------------|
|=       |Sets the value of a variable to the specified value.         |
|+=      |Increases the value of a variable by the specified value, or<br> appends the specified value to the existing value.|
|-=      |Decreases the value of a variable by the specified value.    |
|*=      |Multiplies the value of a variable by the specified value, or<br> appends the specified value to the existing value.|
|/=      |Divides the value of a variable by the specified value.      |
|%=      |Divides the value of a variable by the specified value and<br> then assigns the remainder (modulus) to the variable.|
|++      |Increases the value of a variable, assignable property, or<br> array element by 1.|
|--      |Decreases the value of a variable, assignable property, or<br> array element by 1.|

Run the following command to see how it renders as TXT.

```
pandoc -f markdown -t plain+multiline_tables+inline_code_attributes -o .\markdown-examples.txt --columns 75 --ascii .\markdown-examples.md
```