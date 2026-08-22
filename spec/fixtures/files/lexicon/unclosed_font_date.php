<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>test person unclosed font</title>
</head>
<body dir="rtl">
<table border="0" width="100%">
  <tr>
    <td><p align="center"><font size="5" color="#FF0000">ישראלי, ישראל</font><font size="4" color="#FF0000">(1920-2000)</font></p></td>
  </tr>
</table>
<p>פרטים ביוגרפיים.</p>
<!-- this <font size="2"> is never closed, so everything below it, including the footer,
     ends up nested inside it once the document is parsed -->
<font size="2">
<p>הערה ראשונה על אודות המחבר.</p>
<p>הערה שנייה, בשורה נפרדת, שאינה חלק מתאריך העדכון.</p>
<font size="4" color="#0000FF"><a name="links">קישורים:</a></font>
<ul style="MARGIN-TOP: 0in" type="circle">
</ul>
<hr>עודכן לאחרונה: 2 בספטמבר 2020
</body>
</html>
