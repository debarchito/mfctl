obj-m += minifuse_mod.o

# DKMS provides KERNELRELEASE. If not set, fallback to the currently running kernel.
KVER ?= $(if $(KERNELRELEASE),$(KERNELRELEASE),$(shell uname -r))
KDIR ?= /lib/modules/$(KVER)/build

# Check if the kernel was built using LLVM/Clang
IS_LLVM := $(shell test -f $(KDIR)/.config && grep -q "CONFIG_CC_IS_CLANG=y" $(KDIR)/.config && echo 1 || echo 0)

ifeq ($(IS_LLVM), 1)
	KBUILD_FLAGS := LLVM=1 CC=clang
else
	KBUILD_FLAGS :=
endif

all:
	$(MAKE) $(KBUILD_FLAGS) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) $(KBUILD_FLAGS) -C $(KDIR) M=$(PWD) clean
