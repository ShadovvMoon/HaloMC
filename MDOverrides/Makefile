all:
	clang halomd_overrides.m mach_override.c -o ../halomd_overrides.dylib -dynamiclib -m32 -init _halomd_overrides_init -framework Foundation -framework CoreServices -mmacosx-version-min=10.5