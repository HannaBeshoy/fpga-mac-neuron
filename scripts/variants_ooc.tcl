# ============================================================================
# variants_ooc.tcl - place and route every neuron variant on its own and
# measure its maximum clock frequency (Vivado 2022.2, non-project mode)
#
# Part 1, sweep (about 30-45 minutes on a laptop):
#   For each design below: synth_design -mode out_of_context for the
#   xc7a100tcsg324-1, then for each clock period: create_clock on clk,
#   opt_design, place_design, phys_opt_design, route_design,
#   report_timing_summary and report_utilization. The measured Fmax of a
#   design is the fastest period whose worst setup slack (WNS) is >= 0.
#   Reports:  results/vivado/variants/<design>_<period>ns_timing.rpt
#             results/vivado/variants/<design>_<period>ns_utilization.rpt
#   Summary:  results/vivado/variants/summary.csv  (one row per run)
#             results/vivado/variants/fmax.txt     (one line per design)
#
# Part 2, optional (about 5 minutes): post-route timing simulation of the
#   board design. neuron_top is implemented with the board XDC and the
#   Clocking Wizard, written out with write_verilog -mode timesim and
#   write_sdf, and sim/tb_top.v runs on that netlist in xsim with the SDF
#   delays (define TIMESIM).
#   Results:  results/vivado/timesim/
#
# Run it from the Vivado Tcl console, with no project open:
#   cd C:/path/to/fpga-mac-neuron
#   source scripts/variants_ooc.tcl
#
# Options: set any of these in the console before the source command.
#   set variants_periods {20 10 8 6 5 4.5 4 3.5 3}   clock periods in ns
#   set variants_designs {neuron neuron_parallel}    only these designs
#   set variants_sweep 0                             skip part 1
#   set variants_timesim 0                           skip part 2
#   set variants_stop_on_fail 0                      try every period, even
#                                                    after one has failed
#
# Out of context means the module is implemented on its own, without I/O
# buffers: its ports become internal connections. Every input and output
# is timed against clk with zero external delay (as if a register sat right
# outside the block), so the paths from the ports through the multipliers or
# the ROM count, not only the flip-flop to flip-flop paths. HD.CLK_SRC tells
# the placer that clk comes from a global clock buffer, as it does on the
# board. The build files go to build/ (ignored by git).
# ============================================================================

set V(part) xc7a100tcsg324-1
set V(repo) [file normalize [file join [file dirname [info script]] ..]]
set V(build) [file join $V(repo) build vivado_variants]
set V(out) [file join $V(repo) results vivado variants]
set V(tsout) [file join $V(repo) results vivado timesim]
set V(startdir) [pwd]

# name, top module, generics, source files (relative to the repository)
set V(designs) [list \
    [list neuron                neuron          {}           {src/neuron.v src/seq_mult.v}] \
    [list neuron_signed         neuron_signed   {}           {src/variants/neuron_signed.v src/variants/seq_mult_signed.v src/seq_mult.v}] \
    [list neuron_parallel       neuron_parallel {W=4}        {src/variants/neuron_parallel.v}] \
    [list neuron_parallel_w16   neuron_parallel {W=16}       {src/variants/neuron_parallel.v}] \
    [list weight_rom_sync       weight_rom_sync {DEPTH=8}    {src/variants/weight_rom_sync.v}] \
    [list weight_rom_sync_d1024 weight_rom_sync {DEPTH=1024} {src/variants/weight_rom_sync.v}] \
]

if {![info exists variants_periods]}      { set variants_periods {20 10 8 6 5 4.5 4 3.5 3} }
if {![info exists variants_designs]}      { set variants_designs {} }
if {![info exists variants_sweep]}        { set variants_sweep 1 }
if {![info exists variants_timesim]}      { set variants_timesim 1 }
if {![info exists variants_stop_on_fail]} { set variants_stop_on_fail 1 }

# ---------------------------------------------------------------- helpers

proc vlog {msg} {
    puts "variants_ooc: $msg"
}

# worst slack of the routed design, "NA" if nothing is timed
proc worst_slack {kind} {
    set p [get_timing_paths -quiet -$kind -max_paths 1 -nworst 1]
    if {[llength $p] == 0} { return NA }
    set s [get_property SLACK $p]
    if {$s eq ""} { return NA }
    return [format %.3f $s]
}

# number from a row of the report_utilization tables, or "" if absent
proc util_field {text label} {
    if {[regexp "\\|\\s*${label}\\*?\\s*\\|\\s*(\[0-9.\]+)" $text -> n]} { return $n }
    return ""
}

proc count_cells {filter} {
    return [llength [get_cells -quiet -hierarchical -filter $filter]]
}

# LUT, FF, DSP, BRAM (tiles, RAMB18 = 0.5), CARRY4 of the open design
proc utilization {} {
    set t [report_utilization -return_string]
    set lut  [util_field $t {Slice LUTs}]
    set ff   [util_field $t {Slice Registers}]
    set dsp  [util_field $t {DSPs}]
    set bram [util_field $t {Block RAM Tile}]
    if {$lut eq ""}  { set lut  [count_cells {PRIMITIVE_GROUP == LUT}] }
    if {$ff eq ""}   { set ff   [count_cells {PRIMITIVE_GROUP == FLOP_LATCH}] }
    if {$dsp eq ""}  { set dsp  [count_cells {REF_NAME =~ DSP48*}] }
    if {$bram eq ""} {
        set bram [expr {[count_cells {REF_NAME =~ RAMB36*}] + 0.5 * [count_cells {REF_NAME =~ RAMB18*}]}]
    }
    set carry [count_cells {REF_NAME == CARRY4}]
    return [list $lut $ff $dsp $bram $carry]
}

proc csv_append {file row} {
    set f [open $file a]
    puts $f [join $row ,]
    close $f
}

# run a Vivado command line tool (xvlog, xelab, xsim) in the current folder
proc run_tool {tool args} {
    set bin [file join $::env(XILINX_VIVADO) bin]
    if {$::tcl_platform(platform) eq "windows"} {
        set cmd [list cmd /c [file nativename [file join $bin $tool.bat]] {*}$args]
    } else {
        set cmd [list [file join $bin $tool] {*}$args]
    }
    vlog "running $tool $args"
    set rc [catch {exec {*}$cmd 2>@1} out]
    puts $out
    if {$rc} { error "$tool failed, see [file join [pwd] $tool.log]" }
}

# ------------------------------------------------------ part 1: the sweep

proc synth_ooc {name top generics files} {
    global V
    create_project -in_memory -part $V(part)
    foreach f $files { read_verilog [file join $V(repo) $f] }
    if {$top eq "weight_rom_sync"} { read_mem [file join $V(build) weights.mem] }
    set gen {}
    foreach g $generics { lappend gen -generic $g }
    synth_design -top $top -part $V(part) -mode out_of_context {*}$gen
    set dcp [file join $V(build) ${name}_synth.dcp]
    write_checkpoint -force $dcp
    close_project
    return $dcp
}

proc impl_ooc {name top dcp period csv} {
    global V
    open_checkpoint $dcp
    create_clock -name clk -period $period [get_ports clk]
    set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
    set ins [get_ports -quiet -filter {DIRECTION == IN && NAME != clk}]
    if {[llength $ins]} { set_input_delay -clock clk 0 $ins }
    set outs [get_ports -quiet -filter {DIRECTION == OUT}]
    if {[llength $outs]} { set_output_delay -clock clk 0 $outs }

    opt_design
    place_design
    phys_opt_design
    route_design

    set base [file join $V(out) ${name}_${period}ns]
    report_timing_summary -max_paths 10 -file ${base}_timing.rpt
    report_utilization -file ${base}_utilization.rpt

    set wns [worst_slack setup]
    set whs [worst_slack hold]
    if {$wns eq "NA"} {
        set met NA; set fest NA
    } else {
        set met [expr {$wns >= 0 ? "yes" : "no"}]
        set fest [format %.1f [expr {1000.0 / ($period - $wns)}]]
    }
    set u [utilization]
    csv_append $csv [concat [list $name $top $period $wns $whs $met $fest] $u]
    close_design
    vlog "$name at $period ns: WNS $wns ns, WHS $whs ns, LUT/FF/DSP/BRAM/CARRY4 = [join $u /]"
    return [list $wns $whs $fest $u]
}

proc run_sweep {periods only stop_on_fail} {
    global V
    file mkdir $V(build) $V(out)
    set csv [file join $V(out) summary.csv]
    if {[llength $only] == 0 || ![file exists $csv]} {
        set f [open $csv w]
        puts $f "design,top,period_ns,wns_ns,whs_ns,timing_met,fmax_est_mhz,lut,ff,dsp,bram,carry4"
        close $f
    }
    set periods [lsort -real -decreasing $periods]
    set fmax_lines {}
    foreach d $V(designs) {
        lassign $d name top generics files
        if {[llength $only] && [lsearch -exact $only $name] < 0} { continue }
        set t0 [clock seconds]
        vlog "=== $name: synthesis"
        set dcp [synth_ooc $name $top $generics $files]
        set best ""
        foreach p $periods {
            vlog "=== $name: $p ns ([format %.1f [expr {1000.0 / $p}]] MHz)"
            lassign [impl_ooc $name $top $dcp $p $csv] wns whs fest u
            if {$wns ne "NA" && $wns >= 0} {
                set best [list $p $wns $fest $u]
            } elseif {$stop_on_fail} {
                vlog "$name fails at $p ns, faster clocks skipped"
                break
            }
        }
        if {$best eq ""} {
            set line "$name: timing not met at any period"
        } else {
            lassign $best p wns fest u
            set line [format "%-22s Fmax %6.1f MHz (%s ns met, WNS %s ns, estimate %s MHz)  LUT %s FF %s DSP %s BRAM %s CARRY4 %s" \
                $name [expr {1000.0 / $p}] $p $wns $fest {*}$u]
        }
        lappend fmax_lines $line
        vlog "$line  ([expr {[clock seconds] - $t0}] s)"
    }
    set f [open [file join $V(out) fmax.txt] [expr {[llength $only] ? "a" : "w"}]]
    puts $f [join $fmax_lines \n]
    close $f
    vlog "measured Fmax (fastest period with WNS >= 0):"
    foreach l $fmax_lines { puts "  $l" }
}

# ------------------------------------- part 2: post-route timing simulation

proc run_timesim {} {
    global V
    set tdir [file join $V(build) timesim]
    file delete -force $tdir
    file mkdir $tdir $V(tsout)
    cd $tdir
    file copy -force [file join $V(repo) src weights.mem] weights.mem

    # the board design, with the small tick periods tb_top uses (a digit per
    # clock, a new run every 64 clocks); everything else is the board build
    create_project -in_memory -part $V(part)
    set_property target_language Verilog [current_project]
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0 -dir [file join $tdir ip]
    set_property -dict [list CONFIG.PRIM_IN_FREQ {100.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000}] [get_ips clk_wiz_0]
    generate_target all [get_ips clk_wiz_0]
    synth_ip [get_ips clk_wiz_0]
    foreach f [lsort [glob [file join $V(repo) src *.v]]] { read_verilog $f }
    read_mem weights.mem
    read_xdc [file join $V(repo) constraints nexys4ddr.xdc]
    synth_design -top neuron_top -part $V(part) -generic SCAN_BIT=0 -generic SAMPLE_BITS=6
    opt_design
    place_design
    phys_opt_design
    route_design
    report_timing_summary -max_paths 10 -file [file join $V(tsout) neuron_top_timesim_timing_routed.rpt]
    write_verilog -force -mode timesim -sdf_anno false neuron_top_timesim.v
    write_sdf -force neuron_top_timesim.sdf
    close_project

    # tb_top on the netlist, with the SDF delays (maximum delays)
    file copy -force [file join $V(repo) sim tb_top.v] tb_top.v
    file copy -force [file join $::env(XILINX_VIVADO) data verilog src glbl.v] glbl.v
    run_tool xvlog --log xvlog.log -d TIMESIM neuron_top_timesim.v tb_top.v glbl.v
    run_tool xelab --log xelab.log -debug off -L simprims_ver -L secureip \
        -transport_int_delays -pulse_r 0 -pulse_int_r 0 -maxdelay \
        -sdfmax /tb_top/DUT=neuron_top_timesim.sdf \
        -s tb_top_timesim work.tb_top work.glbl
    run_tool xsim tb_top_timesim -R --log xsim.log
    file copy -force xsim.log [file join $V(tsout) tb_top_timesim.log]

    set f [open xsim.log r]; set log [read $f]; close $f
    if {[regexp {tb_top: (\d+) checks, (\d+) errors} $log -> checks errors] && $errors == 0 \
            && [string match "*PASS*" $log]} {
        vlog "timing simulation: PASS, $checks checks, 0 errors"
    } else {
        vlog "timing simulation: FAIL or incomplete, see [file join $V(tsout) tb_top_timesim.log]"
    }
}

# -------------------------------------------------------------------- main

if {[llength [get_projects -quiet]]} {
    error "variants_ooc: close the open project first (File > Close Project), then source the script again"
}
set V(t0) [clock seconds]
file mkdir $V(build)
cd $V(build)
# $readmemb("weights.mem") in weight_rom_sync is read from the current folder
file copy -force [file join $V(repo) src weights.mem] weights.mem
if {[catch {
    if {$variants_sweep}   { run_sweep $variants_periods $variants_designs $variants_stop_on_fail }
    if {$variants_timesim} { run_timesim }
} err opts]} {
    cd $V(startdir)
    return -options $opts $err
}
cd $V(startdir)
vlog "done in [expr {([clock seconds] - $V(t0)) / 60}] min; results in $V(out) and $V(tsout)"
