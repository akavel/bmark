local expat = require 'expat'

sample = [[
<?xml version="1"?>
<em>hello</em>
]]

require 'html_to_md'
print(html_to_md(sample))
