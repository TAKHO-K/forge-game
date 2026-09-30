-- QUEUE-ALL2 P2(ref 18): 말풍선(ui/kit/Bubble)을 누르면 도움말 백과사전(panels/Help)의 그 항목이 열리게 잇는다. 창은 처음 열 때 짓는다(여기서 짓지 않는다).
local Bubble = require(script.Parent.ui.kit.Bubble)

Bubble.setHelpOpener(function(categoryId, entryId)
	require(script.Parent.panels.Help).open(categoryId, entryId)
end)
