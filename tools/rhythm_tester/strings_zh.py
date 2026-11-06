"""集中管理节拍测试器的简体中文文案。"""

TEXT: dict[str, str] = {
    "app_title": "MIDI 节拍测试器",
    "app_subtitle": "听音乐，按 J、K 或空格跟拍",
    "track": "曲目",
    "mode": "对照模式",
    "mode_pulse": "自动主拍候选",
    "mode_quarter": "MIDI 四分拍",
    "mode_onsets": "鼓点起音",
    "mode_blind": "只听跟拍",
    "mode_desc_pulse": "根据 MIDI 自动估计主拍，供试听对照。",
    "mode_desc_quarter": "按 MIDI 速度图生成四分拍，供对照。",
    "mode_desc_onsets": "显示合并后的鼓点起音，用于对照主拍。",
    "mode_desc_blind": "隐藏拍点、提示声和评分，只记录自然跟拍。",
    "layer": "拍点频率",
    "layer_half": "半速",
    "layer_normal": "原速",
    "layer_double": "倍速",
    "phase": "相位",
    "phase_normal": "原位",
    "phase_half": "偏移半拍",
    "play": "播放",
    "pause": "暂停",
    "resume": "继续",
    "retry": "重新开始",
    "open_pair": "打开 MIDI 与音频",
    "export_results": "导出记录",
    "open_results": "打开结果目录",
    "volume": "音乐音量",
    "click_sound": "拍点提示声",
    "window_limit": "判定窗口半宽上限",
    "compensation": "按键补偿",
    "compensation_tip": "正值使按键记录时间提前，不改变音乐或参考拍点。",
    "compensation_semantics": "正值使按键记录时间提前，不改变音乐或参考拍点。",
    "presentation_offset": "音画同步补偿",
    "presentation_offset_tip": "正值使画面和判定相对处理时钟延后，保留原始按键时间；与按键补偿独立，不改变音乐速度。",
    "presentation_offset_notice": "蓝牙输出可能有延迟，请按听感调整；系统报告的延迟不等于耳边实际延迟。",
    "window_tip": "每侧允许偏差的上限；相邻时机较近时会自动收窄。",
    "settings_hint": "先听音乐，再按需要调整参考时机。",
    "reduced_motion": "减少动态效果",
    "loading": "正在加载…",
    "ready": "已准备",
    "playing": "正在播放",
    "paused": "已暂停",
    "stopped": "已停止",
    "finished": "播放结束",
    "no_audio_device": "没有可用的音频输出设备。",
    "load_failed": "加载失败",
    "status_hint": "选择曲目和模式后播放，听音乐跟拍。",
    "keys_hint": "J / K / 空格 跟拍　P 暂停或继续　R 重新开始　Enter 播放",
    "blind_hint": "只听音乐跟拍；本模式不显示拍点或评分。",
    "waiting_hit": "等待按键",
    "hit": "落在窗口内",
    "early": "偏早",
    "late": "偏晚",
    "duplicate": "重复输入",
    "outside": "落在窗口外",
    "recorded": "已记录",
    "tap_count": "按键次数",
    "match_rate": "落窗比例",
    "mean_error": "平均偏差",
    "median_abs_error": "绝对偏差中位数",
    "last_error": "最近一次偏差",
    "recent_errors": "最近偏差",
    "trial_count": "记录段数",
    "results_empty": "暂无跟拍记录",
    "scheme_score_label": "参考时机匹配",
    "scheme_score_tip": "按所选参考时机统计，仅供比较，不代表节拍识别准确率。",
    "reference_summary": "{count} 个参考时机 · 中位间隔 {interval_ms:.0f} ms · 每分钟约 {rate:.1f} 次",
    "results_saved": "记录已保存",
    "export_failed": "导出失败",
    "external_midi_title": "选择 MIDI 文件",
    "external_audio_title": "选择对应的音频文件",
    "candidate_notice": "自动拍点只是候选，请结合听感比较。",
    "analysis_details": "参考分析详情",
    "focus_paused": "窗口失去焦点，已暂停",
    "key_J": "J",
    "key_K": "K",
    "key_SPACE": "空格",
    "unit_ms": "ms",
    "help_title": "使用说明",
    "help": "帮助",
    "help_body": (
        "选择曲目和对照模式，播放后听音乐，按 J、K 或空格跟拍。\n"
        "P 暂停或继续，R 重新开始，Enter 播放。\n"
        "只听跟拍模式隐藏拍点、提示声和评分，只记录自然按键。\n"
        "结果可导出；与参考时机的匹配不代表节拍识别准确率。"
    ),
    "missing_dependencies": "缺少运行依赖，请查看使用说明。",
    "source_details": "MIDI 与音频应来自同一版本，且时间起点需要对应。",
}


def t(key: str, **kwargs: object) -> str:
    """返回文案；未知键或格式化失败时保留可见的原字符串。"""
    if key not in TEXT:
        return key
    value = TEXT[key]
    if not kwargs:
        return value
    try:
        return value.format(**kwargs)
    except Exception:
        return value
