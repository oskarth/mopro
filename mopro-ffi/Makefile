# XXX: Problem with x86 for wasmer cranelift (x86 support requires SSE2)
#TARGETS = x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim

# XXX: Simplify
# TARGETS = aarch64-apple-ios aarch64-apple-ios-sim
TARGETS = aarch64-apple-ios
BUILD_TYPES = debug release

all: $(BUILD_TYPES)

debug: $(TARGETS)
	for target in $(TARGETS); do \
		cargo build --target $$target; \
	done

release:
	for target in $(TARGETS); do \
		cargo build --release --target $$target; \
	done

.PHONY: all $(BUILD_TYPES) $(TARGETS)