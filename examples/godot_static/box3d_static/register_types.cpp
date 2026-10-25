#include "register_types.h"

#include "core/extension/gdextension_function_loader.h"
#include "core/extension/gdextension_manager.h"

extern "C" GDExtensionBool godot_box3d_main(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization);

void initialize_box3d_static_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SERVERS) {
		return;
	}

	Ref<GDExtensionFunctionLoader> loader;
	loader.instantiate();
	loader->set_initialization_function(godot_box3d_main);
	GDExtensionManager::LoadStatus status = GDExtensionManager::get_singleton()->load_extension_with_loader(
			"libgodot://box3d", loader);
	ERR_FAIL_COND_MSG(status != GDExtensionManager::LOAD_STATUS_OK, "Failed to register statically embedded Box3D.");
}

void uninitialize_box3d_static_module(ModuleInitializationLevel p_level) {
	// GDExtensionManager owns the extension and its shutdown callbacks.
}
