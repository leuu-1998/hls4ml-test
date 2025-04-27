# Function to log steps
proc log_step {message} {
    puts "=============================================="
    puts "STEP: $message"
    puts "=============================================="
}

# Version check
set vivado_version [version -short]
puts "Vivado version: $vivado_version"
if {[string first "2024.1" $vivado_version] == -1} {
    puts "WARNING: Script was tested with Vivado 2024.1, current version is $vivado_version"
}

# Enable verbose logging
set_msg_config -id {Common 17-41} -new_severity INFO

# Start logging
log_step "Creating new Vivado project"
set project_dir [file normalize "./mnist_fpga"]
create_project mnist_fpga $project_dir -part xc7z020clg400-1
set_property board_part xilinx.com:zc702:part0:1.4 [current_project]

log_step "Current working directory: [pwd]"

# Add the IP repository - Using absolute path for Windows
log_step "Setting IP Repository paths"
set ip_repo_path [file normalize "./hls4ml_mnist_vitis_prj/myproject_prj/solution1/impl/ip"]
puts "IP Repository path: $ip_repo_path"

# Verify IP repository path exists
if {![file exists "$ip_repo_path/component.xml"]} {
    error "ERROR: IP repository path not found or invalid at $ip_repo_path"
}

set_property ip_repo_paths $ip_repo_path [current_project]
update_ip_catalog -rebuild
puts "IP Repository updated successfully"

# Create block design
log_step "Creating block design"
create_bd_design "design_1"
puts "Block design created"

# Add Zynq PS
log_step "Adding Zynq Processing System"
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure PS: Enable HP0 port and FCLK0
log_step "Configuring PS settings"
set_property -dict [ list 
    CONFIG.PCW_USE_S_AXI_HP0 {1} 
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} 
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} 
    CONFIG.PCW_USE_M_AXI_GP0 {1} 
] [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
puts "Zynq PS added and configured"

# Add clock wizard
log_step "Adding Clock Management"
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list 
    CONFIG.PRIM_IN_FREQ {100.000} 
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} 
    CONFIG.USE_RESET {false} 
] [get_bd_cells clk_wiz_0]

# Connect PS clock to clock wizard
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins clk_wiz_0/clk_in1]

# Add AXI Reset modules for better reset management
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Add AXI DMA
log_step "Adding AXI DMA"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0

# Configure DMA
set_property -dict [ list 
    CONFIG.c_include_sg {0} 
    CONFIG.c_sg_include_stscntrl_strm {0} 
    CONFIG.c_sg_length_width {26} 
    CONFIG.c_mm2s_burst_size {16} 
    CONFIG.c_s2mm_burst_size {16} 
    CONFIG.c_m_axi_mm2s_data_width {32} 
    CONFIG.c_m_axi_s2mm_data_width {32} 
    CONFIG.c_m_axis_mm2s_tdata_width {32} 
    CONFIG.c_s_axis_s2mm_tdata_width {32} 
] [get_bd_cells axi_dma_0]
puts "AXI DMA added and configured"

# Add Neural Network IP
log_step "Adding Neural Network IP"
create_bd_cell -type ip -vlnv xilinx.com:hls:myproject:1.0 myproject_0

# Verify interfaces before connecting
log_step "Verifying IP Interfaces"
if {[llength [get_bd_intf_pins myproject_0/in_r]] == 0} {
    error "Neural Network IP missing in_r interface"
}
if {[llength [get_bd_intf_pins myproject_0/out_r]] == 0} {
    error "Neural Network IP missing out_r interface"
}

# Verify data widths
set nn_in_width [get_property CONFIG.C_S_AXIS_IN_R_TDATA_WIDTH [get_bd_cells myproject_0]]
set nn_out_width [get_property CONFIG.C_M_AXIS_OUT_R_TDATA_WIDTH [get_bd_cells myproject_0]]
puts "Neural Network input width: $nn_in_width"
puts "Neural Network output width: $nn_out_width"

# Add AXI Interconnect for HP0
log_step "Adding AXI Interconnect for HP0"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hp0
set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {2}] [get_bd_cells axi_interconnect_hp0]

# Add AXI Interconnect for Control
log_step "Adding AXI Interconnect for Control"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ctrl
set_property -dict [list CONFIG.NUM_MI {2} CONFIG.NUM_SI {1}] [get_bd_cells axi_interconnect_ctrl]

# Connect DMA to PS through HP0
log_step "Connecting DMA to PS"
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] -boundary_type upper [get_bd_intf_pins axi_interconnect_hp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] -boundary_type upper [get_bd_intf_pins axi_interconnect_hp0/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_hp0/M00_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Connect Neural Network to DMA
log_step "Connecting Neural Network to DMA"
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins myproject_0/in_r]
connect_bd_intf_net [get_bd_intf_pins myproject_0/out_r] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]


# Connect Control Interfaces
log_step "Connecting Control Interfaces"
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_interconnect_ctrl/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M01_AXI] [get_bd_intf_pins myproject_0/s_axi_control]

# Connect all clock and reset signals
log_step "Connecting Clocks and Resets"
set clk_out [get_bd_pins clk_wiz_0/clk_out1]
set sync_reset [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

# Clock connections
connect_bd_net $clk_out [get_bd_pins axi_interconnect_hp0/ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_hp0/S00_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_hp0/S01_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_hp0/M00_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_ctrl/ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_ctrl/S00_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_ctrl/M00_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_interconnect_ctrl/M01_ACLK]
connect_bd_net $clk_out [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net $clk_out [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net $clk_out [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net $clk_out [get_bd_pins myproject_0/ap_clk]
connect_bd_net $clk_out [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
connect_bd_net $clk_out [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK]

# Reset connections
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_hp0/ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_hp0/S00_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_hp0/S01_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_hp0/M00_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_ctrl/ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_ctrl/S00_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_ctrl/M00_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_interconnect_ctrl/M01_ARESETN]
connect_bd_net $sync_reset [get_bd_pins axi_dma_0/axi_resetn]
connect_bd_net $sync_reset [get_bd_pins myproject_0/ap_rst_n]

# Address space configuration
log_step "Configuring Address Space"
assign_bd_address

# Validate design
log_step "Validating Complete Design"
validate_bd_design

# Check for critical warnings
set critical_warnings [get_msg_config -severity CRITICAL_WARNING -count]
if {$critical_warnings > 0} {
    puts "WARNING: Design has $critical_warnings critical warnings!"
}

# Save design
save_bd_design

# Create wrapper
log_step "Creating design wrapper"
set wrapper_path [file normalize "./mnist_fpga/mnist_fpga.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"]
make_wrapper -files [get_files ./mnist_fpga/mnist_fpga.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse $wrapper_path
puts "Wrapper created"

# Generate bitstream
log_step "Launching implementation and bitstream generation"
launch_runs impl_1 -to_step write_bitstream -jobs 4
puts "Implementation launched with 4 jobs"

# Monitor implementation progress
while { [get_property PROGRESS [get_runs impl_1]] != "100%" } {
    puts "Implementation progress: [get_property PROGRESS [get_runs impl_1]]"
    puts "Current status: [get_property STATUS [get_runs impl_1]]"
    sleep 10
}

wait_on_run impl_1

# Check final status
if {[get_property PROGRESS [get_runs impl_1]] == "100%" && [get_property STATUS [get_runs impl_1]] == "write_bitstream Complete!"} {
    log_step "Implementation completed successfully"
    
    # Copy bitstream to convenient location
    set bitstream_path [file normalize "./mnist_fpga/mnist_fpga.runs/impl_1/design_1_wrapper.bit"]
    set output_path [file normalize "./mnist_fpga.bit"]
    file copy -force $bitstream_path $output_path
    puts "Bitstream copied to: $output_path"
} else {
    log_step "Implementation failed or had warnings. Check logs for details"
    puts "Final status: [get_property STATUS [get_runs impl_1]]"
}
