vlib work
vlog -sv rtl/ooo/*.sv rtl/core/PC.sv rtl/core/Control.sv rtl/core/signextend.sv rtl/core/shiftLeft.sv rtl/common/*.sv rtl/bp/*.sv rtl/cache/*.sv rtl/memory/mem_backend.sv tb/integration/cpu_testbench.sv rtl/cache/dcache.sv rtl/memory/dmem_backend.sv 
vsim work.cpu_testbench -voptargs=+acc
do sim/scripts/wave.do
run 10us