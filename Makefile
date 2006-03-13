PREFIX = /usr/local

LIBOBJS = hugeutils.o elflink.o morecore.o debug.o
INSTALL_OBJ_LIBS = libhugetlbfs.so libhugetlbfs.a
LDSCRIPT_TYPES = B BDT
INSTALL_OBJSCRIPT = ld.hugetlbfs

INSTALL = install

CFLAGS = -O2 -Wall -fPIC -g
CPPFLAGS = -D__LIBHUGETLBFS__

ARCH = $(shell uname -m | sed -e s/i.86/i386/)

ifeq ($(ARCH),ppc64)
CC32 = gcc
CC64 = gcc -m64
ELF32 = elf32ppclinux
ELF64 = elf64ppc
LIB32 = lib
LIB64 = lib64
else
ifeq ($(ARCH),ppc)
CC32 = gcc
ELF32 = elf32ppclinux
LIB32 = lib
else
ifeq ($(ARCH),i386)
CC32 = gcc
ELF32 = elf_i386
LIB32 = lib
else
ifeq ($(ARCH),x86_64)
CC32 = gcc -m32
CC64 = gcc -m64
ELF32 = elf_i386
ELF64 = elf_x86_64
LIB32 = lib32
LIB64 = lib
endif
endif
endif
endif

ifdef CC32
OBJDIRS += obj32
endif
ifdef CC64
OBJDIRS +=  obj64
endif

LIBDIR32 = $(PREFIX)/$(LIB32)
LIBDIR64 = $(PREFIX)/$(LIB64)
LDSCRIPTDIR = $(PREFIX)/lib/ldscripts
BINDIR = $(PREFIX)/bin

INSTALL_LDSCRIPTS = $(foreach type,$(LDSCRIPT_TYPES),$(ELF32).x$(type))
ifdef CC64
INSTALL_LDSCRIPTS += $(foreach type,$(LDSCRIPT_TYPES),$(ELF64).x$(type))
endif


ifdef V
VECHO = :
else
VECHO = echo -e "\t"
.SILENT:
endif

DEPFILES = $(LIBOBJS:%.o=%.d)

all:	libs tests

.PHONY:	tests libs

libs:	$(foreach file,$(INSTALL_OBJ_LIBS),$(OBJDIRS:%=%/$(file)))

tests:	libs	# Force make to build the library first
tests:	tests/all

tests/%:
	$(MAKE) -C tests OBJDIRS="$(OBJDIRS)" CC32="$(CC32)" CC64="$(CC64)" ELF32="$(ELF32)" ELF64="$(ELF64)" $*

check:	all
	./run_tests.sh

checkv:	all
	./run_tests.sh -vV

func:	all
	./run_tests.sh -t func

funcv:	all
	./run_tests.sh -t func -vV

stress:	all
	./run_tests.sh -t stress

stressv: all
	./run_tests.sh -t stress -vV

# Don't want to remake objects just 'cos the directory timestamp changes
$(OBJDIRS): %:
	@mkdir -p $@


.SECONDARY:

obj32/%.o: %.c
	@$(VECHO) CC32 $@
	@mkdir -p obj32
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

obj64/%.o: %.c
	@$(VECHO) CC64 $@
	@mkdir -p obj64
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

%/libhugetlbfs.a: $(foreach OBJ,$(LIBOBJS),%/$(OBJ))
	@$(VECHO) AR $@
	$(AR) $(ARFLAGS) $@ $^

obj32/libhugetlbfs.so: $(LIBOBJS:%=obj32/%)
	@$(VECHO) LD32 "(shared)" $@
	$(CC32) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

obj64/libhugetlbfs.so: $(LIBOBJS:%=obj64/%)
	@$(VECHO) LD64 "(shared)" $@
	$(CC64) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

obj32/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC32) $(CPPFLAGS) -E $< > $@

obj64/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC64) $(CPPFLAGS) -E $< > $@

obj32/%.s:	%.c
	@$(VECHO) CC32 -S $@
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

obj64/%.s:	%.c
	@$(VECHO) CC32 -S $@
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

clean:
	@$(VECHO) CLEAN
	rm -f *~ *.o *.so *.a *.d *.i core a.out
	rm -rf obj*
	rm -f ldscripts/*~
	$(MAKE) -C tests clean

%.d: %.c
	@$(CC) $(CPPFLAGS) -MM -MT "$(foreach DIR,$(OBJDIRS),$(DIR)/$*.o) $@" $< > $@

-include $(DEPFILES)

obj32/install:
	@$(VECHO) INSTALL32 $(LIBDIR32)
	$(INSTALL) -d $(LIBDIR32)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj32/%) $(LIBDIR32)

obj64/install:
	@$(VECHO) INSTALL64 $(LIBDIR64)
	$(INSTALL) -d $(LIBDIR64)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj64/%) $(LIBDIR64)

objscript.%: %
	@$(VECHO) OBJSCRIPT $*
	sed "s!### SET DEFAULT LDSCRIPT PATH HERE ###!HUGETLB_LDSCRIPT_PATH=$(LDSCRIPTDIR)!" < $< > $@

install: all $(OBJDIRS:%=%/install) $(INSTALL_OBJSCRIPT:%=objscript.%)
	@$(VECHO) INSTALL
	$(INSTALL) -d $(LDSCRIPTDIR)
	$(INSTALL) $(INSTALL_LDSCRIPTS:%=ldscripts/%) $(LDSCRIPTDIR)
	$(INSTALL) -d $(BINDIR)
	for x in $(INSTALL_OBJSCRIPT); do $(INSTALL) -m 755 objscript.$$x $(BINDIR)/$$x; done
