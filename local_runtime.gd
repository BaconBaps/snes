extends RefCounted

static func app_path(relative_path: String) -> String:
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join(relative_path)
	return ProjectSettings.globalize_path("res://" + relative_path)

static func python_executable() -> String:
	var override := OS.get_environment("BEDROOM_ARCADE_PYTHON")
	if not override.is_empty():
		return override
	if OS.get_name() == "Windows":
		var bundled := app_path("runtime/python.exe")
		return bundled if FileAccess.file_exists(bundled) else "python"
	return "python3"
