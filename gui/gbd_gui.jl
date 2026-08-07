# ============================================================================
# Benders Decomposition GUI
#
# 简单的图形界面程序，用于调用和运行 Benders 分解算法
#
# 依赖:
#   需要安装 Gtk.jl: using Pkg; Pkg.add("Gtk")
#
# 使用方法:
#   julia --project=. gui/gbd_gui.jl
# ============================================================================

using Pkg

# 检查并尝试加载 Gtk
try
    using Gtk
catch
    @error "Gtk.jl 未安装。请运行: using Pkg; Pkg.add(\"Gtk\")"
    exit(1)
end

# 设置工作目录到项目根目录
cd(joinpath(@__DIR__, ".."))

# 加载环境配置（包含 JuMP 等依赖）
original_dir = "/Users/yuanyiping/Documents/GitHub/module_unitcommitment"
include(joinpath("/Users/yuanyiping/Documents/GitHub/module_unitcommitment", "src", "environment_config.jl"))

# 包含 Benders 分解的核心模块
# 注意：不包含 gbd_mainfunc.jl，因为它是执行脚本，不是模块
# 我们需要的是 benders_mainfunc.jl（提供 benders_mainfunc_modules 函数）
# 和 benderdecomposition_module.jl（提供 bd_framework 函数）
benders_dir = joinpath("/Users/yuanyiping/Documents/GitHub/module_unitcommitment", "tools", "bendersdecomposition")
cd(benders_dir)
try
    include(joinpath(benders_dir,"gbd_mainfunc.jl"))
    # include(joinpath(benders_dir,"benderdecomposition_module.jl"))
finally
    cd(original_dir)
end

# ============================================================================
# GUI 主函数
# ============================================================================
function create_gui()
    # 创建主窗口
    win = GtkWindow("Benders 分解算法 GUI", 600, 500)
    
    # 创建主容器（垂直布局）
    vbox = GtkBox(:v, 10)
    push!(win, vbox)
    
    # 标题标签
    title_label = GtkLabel("Benders 分解算法控制面板")
    set_gtk_property!(title_label, :xalign, 0.5)
    Pango.set_markup(title_label, "<span size='x-large' weight='bold'>Benders 分解算法控制面板</span>")
    push!(vbox, title_label)
    
    # 分隔线
    separator1 = GtkSeparator(:h)
    push!(vbox, separator1)
    
    # 状态信息区域
    info_frame = GtkFrame("状态信息")
    info_vbox = GtkBox(:v, 5)
    push!(info_frame, info_vbox)
    
    # 状态标签
    status_label = GtkLabel("就绪 - 点击 '运行算法' 开始")
    set_gtk_property!(status_label, :xalign, 0.0)
    set_gtk_property!(status_label, :wrap, true)
    push!(info_vbox, status_label)
    
    # 详细信息文本视图（带滚动条）
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
    
    # 按钮区域
    button_hbox = GtkBox(:h, 10)
    set_gtk_property!(button_hbox, :homogeneous, true)
    
    # 运行按钮
    run_button = GtkButton("运行算法")
    set_gtk_property!(run_button, :tooltip_text, "初始化并运行 Benders 分解算法")
    push!(button_hbox, run_button)
    
    # 清除按钮
    clear_button = GtkButton("清除日志")
    set_gtk_property!(clear_button, :tooltip_text, "清除输出日志")
    push!(button_hbox, clear_button)
    
    # 退出按钮
    exit_button = GtkButton("退出")
    set_gtk_property!(exit_button, :tooltip_text, "退出程序")
    push!(button_hbox, exit_button)
    
    push!(vbox, button_hbox)
    
    # 进度条
    progress_bar = GtkProgressBar()
    set_gtk_property!(progress_bar, :show_text, true)
    set_gtk_property!(progress_bar, :text, "等待中...")
    push!(vbox, progress_bar)
    
    # 辅助函数：更新状态文本
    function update_status(message)
        set_gtk_property!(status_label, :label, message)
        Gtk.gc_preserve(win, status_label)
    end
    
    # 辅助函数：追加日志到文本视图
    function append_log(text)
        end_iter = get_end_iter(details_buffer)
        insert!(details_buffer, end_iter, string(text, "\n"))
        # 自动滚动到底部
        mark = create_mark(details_buffer, "end", end_iter, true)
        scroll_to_mark(details_text, mark, 0.0, false, 0.0, 1.0)
    end
    
    # 辅助函数：清除日志
    function clear_log()
        set_gtk_property!(details_buffer, :text, "")
    end
    
    # 运行算法的函数（在后台线程中执行）
    function run_algorithm()
        try
            # 更新 UI 状态
            set_gtk_property!(run_button, :sensitive, false)
            set_gtk_property!(progress_bar, :fraction, 0.0)
            set_gtk_property!(progress_bar, :text, "初始化中...")
            update_status("正在初始化模型...")
            clear_log()
            
            append_log("="^80)
            append_log("开始初始化 Benders 分解模型...")
            append_log("="^80)
            
            # 初始化模型（在后台线程中执行）
            @async begin
                try
                    Gtk.@idle_add begin
                        set_gtk_property!(progress_bar, :fraction, 0.2)
                        set_gtk_property!(progress_bar, :text, "初始化模型 (20%)...")
                        update_status("正在初始化模型...")
                        true
                    end
                    
                    scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, 
                    batch_sub_model_struct_dic, config_param, units, lines, loads, winds, psses, 
                    NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules()
                    
                    # 验证初始化
                    if scuc_masterproblem === nothing || scuc_subproblem === nothing
                        error("初始化失败：主问题或子问题模型为空")
                    end
                    
                    Gtk.@idle_add begin
                        append_log("  ✓ 主问题模型已初始化")
                        append_log("    - 变量数: $(num_variables(scuc_masterproblem))")
                        append_log("  ✓ 子问题模型已初始化")
                        append_log("    - 变量数: $(num_variables(scuc_subproblem))")
                        append_log("  ✓ 批量子问题: $(length(batch_sub_model_struct_dic)) 个场景")
                        append_log("  ✓ 问题维度:")
                        append_log("    - 母线数 (NB): $NB")
                        append_log("    - 发电机数 (NG): $NG")
                        append_log("    - 传输线数 (NL): $NL")
                        append_log("    - 负荷数 (ND): $ND")
                        append_log("    - 时间周期数 (NT): $NT")
                        append_log("    - 场景数 (NS): $NS")
                        append_log("    - 储能单元数 (NC): $NC")
                        append_log("    - 数据中心数 (ND2): $ND2")
                        append_log("="^80)
                        set_gtk_property!(progress_bar, :fraction, 0.4)
                        set_gtk_property!(progress_bar, :text, "运行算法 (40%)...")
                        update_status("正在运行 Benders 分解算法...")
                        true
                    end
                    
                    # 运行 Benders 分解框架
                    Gtk.@idle_add begin
                        append_log("\n" * "="^80)
                        append_log("运行 Benders 分解算法...")
                        append_log("="^80)
                        append_log("  这可能需要几分钟，取决于问题规模...")
                        append_log("  算法将迭代直到收敛或达到最大迭代次数")
                        append_log("-"^80)
                        true
                    end
                    
                    # 运行算法
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
                        append_log("✓ Benders 分解成功完成！")
                        append_log("="^80)
                        set_gtk_property!(progress_bar, :fraction, 1.0)
                        set_gtk_property!(progress_bar, :text, "完成 (100%)")
                        update_status("算法执行成功完成！")
                        set_gtk_property!(run_button, :sensitive, true)
                        true
                    end
                catch e
                    Gtk.@idle_add begin
                        append_log("\n" * "="^80)
                        append_log("✗ 执行失败！")
                        append_log("="^80)
                        append_log("错误详情:")
                        append_log("  $e")
                        append_log("  $(sprint(showerror, e, catch_backtrace()))")
                        set_gtk_property!(progress_bar, :fraction, 0.0)
                        set_gtk_property!(progress_bar, :text, "错误")
                        update_status("执行失败，请查看日志")
                        set_gtk_property!(run_button, :sensitive, true)
                        true
                    end
                end
            end
            
        catch e
            Gtk.@idle_add begin
                append_log("\n" * "="^80)
                append_log("✗ 初始化失败！")
                append_log("="^80)
                append_log("错误详情:")
                append_log("  $e")
                append_log("  $(sprint(showerror, e, catch_backtrace()))")
                set_gtk_property!(progress_bar, :fraction, 0.0)
                set_gtk_property!(progress_bar, :text, "错误")
                update_status("初始化失败，请查看日志")
                set_gtk_property!(run_button, :sensitive, true)
                true
            end
        end
    end
    
    # 按钮事件处理
    signal_connect(run_button, "clicked") do widget
        @async run_algorithm()
    end
    
    signal_connect(clear_button, "clicked") do widget
        clear_log()
        update_status("日志已清除")
    end
    
    signal_connect(exit_button, "clicked") do widget
        Gtk.destroy(win)
    end
    
    # 窗口关闭事件
    signal_connect(win, "destroy") do widget
        Gtk.quit()
    end
    
    # 显示窗口
    showall(win)
    
    return win
end

# ============================================================================
# 主程序入口
# ============================================================================
if abspath(PROGRAM_FILE) == @__FILE__
    println("启动 Benders 分解算法 GUI...")
    win = create_gui()
    Gtk.@guarded Gtk.main()
end

