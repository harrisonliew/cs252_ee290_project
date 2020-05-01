prefix		:= /usr/local
abs_top_srcdir	:= /home/aa/users/harrisonliew/ee290c-2/cs252_ee290_project/generators/HD_sensor_fusion/software/build/..
XLEN            := 64
RISCVTOOLS      := @RISCVTOOLS@
ROCC = examples

.PHONY: all clean pulp
all: pulp

vars = \
	abs_top_srcdir=$(abs_top_srcdir) \
	XLEN=$(XLEN) \
	PREFIX=$(ROCC)-$@ \
	src_dir=$(abs_top_srcdir)/$@ \
	RISCVTOOLS=$(RISCVTOOLS)

pulp:
	mkdir -p $@
	$(MAKE) -C $@ -f $(abs_top_srcdir)/$@/Makefile $(vars)

clean:
	$(MAKE) -C pulp -f $(abs_top_srcdir)/pulp/Makefile abs_top_srcdir=$(abs_top_srcdir) PREFIX=$(ROCC)-pulp clean
