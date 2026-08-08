# ============================================================================
# Benders Decomposition GUI
#
# Simple graphical interface for launching the Benders decomposition algorithm
#
# Dependencies:
#   Gtk.jl must be installed: using Pkg; Pkg.add("Gtk")
#
# Usage:
#   julia --project=. gui/gbd_gui.jl
# ============================================================================

using Pkg

# Check and load Gtk.
try
    using Gtk
catch
    @error "Gtk.jl is not installed. Run: using Pkg; Pkg.add(\"Gtk\")"
    exit(1)
end

# Set the working directory to the project root.
cd(joinpath(@__DIR__, ".."))

# Load environment configuration, including JuMP dependencies.
original_dir = "/Users/yuanyiping/Documents/GitHub/module_unitcommitment"
include(joinpath("/Users/yuanyiping/Documents/GitHub/module_unitcommitment", "src", "environment_config.jl"))

# Include the core Benders decomposition modules.
# Note: gbd_mainfunc.jl is not included because it is an execution script, not a module.
# The required file is benders_mainfunc.jl, which provides benders_mainfunc_modules.
# benderdecomposition_module.jl provides bd_framework.
benders_dir = joinpath("/Users/yuanyiping/Documents/GitHub/module_unitcommitment", "tools", "bendersdecomposition")
cd(benders_dir)
try
    include(joinpath(benders_dir,"gbd_mainfunc.jl"))
    # include(joinpath(benders_dir,"benderdecomposition_module.jl"))
finally
    cd(original_dir)
end

# ============================================================================
# GUI main function.
# ============================================================================
function create_gui()
    # Create the main window.
    win = GtkWindow("Benders Decomposition GUI", 600, 500)
    
    # Create the main vertical container.
    vbox = GtkBox(:v, 10)
    push!(win, vbox)
    
    # Title label.
    title_label = GtkLabel("Benders Decomposition Control Panel")
    set_gtk_property!(title_label, :xalign, 0.5)
    Pango.set_markup(title_label, "<span size='x-large' weight='bold'>Benders Decomposition Control Panel</span>")
    push!(vbox, title_label)
    
    # Separator.
    separator1 = GtkSeparator(:h)
    push!(vbox, separator1)
    
    # Status information area.
    info_frame = GtkFrame("Status Information")
    info_vbox = GtkBox(:v, 5)
    push!(info_frame, info_vbox)
    
    # Status label.
    status_label = GtkLabel("Ready - click 'Run Algorithm' to start")
    set_gtk_property!(status_label, :xalign, 0.0)
    set_gtk_property!(status_label, :wrap, true)
    push!(info_vbox, status_label)
    
    # Detailed text view with scroll bar.
    details_scrolled = GtkScrolledWindow()
    details_text = GtkTextView()
    details_buffer = GtkTextBuffer(GtkTextTagTable())
    set_gtk_property!(details_text, :buffer, details_buffer)
    set_gtk_property!(details_text, :editable, false)
    set_gtk_property!(details_text, :monospace, true)
    set_gtk_property!(details_scrolled, :min_content_height, 200)
    push!(details_scrolled, details_text)
    push!(info_vbox, details_scrolled)
    
    push!(vbox, info_frame)
    
    # Button area.
    button_hbox = GtkBox(:h, 10)
    set_gtk_property!(button_hbox, :homogeneous, true)
    
    # Run button.
    run_button = GtkButton("Run Algorithm")
    set_gtk_property!(run_button, :tooltip_text, "Initialize and run the Benders decomposition algorithm")
    push!(button_hbox, run_button)
    
    # Clear button.
    clear_button = GtkButton("Clear Log")
    set_gtk_property!(clear_button, :tooltip_text, "Clear output log")
    push!(button_hbox, clear_button)
    
    # Exit button.
    exit_button = GtkButton("Exit")
    set_gtk_property!(exit_button, :tooltip_text, "Exit program")
    push!(button_hbox, exit_button)
    
    push!(vbox, button_hbox)
    
    # Progress bar.
    progress_bar = GtkProgressBar()
    set_gtk_property!(progress_bar, :show_text, true)
    set_gtk_property!(progress_bar, :text, "Waiting...")
    push!(vbox, progress_bar)
    
    # Helper: update status text.
    function update_status(message)
        set_gtk_property!(status_label, :label, message)
        Gtk.gc_preserve(win, status_label)
    end
    
    # Helper: append logs to the text view.
    function append_log(text)
        end_iter = get_end_iter(details_buffer)
        insert!(details_buffer, end_iter, string(text, "\n"))
        # Automatically scroll to the bottom.
        mark = create_mark(details_buffer, "end", end_iter, true)
        scroll_to_mark(details_text, mark, 0.0, false, 0.0, 1.0)
    end
    
    # Helper: clear logs.
    function clear_log()
        set_gtk_property!(details_buffer, :text, "")
    end
    
    # Run the algorithm in a background thread.
    function run_algorithm()
        try
            # Update UI status.
            set_gtk_property!(run_button, :sensitive, false)
            set_gtk_property!(progress_bar, :fraction, 0.0)
            set_gtk_property!(progress_bar, :text, "Initializing...")
            update_status("Initializing model...")
            clear_log()
            
            append_log("="^80)
            append_log("Starting Benders decomposition model initialization...")
            append_log("="^80)
            
            # Initialize the model in a background thread.
            @async begin
                try
                    Gtk.@idle_add begin
                        set_gtk_property!(progress_bar, :fraction, 0.2)
                        set_gtk_property!(progress_bar, :text, "Initializing model (20%)...")
                        update_status("Initializing model...")
                        true
                    end
                    
                    scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, 
                    batch_sub_model_struct_dic, config_param, units, lines, loads, winds, psses, 
                    NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules()
                    
                    # Validate initialization.
                    if scuc_masterproblem === nothing || scuc_subproblem === nothing
                        error("Initialization failed: master or subproblem model is empty")
                    end
                    
                    Gtk.@idle_add begin
                        append_log("  OK master problem model initialized")
                        append_log("    - variables: $(num_variables(scuc_masterproblem))")
                        append_log("  OK subproblem model initialized")
                        append_log("    - variables: $(num_variables(scuc_subproblem))")
                        append_log("  OK batch subproblems: $(length(batch_sub_model_struct_dic)) scenarios")
                        append_log("  OK problem dimensions:")
                        append_log("    - buses (NB): $NB")
                        append_log("    - generators (NG): $NG")
                        append_log("    - transmission lines (NL): $NL")
                        append_log("    - loads (ND): $ND")
                        append_log("    - time periods (NT): $NT")
                        append_log("    - scenarios (NS): $NS")
                        append_log("    - storage units (NC): $NC")
                        append_log("    - data centers (ND2): $ND2")
                        append_log("="^80)
                        set_gtk_property!(progress_bar, :fraction, 0.4)
                        set_gtk_property!(progress_bar, :text, "Running algorithm (40%)...")
                        update_status("Running Benders decomposition algorithm...")
                        true
                    end
                    
                    # Run the Benders decomposition framework.
                    Gtk.@idle_add begin
                        append_log("\n" * "="^80)
                        append_log("Running Benders decomposition algorithm...")
                        append_log("="^80)
                        append_log("  This may take several minutes depending on problem size...")
                        append_log("  The algorithm iterates until convergence or the maximum iteration count is reached")
                        append_log("-"^80)
                        true
                    end
                    
                    # Run the algorithm.
                    bd_framework(
                        scuc_masterproblem,
                        scuc_subproblem,
                        master_model_struct,
                        batch_sub_model_struct_dic,
                        winds,
                        config_param,
                    )
                    
                    Gtk.@idle_add begin
                        append_log("\n" * "="^80)
                        append_log("OK Benders decomposition completed successfully!")
                        append_log("="^80)
                        set_gtk_property!(progress_bar, :fraction, 1.0)
                        set_gtk_property!(progress_bar, :text, "Complete (100%)")
                        update_status("Algorithm execution completed successfully!")
                        set_gtk_property!(run_button, :sensitive, true)
                        true
                    end
                catch e
                    Gtk.@idle_add begin
                        append_log("\n" * "="^80)
                        append_log("ERROR execution failed!")
                        append_log("="^80)
                        append_log("Error details:")
                        append_log("  $e")
                        append_log("  $(sprint(showerror, e, catch_backtrace()))")
                        set_gtk_property!(progress_bar, :fraction, 0.0)
                        set_gtk_property!(progress_bar, :text, "Error")
                        update_status("Execution failed. Check the log.")
                        set_gtk_property!(run_button, :sensitive, true)
                        true
                    end
                end
            end
            
        catch e
            Gtk.@idle_add begin
                append_log("\n" * "="^80)
                append_log("ERROR initialization failed!")
                append_log("="^80)
                append_log("Error details:")
                append_log("  $e")
                append_log("  $(sprint(showerror, e, catch_backtrace()))")
                set_gtk_property!(progress_bar, :fraction, 0.0)
                set_gtk_property!(progress_bar, :text, "Error")
                update_status("Initialization failed. Check the log.")
                set_gtk_property!(run_button, :sensitive, true)
                true
            end
        end
    end
    
    # Button event handlers.
    signal_connect(run_button, "clicked") do widget
        @async run_algorithm()
    end
    
    signal_connect(clear_button, "clicked") do widget
        clear_log()
        update_status("Log cleared")
    end
    
    signal_connect(exit_button, "clicked") do widget
        Gtk.destroy(win)
    end
    
    # Window close event.
    signal_connect(win, "destroy") do widget
        Gtk.quit()
    end
    
    # Show the window.
    showall(win)
    
    return win
end

# ============================================================================
# Main entry point.
# ============================================================================
if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting Benders Decomposition GUI...")
    win = create_gui()
    Gtk.@guarded Gtk.main()
end
