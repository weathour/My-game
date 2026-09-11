extends RefCounted

const NUMBER_COLOR := "#FFB84D"
const NUMBER_PATTERN := "([+-]?\\d+(?:\\.\\d+)?(?:\\s*[%％])?)"

static var _number_regex: RegEx = null


static func escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


static func highlight_numbers(text: String, color: String = NUMBER_COLOR) -> String:
	if text.is_empty():
		return text
	if _number_regex == null:
		_number_regex = RegEx.new()
		_number_regex.compile(NUMBER_PATTERN)
	var escaped := escape_bbcode(text)
	return _number_regex.sub(escaped, "[color=%s]$1[/color]" % color, true)
