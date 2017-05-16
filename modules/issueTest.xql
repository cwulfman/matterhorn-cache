xquery version "3.0";


import module namespace issue="http://cwulfman.io/matterhorn/issue" at "issue.xqm";

let $testIssue1 := "bmtnaap_1921-11_01"

return issue:issue($testIssue1)