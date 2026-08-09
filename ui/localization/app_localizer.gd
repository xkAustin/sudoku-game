class_name AppLocalizer
extends RefCounted

static func resolve_language(selected: String, system_locale: String) -> String:
	if selected == "system":
		return "zh" if system_locale.begins_with("zh") else "en"
	return "en" if selected == "en" else "zh"

static func text(zh: String, en: String, selected: String, system_locale: String) -> String:
	return en if resolve_language(selected, system_locale) == "en" else zh
