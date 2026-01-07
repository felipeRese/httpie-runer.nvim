if exists("b:current_syntax")
  finish
endif

syn match httpieRunnerPrompt "^$ .*$" contains=httpieRunnerHttpMethod
syn match httpieRunnerHttpMethod "^$ \zs\%(GET\|HEAD\|POST\|PUT\|PATCH\|DELETE\|OPTIONS\|TRACE\|CONNECT\|LINK\|UNLINK\|PURGE\)\>" contained
syn match httpieRunnerHttpStatus "^HTTP/\d\+\.\d\+\s\+\d\{3}.*$" contains=httpieRunnerStatusCode
syn match httpieRunnerStatusCode "\d\{3}" contained

syn region httpieRunnerHeader start="^\s*[A-Za-z0-9-]\+\s*:" end="$" contains=httpieRunnerHeaderName,httpieRunnerHeaderValue
syn match httpieRunnerHeaderName "^\s*\zs[A-Za-z0-9-]\+\ze\s*:" contained
syn match httpieRunnerHeaderValue ":\s*\zs.*$" contained

syn match httpieRunnerStderr "^\[stderr\].*$"
syn match httpieRunnerExit "^\[exit\s\+\d\+\]$"

syn match httpieRunnerJsonKey +"\zs\([^"\\]\|\\.\)*\ze"\s*:+
syn match httpieRunnerJsonString +"\([^"\\]\|\\.\)*"+ contains=httpieRunnerJsonEscape
syn match httpieRunnerJsonEscape +\\["\\/bfnrtu]+ contained
syn match httpieRunnerJsonNumber "\<-\=\d\+\(\.\d\+\)\=\([eE][+-]\=\d\+\)\=\>"
syn keyword httpieRunnerJsonBoolean true false null

hi def link httpieRunnerPrompt Comment
hi def link httpieRunnerHttpMethod Statement
hi def link httpieRunnerHttpStatus Type
hi def link httpieRunnerStatusCode Number
hi def link httpieRunnerHeaderName Identifier
hi def link httpieRunnerHeaderValue String
hi def link httpieRunnerStderr WarningMsg
hi def link httpieRunnerExit Comment
hi def link httpieRunnerJsonKey Type
hi def link httpieRunnerJsonString String
hi def link httpieRunnerJsonEscape Special
hi def link httpieRunnerJsonNumber Number
hi def link httpieRunnerJsonBoolean Boolean

let b:current_syntax = "httpie-runner"
