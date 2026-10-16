local function L(key, cmd, repeating)
    hl.bind(key, hl.dsp.exec_cmd(cmd), { repeating = repeating or false, locked = true })
end

L("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true)
L("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
L("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
L("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
L("XF86MonBrightnessUp", "quickshell ipc call shell brightnessUp", true)
L("XF86MonBrightnessDown", "quickshell ipc call shell brightnessDown", true)
L("XF86AudioNext", "playerctl next")
L("XF86AudioPrev", "playerctl previous")
L("XF86AudioPlay", "playerctl play-pause")
L("XF86AudioPause", "playerctl play-pause")
