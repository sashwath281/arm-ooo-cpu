vlib work
vlog -sv rtl/ooo/*.sv rtl/core/PC.sv rtl/core/Control.sv rtl/core/signextend.sv rtl/core/shiftLeft.sv rtl/common/*.sv rtl/bp/*.sv rtl/cache/*.sv rtl/memory/mem_backend.sv tb/integration/ooo_testbench.sv
vsim work.ooo_tb -voptargs=+acc
do sim/scripts/wave.do
run 10us