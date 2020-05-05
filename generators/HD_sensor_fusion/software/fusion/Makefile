include $(abs_top_srcdir)/Makefrag

tests = main spatial

tests_baremetal = $(tests:=-baremetal)
ifdef BAREMETAL_ONLY
	tests_linux =
else
	tests_linux = $(tests:=-linux)
endif

BENCH_COMMON = $(abs_top_srcdir)/esp-tests/benchmarks/common
FUSION_FUNCS = $(abs_top_srcdir)/fusion/fusion_funcs.c $(abs_top_srcdir)/fusion/associative_memory.c

CFLAGS := $(CFLAGS) \
	-DPREALLOCATE=1 \
	-DMULTITHREAD=1 \
	-mcmodel=medany \
	-std=gnu99 \
	-O2 \
	-ffast-math \
	-fno-common \
	-fno-builtin-printf \
	-march=rv64gc -Wa,-march=rv64gcxhwacha \
	-lm \
	-lgcc \
	-I$(abs_top_srcdir)/esp-tests \
	-I$(abs_top_srcdir)/esp-tests/env \
	-I$(abs_top_srcdir)/fusion \
	-I$(abs_top_srcdir) \
	-I$(BENCH_COMMON) \
	-DID_STRING=$(ID_STRING) \

CFLAGS_BAREMETAL := \
	$(CFLAGS) \
	-nostdlib \
	-nostartfiles \
	-static \
	-T $(BENCH_COMMON)/test.ld \
	-DBAREMETAL=1 \

all: $(tests_baremetal) $(tests_linux)

vpath %.c $(src_dir)

%-baremetal: %.c $(FUSION_FUNCS)
	$(CC_BAREMETAL) $^ $(LFLAGS) -o $@ $(CFLAGS_BAREMETAL)\
		$(wildcard $(BENCH_COMMON)/*.c) $(wildcard $(BENCH_COMMON)/*.S) $(LIBS)

%-linux: %.c $(FUSION_FUNCS)
	$(CC_LINUX) $^ $(LFLAGS) -o $@ $(CFLAGS)

junk += $(tests_baremetal) $(tests_linux)

