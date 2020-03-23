export CHIPYARD_TOOLCHAIN_SOURCED=1
export RISCV=/home/ff/ee290-2/ee290-2-esp-tools
export PATH=${RISCV}/bin:${PATH}
export LD_LIBRARY_PATH=${RISCV}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

source /home/ff/ee290-2/env-vcs.sh
